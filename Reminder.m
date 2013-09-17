#import "Reminder.h"

#define REMINDER_NAME @"name"
#define REMINDER_ID @"showId"

@implementation Reminder

@synthesize name;
@synthesize showId;

- (NSString*)getUATag
{
    return [NSString stringWithFormat:@"%@ %@", showId, [[NSTimeZone localTimeZone] name]];
}

#pragma mark - 
#pragma mark NSCoding Protocol

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:name forKey:REMINDER_NAME];
    [aCoder encodeObject:showId forKey:REMINDER_ID];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self.name = [aDecoder decodeObjectForKey:REMINDER_NAME];
    self.showId = [aDecoder decodeObjectForKey:REMINDER_ID];
    return self;
}

@end
