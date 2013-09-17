#define REMINDER_KEY @"reminderKey"

@interface Reminder : NSObject <NSCoding> {
    NSString *name;
    NSNumber *showId;
}

@property(nonatomic, retain) NSString *name;
@property(nonatomic, retain) NSNumber *showId;

- (NSString*)getUATag;

@end
