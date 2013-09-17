#import "TVDinnerAppDelegate.h"
#import "Reminder.h"

#define UA_TAG_ID       0
#define UA_TAG_TIMEZONE 1

@interface ReminderManager : NSObject {
    
    TVDinnerAppDelegate *app;
    
    NSString *timeZone;
    NSMutableArray *uaTags;
    NSMutableDictionary *allTvPrograms; // Active + Inactive
    NSMutableDictionary *tvPrograms; // Active
    
    BOOL checkedUaTagsTimezones;
    BOOL hasValidUaTags;
    BOOL hasValidPrograms;
    
    BOOL fetchingUaTags;
    BOOL fetchingPrograms;
}

@property(nonatomic, retain) NSString *timeZone;

@property(nonatomic, retain) NSMutableArray *uaTags;
@property(nonatomic, retain) NSMutableDictionary *allTvPrograms;
@property(nonatomic, retain) NSMutableDictionary *tvPrograms;
@property(nonatomic, readonly) BOOL hasValidUaTags;
@property(nonatomic, readonly) BOOL hasValidPrograms;
@property(nonatomic, readonly) BOOL fetchingUaTags;
@property(nonatomic, readonly) BOOL fetchingPrograms;

- (BOOL)searchTagById:(NSInteger)item;
- (NSString *)retrieveTagById:(NSInteger)item;
- (void)addTagAndNotify:(NSString *)tag;
- (void)removeTagAndNotify:(NSString *)tag;

- (void)fetchUaTags;
- (void)checkUaTagsTimezones;

- (void) fetchPrograms;

- (void)addTagToCurrentDevice:(NSString *)tag delegate:(id)delegate withExtraInfo:(NSMutableDictionary *)extraInfo;
- (void)removeTagFromCurrentDevice:(NSString *)tag delegate:(id)delegate withExtraInfo:(NSMutableDictionary *)extraInfo;

+ (ReminderManager *)sharedInstance;

@end

