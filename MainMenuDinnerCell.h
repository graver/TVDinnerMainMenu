//
//  MainMenuDinnerCell.h
//  TVDinner
//
//  Created by Ben on 2/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UITableViewCell+NIB.h"
#import "ReminderManager.h"
#import "MainMenuVC.h"

@interface MainMenuDinnerCell : UITableViewCell
{
    MainMenuVC *mainMenu;
    ReminderManager *reminderManager;
    
    IBOutlet UIView *showBkgdView;
    IBOutlet UIView *timeBkgdView;
    IBOutlet UIView *genreColor;
    
    IBOutlet UILabel *showLabel;
    IBOutlet UILabel *episodeLabel;
    IBOutlet UILabel *timeLabel;
    IBOutlet UILabel *dayLabel;
    IBOutlet UILabel *onNowLabel;
    
    IBOutlet UIButton *favoriteButton;
    IBOutlet UIActivityIndicatorView *spinner;
    
    BOOL favorite;
    BOOL onNow;
    
    NSInteger reminderId;
    NSInteger dinnerArrayId;
}

@property (nonatomic, retain) IBOutlet UIView *showBkgdView;
@property (nonatomic, retain) IBOutlet UIView *timeBkgdView;
@property (nonatomic, retain) IBOutlet UIView *genreColor;
@property (nonatomic, retain) IBOutlet UILabel *showLabel;
@property (nonatomic, retain) IBOutlet UILabel *episodeLabel;
@property (nonatomic, retain) IBOutlet UILabel *timeLabel;
@property (nonatomic, retain) IBOutlet UILabel *dayLabel;
@property (nonatomic, retain) IBOutlet UILabel *onNowLabel;
@property (nonatomic, retain) IBOutlet UIButton *favoriteButton;
@property (nonatomic, retain) IBOutlet UIActivityIndicatorView *spinner;

@property (nonatomic, assign) BOOL favorite;
@property (nonatomic, assign) BOOL onNow;

@property (nonatomic, assign) MainMenuVC *mainMenu;
@property (nonatomic, assign) ReminderManager *reminderManager;
@property (nonatomic, assign) NSInteger reminderId;
@property (nonatomic, assign) NSInteger dinnerArrayId;

//- (void)runPopAnimation;

@end
