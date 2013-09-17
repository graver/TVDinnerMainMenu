//
//  MainMenuVC.m
//  TVDinner
//
//  Created by Ben on 2/8/12.
//  Copyright (c) 2012 TV Dinner. All rights reserved.
//

#import "MainMenuVC.h"
#import "MainMenuDinnerCell.h"
#import "CommonToolbox.h"
#import <QuartzCore/QuartzCore.h>
#import "ReminderManager.h"
#import "UAPush.h"
//#import "NibbleReplyCountStore.h"
#import "HomeVC.h"
#import "TVDinnerViewController.h"
#import "AFTVDinnerAPIClient.h"
#import "TVDXMLParser.h"

@interface MainMenuVC (Private)
- (void)updateTitleBarAndFooter:(NSString *)searchText;
- (NSInteger)numberOfFavoritesInDinnerArray:(NSMutableArray *)dinnerArray;
- (void)filterDinnerArrayBySearch:(NSMutableArray *)original filtered:(NSMutableArray *)filtered text:(NSString *)text;
- (void)filterDinnerArrayByFavorites:(NSMutableArray *)original filtered:(NSMutableArray *)filtered;
- (void)filterDinnerArrayByGenre:(NSMutableArray *)original filtered:(NSMutableArray *)filtered;
- (void)searchDinners:(NSString *)text;
- (void)filterFavoriteDinners;
- (void)filterGenreDinners;
- (void)resizeDinnerTableFooter;
@end

@implementation MainMenuVC

@synthesize settingsVC, noFavoritesView, dinnersFooterView, dinnersTableFooterView;
@synthesize noSearchResultsView, requestShowButton, dinnersFooterLabel, dinnersTableFooterButton, dinnersTableFooterLabel;
@synthesize dinnersTable, selectionTable, selectionModeTitles, showSearchBar, avatarImage, settingsButton, backButton;
@synthesize filteredOnNowShows, filteredOnLaterShows, genreIds, refreshTimer;
@synthesize delegate;

// How often to refresh dinners (in seconds)
float refreshRate = 30.0;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:
                              @"On Now", [NSNumber numberWithInt:ON_NOW], 
                              @"On Later", [NSNumber numberWithInt:ON_LATER], 
                              @"My Favorites", [NSNumber numberWithInt:MY_FAVORITES], 
                              @"Friends Favorites", [NSNumber numberWithInt:FRIENDS_FAVORITES], 
                              @"Search", [NSNumber numberWithInt:SEARCH], nil];
        self.selectionModeTitles = dict;
        [dict release];
        
        dinnerSections = 0;
        dinnerRows = 0;
        dinnerFooterResized = NO;
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    if (![self isViewLoaded])
    {
        // Release any cached data, images, etc that aren't in use.
        self.selectionModeTitles = nil;
        self.filteredOnNowShows = nil;
        self.filteredOnLaterShows = nil;
        self.genreIds = nil;
    }
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    app = (TVDinnerAppDelegate *)[[UIApplication sharedApplication] delegate];
    fbHelper = [FacebookHelper sharedInstance];
    reminderManager = [ReminderManager sharedInstance];
    
    self.settingsVC = app.settingsViewCtrl;
    self.genreIds = [app.tvCategories keysSortedByValueUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    // Modify dinner table
    [self.dinnersTable setSeparatorColor:UIColorFromRGB(0x252a2e)];
    self.dinnersTable.tableFooterView = dinnersTableFooterView;
    
    // Modify selection table
    UIView *footer = [[UIView alloc] initWithFrame:CGRectZero];
    self.selectionTable.tableFooterView = footer;
    [footer release];
    
    // Color in no favorites/search results gradient
    UIColor *topGradient = UIColorFromRGB(0x1b1f24);
    UIColor *bottomGradient = UIColorFromRGB(0x090b0c);
    
    CAGradientLayer *noFavGradient = [CAGradientLayer layer];
    noFavGradient.frame = noFavoritesView.bounds;
    noFavGradient.colors = [NSArray arrayWithObjects:(id)[topGradient CGColor], (id)[bottomGradient CGColor], nil];
    [noFavoritesView.layer insertSublayer:noFavGradient atIndex:0];
    
    CAGradientLayer *noSearchGradient = [CAGradientLayer layer];
    noSearchGradient.frame = noSearchResultsView.bounds;
    noSearchGradient.colors = [NSArray arrayWithObjects:(id)[topGradient CGColor], (id)[bottomGradient CGColor], nil];
    [noSearchResultsView.layer insertSublayer:noSearchGradient atIndex:0];
    
    CAGradientLayer *viewGradient = [CAGradientLayer layer];
    viewGradient.frame = self.view.bounds;
    viewGradient.colors = [NSArray arrayWithObjects:(id)[topGradient CGColor], (id)[bottomGradient CGColor], nil];
    [self.view.layer insertSublayer:viewGradient atIndex:0];
    
    // Default to 'On Later' if no current dinners
    selectionMode = [app.tvDinnersArray count] ? ON_NOW : ON_LATER;
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:selectionMode inSection:0];
    [selectionTable selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
    
	// Set user avatar
    NSMutableDictionary *userDict = [app.UserInfoArray objectAtIndex:0];
    UIImage *checkAvatarImage = [userDict objectForKey:@"AvatarImage"];
	if (checkAvatarImage != nil)
	{
		[avatarImage setImage:checkAvatarImage];
	}
    
    [self updateTitleBarAndFooter:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleEnteredBackground:) 
                                                 name: UIApplicationDidEnterBackgroundNotification
                                               object: nil];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleBecameActive:) 
                                                 name: UIApplicationDidBecomeActiveNotification
                                               object: nil];
    
    if (![[ReminderManager sharedInstance] hasValidPrograms] && ![[ReminderManager sharedInstance] fetchingPrograms]) 
    { 
        [[ReminderManager sharedInstance] fetchPrograms]; 
    }
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];  
    
    if (self.refreshTimer == nil)
    {
        // Update the dinners periodically
        NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:refreshRate target:self selector:@selector(refreshDinners:) userInfo:nil repeats:YES];
        self.refreshTimer = timer;
    }
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];  
    [self stopRefreshTimer];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.settingsVC = nil;
    self.noFavoritesView = nil;
    self.noSearchResultsView = nil;
    self.dinnersFooterView = nil;
    self.dinnersTableFooterView = nil;
    self.dinnersFooterLabel = nil;
    self.dinnersTable = nil;
    self.selectionTable = nil;
    self.showSearchBar = nil;
    self.requestShowButton = nil;
    self.avatarImage = nil;
    self.settingsButton = nil;
    self.dinnersTableFooterButton = nil;
    self.dinnersTableFooterLabel = nil;
    self.backButton = nil;
    
    reminderManager = nil;
    app = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)dealloc
{
    [settingsVC release];
    [noFavoritesView release];
    [noSearchResultsView release];
    [dinnersFooterView release];
    [dinnersTableFooterView release];
    [dinnersFooterLabel release];
    [requestShowButton release];
    [dinnersTable release];
    [selectionTable release];
    [selectionModeTitles release];
    [showSearchBar release];
    [avatarImage release];
    [settingsButton release];
    [dinnersTableFooterButton release];
    [dinnersTableFooterLabel release];
    [backButton release];
    
    [filteredOnNowShows release];
    [filteredOnLaterShows release];
    [genreIds release];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationLandscapeRight || interfaceOrientation == UIInterfaceOrientationLandscapeLeft);
}

# pragma mark App Lifecycle
#pragma mark -

- (void)handleEnteredBackground:(UIApplication *)application
{
    [self stopRefreshTimer];
}

- (void)handleBecameActive:(UIApplication *)application
{
    if (![fbHelper isLoggedIn])
    {
        // Return to the Facebook login screen
        // This is ugly, but it works
        [self.delegate welcomeViewController:nil didTapSignoutButton:nil];
    }
    else
    {
        if (self.refreshTimer == nil)
        {
            // Update the dinners periodically
            NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:refreshRate target:self selector:@selector(refreshDinners:) userInfo:nil repeats:YES];
            self.refreshTimer = timer;
        }
        
        // Force refresh now
        [self refreshDinners:nil];
        [SVProgressHUD show];
    }
}

#pragma mark -
#pragma mark Private methods

- (void)updateTitleBarAndFooter:(NSString *)searchText;
{
    dinnersFooterLabel.text = @"";
    
    switch(selectionMode)
    {
        case GENRE:
        {
            NSNumber *genreId = [genreIds objectAtIndex:[selectionTable indexPathForSelectedRow].row];
            titleItem.title = [app.tvCategories objectForKey:genreId];
            break;
        }
        case SEARCH:
            titleItem.title = [NSString stringWithFormat:@"%@ - %@", [selectionModeTitles objectForKey:[NSNumber numberWithInt:selectionMode]], searchText];
            break;
        case MY_FAVORITES:
            dinnersFooterLabel.text = @"Any show added to My Favorites will trigger a push notification when a dinner is live for that show.";
            // fall through on purpose
        default:
            titleItem.title = [selectionModeTitles objectForKey:[NSNumber numberWithInt:selectionMode]];
            break;
    }
}

- (void)searchDinners:(NSString *)text
{
    // Setup search result arrays
    NSMutableArray *array = [[NSMutableArray alloc] init];
    self.filteredOnNowShows = array;
    [array release];
    array = nil;
    
    array = [[NSMutableArray alloc] init];
    self.filteredOnLaterShows = array;
    [array release];
    
    [self filterDinnerArrayBySearch:app.tvDinnersArray filtered:filteredOnNowShows text:text];
    [self filterDinnerArrayBySearch:app.tvDinnersUpcomingArray filtered:filteredOnLaterShows text:text];    
}

- (void)filterFavoriteDinners
{
    // Setup result arrays
    NSMutableArray *array = [[NSMutableArray alloc] init];
    self.filteredOnNowShows = array;
    [array release];
    array = nil;
    
    array = [[NSMutableArray alloc] init];
    self.filteredOnLaterShows = array;
    [array release];
    
    [self filterDinnerArrayByFavorites:app.tvDinnersArray filtered:filteredOnNowShows];
    [self filterDinnerArrayByFavorites:app.tvDinnersUpcomingArray filtered:filteredOnLaterShows];    
}

- (void)filterGenreDinners
{
    // Setup result arrays
    NSMutableArray *array = [[NSMutableArray alloc] init];
    self.filteredOnNowShows = array;
    [array release];
    array = nil;
    
    array = [[NSMutableArray alloc] init];
    self.filteredOnLaterShows = array;
    [array release];
    
    [self filterDinnerArrayByGenre:app.tvDinnersArray filtered:filteredOnNowShows];
    [self filterDinnerArrayByGenre:app.tvDinnersUpcomingArray filtered:filteredOnLaterShows];   
    
}

- (void)filterDinnerArrayBySearch:(NSMutableArray *)original filtered:(NSMutableArray *)filtered text:(NSString *)text
{
    NSArray *searchTerms = [text componentsSeparatedByString:@" "];
    
    for (NSMutableDictionary *dinnerDictionary in original)
    {
        BOOL add = NO;
        
        NSString *showName = [dinnerDictionary objectForKey:@"ProgramName"];
		NSString *episodeName = [dinnerDictionary objectForKey:@"EpisodeName"];
        NSString *stationName = [dinnerDictionary objectForKey:@"ChannelName"];
        
        for (NSString *searchTerm in searchTerms)
        {
            if (!add) // short circuit if already found
            {
                if ([showName rangeOfString:searchTerm options:NSCaseInsensitiveSearch].location != NSNotFound ||
                    [episodeName rangeOfString:searchTerm options:NSCaseInsensitiveSearch].location != NSNotFound ||
                    [stationName rangeOfString:searchTerm options:NSCaseInsensitiveSearch].location != NSNotFound)
                {
                    add = YES;
                }
            }
        }
        
        if (add)
        {
            [filtered addObject:dinnerDictionary];
        }
    }
}

- (void)filterDinnerArrayByFavorites:(NSMutableArray *)original filtered:(NSMutableArray *)filtered 
{
    for (NSMutableDictionary *dinnerDictionary in original)
    {
        NSNumber *reminderId = [dinnerDictionary objectForKey:@"ReminderId"];
        if ([reminderManager searchTagById:[reminderId integerValue]])
        {
            [filtered addObject:dinnerDictionary];
        }
    }
}

- (void)filterDinnerArrayByGenre:(NSMutableArray *)original filtered:(NSMutableArray *)filtered
{
    NSNumber *genreId = [genreIds objectAtIndex:[selectionTable indexPathForSelectedRow].row];
    
    for (NSMutableDictionary *dinnerDictionary in original)
    {
        NSString *categoryId = [dinnerDictionary objectForKey:@"CategoryId"];
        
        if ([[genreId stringValue] isEqualToString:categoryId])
        {
            [filtered addObject:dinnerDictionary];
        }
    }
}

- (void)resizeDinnerTableFooter
{
    int origHeight = 120;
    int finalHeight = dinnersTable.frame.size.height;
    
    if (dinnerSections == 2) finalHeight -= ((22 + 2) * 2);
    finalHeight -= dinnerRows * (88 + 2);
    
    if (finalHeight < origHeight) finalHeight = origHeight;
    
    CGRect newFrame = dinnersTableFooterView.frame;
    newFrame.size.height = finalHeight;
    dinnersTableFooterView.frame = newFrame;
    
    //NSLog(@"Sections: %d", dinnerSections);
    //NSLog(@"Rows: %d", dinnerRows);
    //NSLog(@"Height: %d", finalHeight);
    
    // Center label
    newFrame = dinnersTableFooterLabel.frame;
    CGPoint newPoint = newFrame.origin;
    newPoint.y = (finalHeight/2) - (newFrame.size.height/2);
    newFrame.origin = newPoint;
    dinnersTableFooterLabel.frame = newFrame;
    
    // Center button
    newFrame = dinnersTableFooterButton.frame;
    newPoint = newFrame.origin;
    newPoint.y = (finalHeight/2) - (newFrame.size.height/2);
    newFrame.origin = newPoint;
    dinnersTableFooterButton.frame = newFrame;
}

#pragma mark -
#pragma mark Button actions

- (IBAction)requestShow:(id)sender
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://tv-dinner.com/shows"]];    
}

- (IBAction)editSettings:(id)sender
{
	settingsVC.delegate = self;
    UINavigationController *settingsNavigationController = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    settingsNavigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentModalViewController:settingsNavigationController animated:YES];
    settingsNavigationController.view.superview.frame = CGRectMake(0, 0, 512, 670);//it's important to do this after presentModalViewController
    settingsNavigationController.view.superview.center = self.view.center;//self.view assumes the base view is doing the launching, if not you might need self.view.superview.center etc.
    [settingsNavigationController release];    
}

- (IBAction)backToWelcome:(id)sender
{
    NSArray *array = [self.navigationController viewControllers];
    TVDinnerViewController *tvDinnerVC = [array objectAtIndex:0];
    [self.navigationController popToRootViewControllerAnimated:NO];
	[tvDinnerVC viewDidLoadWithoutAnimation];
}

#pragma mark -
#pragma mark Refresh timer methods

-(void)refreshDinners:(NSTimer *)timer
{
    [[AFTVDinnerAPIClient sharedClient] getPath:@"dinners" parameters:nil success:^(AFHTTPRequestOperation *operation, id xml) {
        [TVDXMLParser parseDinners:xml];
        self.genreIds = [app.tvCategories keysSortedByValueUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        
        // Preserve selected cell
        NSIndexPath *indexPath = [selectionTable indexPathForSelectedRow];
        
        [selectionTable reloadData];
        
        if (selectionMode == MY_FAVORITES)
        {
            [self filterFavoriteDinners];
        }
        
        if (selectionMode != SEARCH)
        {
            if (selectionMode == ON_NOW)
            {
                // Default to 'On Later' if no current dinners
                selectionMode = [app.tvDinnersArray count] ? ON_NOW : ON_LATER;
                indexPath = [NSIndexPath indexPathForRow:selectionMode inSection:0];
            }
            [selectionTable selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        }

        [dinnersTable reloadData];
        if ([SVProgressHUD isVisible]) [SVProgressHUD dismiss];
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if ([operation.response statusCode] == 412)
        {
            CXMLDocument *doc = [[[CXMLDocument alloc] initWithData:operation.responseData options:0 error:nil] autorelease];
            NSString *errorMsg = [TVDXMLParser stringForXPath:@"//RestResult/Message" ofNode:doc];
            
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"" message:errorMsg delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alertView show];
            [alertView release];
            
            [self.delegate welcomeViewController:nil didTapSignoutButton:nil];
        }
        NSLog(@"Error: %@", error);
        if ([SVProgressHUD isVisible]) [SVProgressHUD dismiss];
    }];
}

-(void)stopRefreshTimer
{
    [refreshTimer invalidate];
    self.refreshTimer = nil;
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections
    if (tableView == dinnersTable)
    {
        switch(selectionMode)
        {
            case MY_FAVORITES:
                if ([filteredOnNowShows count] && [filteredOnLaterShows count])
                {
                    noFavoritesView.hidden = YES;
                    dinnerSections = 2;
                }
                else if ([filteredOnNowShows count] || [filteredOnLaterShows count])
                {
                    noFavoritesView.hidden = YES;
                    dinnerSections = 1;
                }
                else
                {
                    noFavoritesView.hidden = NO;
                    dinnersFooterView.hidden = YES;
                    dinnersTable.hidden = YES;
                    dinnerSections = 0;
                }
                break;
            case SEARCH:
                if ([filteredOnNowShows count] && [filteredOnLaterShows count])
                {
                    noSearchResultsView.hidden = YES;
                    dinnerSections = 2;
                }
                else if ([filteredOnNowShows count] || [filteredOnLaterShows count])
                {
                    noSearchResultsView.hidden = YES;
                    dinnerSections = 1;
                }
                else
                {
                    noSearchResultsView.hidden = NO;
                    dinnersFooterView.hidden = YES;
                    dinnersTable.hidden = YES;
                    dinnerSections = 0;
                }
                break;
            case GENRE:
                if ([filteredOnNowShows count] && [filteredOnLaterShows count])
                {
                    dinnerSections = 2;
                }
                else
                {
                    dinnerSections = 1;
                }
                break;
            case ON_NOW:
            case ON_LATER:
            default:
                dinnerSections = 1;
                break;
        }
        return dinnerSections;
    }
    else if (tableView == selectionTable)
    {
        return 2;
    }
    else
    {
        return 0;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section
    if (tableView == dinnersTable)
    {
        switch (selectionMode)
        {
            case ON_NOW:
            {
                dinnerRows = [app.tvDinnersArray count];
                return [app.tvDinnersArray count];
            }
            case ON_LATER:
            {
                dinnerRows = [app.tvDinnersUpcomingArray count];
                
                if (dinnerRows == 0 && !dinnerFooterResized)
                {
                    // Dynamically center/resize footer
                    [self resizeDinnerTableFooter];
                    dinnerFooterResized = YES;
                }
                
                return [app.tvDinnersUpcomingArray count];
            }
            case MY_FAVORITES:
            case SEARCH:
            case GENRE:
                if (section == 0)
                {
                    if ([filteredOnNowShows count]) 
                    {
                        dinnerRows += [filteredOnNowShows count];
                        return [filteredOnNowShows count];
                    }
                    else
                    {
                        dinnerRows += [filteredOnLaterShows count];
                        return [filteredOnLaterShows count];
                    }
                }
                else if (section == 1)
                {
                    dinnerRows += [filteredOnLaterShows count];
                    return [filteredOnLaterShows count];
                }
            default:
                return 0;
        }
            
    }
    else if (tableView == selectionTable)
    {
        switch (section)
        {
            case 0:
                return 3;
                // return 4; // When 'Friends Favorites' is complete
            case 1:
                return [app.tvCategories count];
            default:
                return 0;
        }
    }
    else
    {
        return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (tableView == dinnersTable)
    {
        if ((selectionMode == SEARCH || selectionMode == MY_FAVORITES || selectionMode == GENRE) && dinnerSections > 1)
        {
            if (section == 0)
            {
                if ([filteredOnNowShows count]) return @"On Now";
                else return @"On Later";
            }
            else if (section == 1)
            {
                return @"On Later";
            }
        }
    }
    else if (tableView == selectionTable)
    {
        if (section == 1) return @"Genres";
    }
    
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == dinnersTable)
    {
        return 88;
    }
    else if (tableView == selectionTable)
    {
        return 44;
    }
    else
    {
        return 0;
    }
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == dinnersTable)
    {
        // Dynamically center/resize footer
        if (!dinnerFooterResized)
        {
            [self resizeDinnerTableFooter];
            dinnerFooterResized = YES;
        }        
        
        BOOL onNow = NO;
        
        NSMutableArray *dinnerArray;
        switch (selectionMode)
        {
            case ON_NOW:
                dinnerArray = app.tvDinnersArray;
                onNow = YES;
                break;
            case ON_LATER:
                dinnerArray = app.tvDinnersUpcomingArray;
                break;
            case MY_FAVORITES:
            case SEARCH:
            case GENRE:
            {
                NSInteger section = [indexPath section];
                if (section == 0)
                {
                    if ([filteredOnNowShows count])
                    {
                        dinnerArray = filteredOnNowShows;
                        onNow = YES;
                    }
                    else dinnerArray = filteredOnLaterShows;
                }
                else if (section == 1)
                {
                    dinnerArray = filteredOnLaterShows;
                }
                break;
            }
            default:
                return nil;
        }
        
        NSMutableDictionary *dinnerDictionary = [dinnerArray objectAtIndex:indexPath.row];
		NSString *showName = [dinnerDictionary objectForKey:@"ProgramName"];
		NSString *episodeName = [dinnerDictionary objectForKey:@"EpisodeName"];
        NSString *stationName = [dinnerDictionary objectForKey:@"ChannelName"];
        NSString *startTime = [dinnerDictionary objectForKey:@"AiringStartTime"];
        NSString *time = [[app formatTimeString:startTime] lowercaseString];
        NSString *weekday = [app formatDayOfWeekString:startTime];
        NSNumber *reminderId = [dinnerDictionary objectForKey:@"ReminderId"];
        NSNumber *menuColor = [dinnerDictionary objectForKey:@"MenuColor"];
        
        MainMenuDinnerCell *cell = [MainMenuDinnerCell dequeOrCreateInTable:tableView];
        cell.showLabel.text = showName;
        cell.episodeLabel.text = [NSString stringWithFormat:@"%@ | %@", episodeName, stationName];
        
        cell.dinnerArrayId = indexPath.row;
        cell.onNow = onNow;
        
        // Display "On Now" for current airings, otherwise display time and weekday
        if (onNow)
        {
            cell.onNowLabel.hidden = NO;
            cell.timeLabel.hidden = YES;
            cell.dayLabel.hidden = YES;
        }
        else
        {
            cell.onNowLabel.hidden = YES;
            cell.timeLabel.hidden = NO;
            cell.dayLabel.hidden = NO;
            cell.timeLabel.text = time;
            cell.dayLabel.text = weekday;
        }
        
        // Display full star for favorited shows
        if (selectionMode == MY_FAVORITES || [reminderManager searchTagById:[reminderId integerValue]])
        {
            [cell.favoriteButton setBackgroundImage:[UIImage imageNamed:@"fullstar.png"] forState:UIControlStateNormal];
            cell.favorite = YES;
        }
        else
        {
            [cell.favoriteButton setBackgroundImage:[UIImage imageNamed:@"emptystar.png"] forState:UIControlStateNormal];
            cell.favorite = NO;
        }
        cell.reminderId = [reminderId integerValue];
        cell.reminderManager = reminderManager;
        cell.mainMenu = self;
        
        cell.favoriteButton.hidden = NO;
        [cell.spinner stopAnimating];
        cell.spinner.hidden = YES;
        
        // Color in cell gradients
        UIColor *topGradient = UIColorFromRGB(0x1b1f24);
        UIColor *bottomGradient = UIColorFromRGB(0x090b0c);

        CAGradientLayer *showGradient = [CAGradientLayer layer];
        showGradient.frame = cell.showBkgdView.bounds;
        showGradient.colors = [NSArray arrayWithObjects:(id)[topGradient CGColor], (id)[bottomGradient CGColor], nil];
        [cell.showBkgdView.layer insertSublayer:showGradient atIndex:0];

        topGradient = UIColorFromRGB(0x23272e);
        bottomGradient = UIColorFromRGB(0x1c1e23);

        CAGradientLayer *timeGradient = [CAGradientLayer layer];
        timeGradient.frame = cell.timeBkgdView.bounds;
        timeGradient.colors = [NSArray arrayWithObjects:(id)[topGradient CGColor], (id)[bottomGradient CGColor], nil];
        [cell.timeBkgdView.layer insertSublayer:timeGradient atIndex:0];
        
        if ([menuColor intValue] > 0)
        {
            [cell.genreColor setBackgroundColor:UIColorFromRGB([menuColor intValue])];
        }
        else 
        {
            // Default color
            [cell.genreColor setBackgroundColor:UIColorFromRGB(0x808080)];
        }

        return cell;
    }
    else if (tableView == selectionTable)
    {
        static NSString *cellIdentifier = @"selectionCell"; 
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if (cell == nil)
        {
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier] autorelease];
        }
        
        NSInteger section = [indexPath section];
        switch (section)
        {
            case 0:
                cell.textLabel.text = [selectionModeTitles objectForKey:[NSNumber numberWithInteger:indexPath.row]];
                cell.imageView.image = [UIImage imageNamed:@"tv_icon.png"];
                
                // Reset cell
                cell.imageView.alpha = 1;
                cell.textLabel.alpha = 1;
                cell.userInteractionEnabled = YES;
                
                // Via: http://stackoverflow.com/questions/5905608/how-do-i-make-a-uitableviewcell-appear-disabled
                CGFloat disabledAplha = 0.439216f; // (1 - alpha) * 255 = 143
                
                // Disable "On Now" when there's no currently airing dinners
                if (indexPath.row == ON_NOW && [app.tvDinnersArray count] == 0)
                {
                    cell.imageView.alpha = disabledAplha;
                    cell.textLabel.alpha = disabledAplha;
                    cell.userInteractionEnabled = NO;
                }
                else if (indexPath.row == MY_FAVORITES && !([[ReminderManager sharedInstance] hasValidUaTags] && [[ReminderManager sharedInstance] hasValidPrograms]))
                {
                    cell.imageView.alpha = disabledAplha;
                    cell.textLabel.alpha = disabledAplha;
                    cell.userInteractionEnabled = NO;                    
                }
                break;
            case 1:
                //NSLog(@"Genres: %@", genreIds);
                cell.textLabel.text = [app.tvCategories objectForKey:[genreIds objectAtIndex:indexPath.row]];
                cell.tag = [[genreIds objectAtIndex:indexPath.row] integerValue];
                break;
            default:
                break;
        }
        
        return cell;
    }
    else
    {
        return nil;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == dinnersTable)
    {
        if (app.tvDinnersArray != nil && [app.tvDinnersArray count] > 0)
        {
            MainMenuDinnerCell *cell = (MainMenuDinnerCell*)[tableView cellForRowAtIndexPath:indexPath];
            if (cell.onNow)
            {
                [app playSound:6:0];
                
                if (selectionMode != ON_NOW)
                {
                    NSMutableDictionary *filteredDict = [filteredOnNowShows objectAtIndex:cell.dinnerArrayId];
                    NSString *filteredDinnerId = [filteredDict objectForKey:@"TvdinnerId"];
                    
                    int i;
                    for (i = 0; i < [app.tvDinnersArray count]; i++)
                    {
                        NSMutableDictionary *tempDinnerDict = [app.tvDinnersArray objectAtIndex:i];
                        NSString *dinnerId = [tempDinnerDict objectForKey:@"TvdinnerId"];  
                        if ([dinnerId isEqualToString:filteredDinnerId]) break;
                    }
                    cell.dinnerArrayId = i;
                }
                
                //NSMutableDictionary *dinnerDict = [app.tvDinnersArray objectAtIndex:cell.dinnerArrayId];
                //NSString *dinnerId = [dinnerDict objectForKey:@"TvdinnerId"];
                //NSString *dinnerAiringEndTime = [dinnerDict objectForKey:@"AiringEndTime"];
                //NibbleReplyCountStore *nibbleReplyCountStore = [[NibbleReplyCountStore alloc] initWithDinnerId:dinnerId andAiringEndTime:dinnerAiringEndTime];
                
                // Clear the ImageDownloader memory cache here, before we start loading home screen images.
                [ImageDownloader clearMemoryCache];
                
                HomeVC *homeVC = [[HomeVC alloc]initWithNibName:@"HomeVC" bundle:nil];
                homeVC.m_nCurrentTVDinner = cell.dinnerArrayId;
                //homeVC.nibbleReplyCountStore = nibbleReplyCountStore;
                //[nibbleReplyCountStore release];
                
                [self.navigationController pushViewController:homeVC animated:NO];
                [homeVC release];
            }
        }
        else
        {
            // Force refresh
            [self refreshDinners:nil];
            [SVProgressHUD show];
        }
    }
    else if (tableView == selectionTable)
    {
        // Clear search bar and hide keyboard
        showSearchBar.text = @"";
        [showSearchBar endEditing:YES];
        
        noFavoritesView.hidden = YES;
        noSearchResultsView.hidden = YES;
        dinnersFooterView.hidden = NO;
        dinnersTable.hidden = NO;
        [dinnersTable setContentOffset:CGPointMake(0, 0) animated:NO];
        dinnersTable.scrollEnabled = YES;
        
        dinnerRows = 0;
        dinnerSections = 0;
        dinnerFooterResized = NO;
        
        NSInteger section = [indexPath section];
        switch (section)
        {
            case 0:
                if (indexPath.row == 0) selectionMode = ON_NOW;
                else if (indexPath.row == 1) selectionMode = ON_LATER;
                else if (indexPath.row == 2) 
                {
                    selectionMode = MY_FAVORITES;
                    [self filterFavoriteDinners];
                }
                else if (indexPath.row == 3) selectionMode = FRIENDS_FAVORITES;
                break;
            case 1:
                selectionMode = GENRE;
                [self filterGenreDinners];
                break;
            default:
                break;
        }
        
        [self updateTitleBarAndFooter:nil];
        [dinnersTable reloadData];
    }
    
}

#pragma mark -
#pragma mark Search bar delegate

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    selectionMode = SEARCH;
    [selectionTable deselectRowAtIndexPath:[selectionTable indexPathForSelectedRow] animated:NO];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    noSearchResultsView.hidden = YES;
    dinnersFooterView.hidden = NO;
    
    dinnerRows = 0;
    dinnerSections = 0;
    dinnerFooterResized = NO;
    
    dinnersTable.hidden = NO;
    dinnersTable.scrollEnabled = YES;
    
    // Hide keyboard
    [showSearchBar endEditing:YES];

    [self searchDinners:searchBar.text];
    [self updateTitleBarAndFooter:searchBar.text];
    
    // Clear search bar
    showSearchBar.text = @"";
    
    [dinnersTable reloadData];
}

#pragma mark -
#pragma mark Settings delegate methods

- (void)settingsViewController:(SettingsViewController *)controller didTapToDismissViewController:(id)sender
{
    [self dismissModalViewControllerAnimated:YES];
    [avatarImage setImage:controller.userThumb];
	settingsVC.delegate = nil;
    
    if (selectionMode == MY_FAVORITES)
    {
        [self filterFavoriteDinners];
    }
    [dinnersTable reloadData];
}

- (void)settingsViewControllerDidTapSignOut:(SettingsViewController *)controller
{
    [self dismissModalViewControllerAnimated:NO];
    settingsVC.delegate = nil;
	[self.delegate welcomeViewController:nil didTapSignoutButton:nil];
}

#pragma mark -
#pragma mark - UA delegates

- (void)addTagToDeviceSucceeded:(ASIHTTPRequest *)request
{
    if (request.responseStatusCode != 200 && request.responseStatusCode != 201)
    {
        [self addTagToDeviceFailed:request];
    } 
    else
    {
        NSDictionary* userInfo = request.userInfo;
        NSString *tag = [userInfo valueForKey:@"tag"];
        //NSMutableDictionary *extraInfo = [userInfo valueForKey:@"extraInfo"];
        
        [reminderManager addTagAndNotify:tag];
        
        if (![[[UAPush shared] tags] containsObject:tag]) {
            [[[UAPush shared] tags] addObject:tag];
        }
        
        NSLog(@"UA: Added: %@", tag);
        [dinnersTable reloadData];
    }    
}

- (void)addTagToDeviceFailed:(ASIHTTPRequest *)request
{
    NSDictionary *userInfo = request.userInfo;
    NSString *tag = [userInfo valueForKey:@"tag"];
    //NSMutableDictionary *extraInfo = [userInfo valueForKey:@"extraInfo"];
    NSLog(@"UA: Add failed: %@ -> %@", tag, request.error);
    
    [dinnersTable reloadData];
}

- (void)removeTagFromDeviceSucceeded:(ASIHTTPRequest *)request
{
    switch (request.responseStatusCode) {
        case 204://just removed
        case 404://already removed
            {
                NSDictionary *userInfo = request.userInfo;
                NSString *tag = [userInfo valueForKey:@"tag"];
                //NSMutableDictionary *extraInfo = [userInfo valueForKey:@"extraInfo"];
                
                [reminderManager removeTagAndNotify:tag];
                
                NSLog(@"UA: Removed: %@", tag);
                
                if (selectionMode == MY_FAVORITES)
                {
                    [self filterFavoriteDinners];
                }
                [dinnersTable reloadData];
            }
            break;
            
        default:
            [self removeTagFromDeviceFailed:request];
            break;
    }    
}

- (void)removeTagFromDeviceFailed:(ASIHTTPRequest *)request
{
    NSDictionary *userInfo = request.userInfo;
    NSString *tag = [userInfo valueForKey:@"tag"];
    //NSMutableDictionary *extraInfo = [userInfo valueForKey:@"extraInfo"];
    NSLog(@"UA: Removal failed: %@ -> %@", tag, request.error);

    [dinnersTable reloadData];
    
}

@end
