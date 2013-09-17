//
//  MainMenuDinnerCell.m
//  TVDinner
//
//  Created by Ben on 2/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MainMenuDinnerCell.h"
#import <QuartzCore/QuartzCore.h>

// Number of pixels by which the star expands in each direction when
// playing the "pop" animation.
#define POPPED_STAR_SIZE_OFFSET 8



@interface MainMenuDinnerCell (Private)
- (IBAction)favoriteClicked:(id)sender;
@end

@implementation MainMenuDinnerCell

@synthesize showBkgdView, timeBkgdView;
@synthesize genreColor, showLabel, episodeLabel, timeLabel, dayLabel, onNowLabel, favoriteButton, spinner;
@synthesize favorite, onNow, reminderManager, mainMenu, reminderId, dinnerArrayId;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        reminderId = 0;
        dinnerArrayId = 0;
        favorite = NO;
        onNow = NO;
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)dealloc
{
    [showBkgdView release];
    [timeBkgdView release];
    [genreColor release];
    [showLabel release];
    [episodeLabel release];
    [timeLabel release];
    [dayLabel release];
    [onNowLabel release];
    [favoriteButton release];
    [spinner release];
    
    mainMenu = nil;
    
    [super dealloc];
}

- (IBAction)favoriteClicked:(id)sender
{
    NSString *tag = [NSString stringWithFormat:@"%ld %@", reminderId, [reminderManager timeZone]];
    NSMutableDictionary *extraInfo = [[[NSMutableDictionary alloc] init] autorelease];
    //[extraInfo setValue:indexPath forKey:@"indexPath"];
    
    if (favorite)
    {
        [reminderManager removeTagFromCurrentDevice:tag delegate:mainMenu withExtraInfo:extraInfo];
    }
    else
    {
        [reminderManager addTagToCurrentDevice:tag delegate:mainMenu withExtraInfo:extraInfo];
    }
    
    favoriteButton.hidden = YES;
    spinner.hidden = NO;
    [spinner startAnimating];
}

- (void)runPopAnimation
{
    // Start part 1 of the pop animation.
    [UIView setAnimationsEnabled:YES];
    [UIView beginAnimations:@"Pop1" context:NULL];
    [UIView setAnimationDuration:0.5];
    [UIView setAnimationDelegate:self];
    
    CGRect frame = favoriteButton.frame;
    frame.origin.x -= POPPED_STAR_SIZE_OFFSET / 2;
    frame.origin.y -= POPPED_STAR_SIZE_OFFSET / 2;
    frame.size.width += POPPED_STAR_SIZE_OFFSET;
    frame.size.height += POPPED_STAR_SIZE_OFFSET;
    favoriteButton.frame = frame;
    
    [UIView commitAnimations];
}

- (void)animationDidStop:(NSString *)animationID finished:(BOOL)finished context:(void *)context
{
    // If the first half of the animation finished, run the second half.
    if (animationID == @"Pop1")
    {
        [UIView beginAnimations:@"Pop2" context:NULL];
        [UIView setAnimationDuration:0.5];
        [UIView setAnimationDelegate:self];
        
        CGRect frame = favoriteButton.frame;
        frame.origin.x += POPPED_STAR_SIZE_OFFSET / 2;
        frame.origin.y += POPPED_STAR_SIZE_OFFSET / 2;
        frame.size.width -= POPPED_STAR_SIZE_OFFSET;
        frame.size.height -= POPPED_STAR_SIZE_OFFSET;
        favoriteButton.frame = frame;
        
        [UIView commitAnimations];        
    }
}

@end
