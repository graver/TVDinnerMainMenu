//
//  MainMenuVC.h
//  TVDinner
//
//  Created by Ben on 2/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TVDinnerAppDelegate.h"
#import "ReminderManager.h"
#import "SettingsViewController.h"
#import "WelcomeViewController.h"
#import "ASIHTTPRequest.h"

typedef enum
{
    ON_NOW = 0,
    ON_LATER = 1,
    MY_FAVORITES = 2,
    FRIENDS_FAVORITES = 3,
    GENRE = 4,
    SEARCH = 5
} MainMenuMode;

@interface MainMenuVC : UIViewController <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, SettingsViewControllerDelegate>
{
    TVDinnerAppDelegate *app;
    ReminderManager *reminderManager;
    SettingsViewController *settingsVC;
    FacebookHelper *fbHelper;
    
    IBOutlet UIView *dinnersTableFooterView;
    //IBOutlet UISearchBar *dinnersTableFooterSearchBar;
    IBOutlet UIButton *dinnersTableFooterButton;
    IBOutlet UILabel *dinnersTableFooterLabel;
    
    IBOutlet UIView *noFavoritesView;
    IBOutlet UIView *noSearchResultsView;
    IBOutlet UIView *dinnersFooterView;
    IBOutlet UILabel *dinnersFooterLabel;
    IBOutlet UIButton *requestShowButton;
    IBOutlet UITableView *dinnersTable;
    IBOutlet UITableView *selectionTable;

    
    IBOutlet UINavigationItem *titleItem;
    IBOutlet UIBarButtonItem *backButton;
    IBOutlet UISearchBar *showSearchBar;
    IBOutlet UIImageView *avatarImage;
    IBOutlet UIButton *settingsButton;
    
    MainMenuMode selectionMode;
    NSDictionary *selectionModeTitles;
    
    NSMutableArray *filteredOnNowShows;
    NSMutableArray *filteredOnLaterShows;
    NSArray *genreIds;
    
    NSTimer *refreshTimer;
    
    id<WelcomeViewControllerDelegate> delegate;
    
    int dinnerSections;
    int dinnerRows;
    BOOL dinnerFooterResized;
}

@property (nonatomic, retain) SettingsViewController *settingsVC;

@property (nonatomic, retain) IBOutlet UIView *noFavoritesView;
@property (nonatomic, retain) IBOutlet UIView *noSearchResultsView;
@property (nonatomic, retain) IBOutlet UIView *dinnersFooterView;
@property (nonatomic, retain) IBOutlet UIView *dinnersTableFooterView;
//@property (nonatomic, retain) IBOutlet UISearchBar *dinnersTableFooterSearchBar;
@property (nonatomic, retain) IBOutlet UIButton *dinnersTableFooterButton;
@property (nonatomic, retain) IBOutlet UILabel *dinnersTableFooterLabel;
@property (nonatomic, retain) IBOutlet UILabel *dinnersFooterLabel;
@property (nonatomic, retain) IBOutlet UIButton *requestShowButton;
@property (nonatomic, retain) IBOutlet UITableView *dinnersTable;
@property (nonatomic, retain) IBOutlet UITableView *selectionTable;
@property (nonatomic, retain) IBOutlet NSDictionary *selectionModeTitles;
@property (nonatomic, retain) IBOutlet UISearchBar *showSearchBar;
@property (nonatomic, retain) IBOutlet UIImageView *avatarImage;
@property (nonatomic, retain) IBOutlet UIButton *settingsButton;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *backButton;

@property (nonatomic, retain) NSMutableArray *filteredOnNowShows;
@property (nonatomic, retain) NSMutableArray *filteredOnLaterShows;
@property (nonatomic, retain) NSArray *genreIds;

@property (assign) NSTimer *refreshTimer;

@property (nonatomic, assign) id<WelcomeViewControllerDelegate> delegate;

- (IBAction)requestShow:(id)sender;
- (IBAction)editSettings:(id)sender;
- (IBAction)backToWelcome:(id)sender;

-(void)refreshDinners:(NSTimer *)timer;
-(void)stopRefreshTimer;

- (void)addTagToDeviceSucceeded:(ASIHTTPRequest *)request;
- (void)addTagToDeviceFailed:(ASIHTTPRequest *)request;
- (void)removeTagFromDeviceSucceeded:(ASIHTTPRequest *)request;
- (void)removeTagFromDeviceFailed:(ASIHTTPRequest *)request;

@end
