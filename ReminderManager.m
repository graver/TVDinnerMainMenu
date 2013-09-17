#import "ReminderManager.h"
#import "UAirship.h"
#import "UAPush.h"
#import "ASIHTTPRequest.h"
#import "NSString+SBJSON.h"
#import "Constant.h"
#import "TouchXML.h"

@implementation ReminderManager

@synthesize timeZone;
@synthesize uaTags;
@synthesize allTvPrograms;
@synthesize tvPrograms;
@synthesize hasValidUaTags;
@synthesize hasValidPrograms;
@synthesize fetchingUaTags;
@synthesize fetchingPrograms;

static ReminderManager *sharedInstance = NULL;

+ (ReminderManager *)sharedInstance {
	@synchronized (self) {
		if (sharedInstance == NULL) {
			sharedInstance = [[self alloc] init];
		}
	}
	
	return sharedInstance;
}

- (id)init {
    self = [super init];
    if (self) {
        app = (TVDinnerAppDelegate *)[[UIApplication sharedApplication] delegate]; 
        timeZone = [[NSTimeZone localTimeZone] name];
        checkedUaTagsTimezones = NO;
        uaTags = [[NSMutableArray alloc] init];
        tvPrograms = [[NSMutableDictionary alloc] init];
        allTvPrograms = [[NSMutableDictionary alloc] init];
        hasValidUaTags = NO;
        hasValidPrograms = NO;
        fetchingUaTags = NO;
        fetchingPrograms = NO;
        
        NSArray *eastern = [NSArray arrayWithObjects:@"America/New_York", @"America/Detroit", @"America/Kentucky/Louisville", @"America/Kentucky/Monticello", @"America/Indiana/Indianapolis", @"America/Indiana/Vincennes", @"America/Indiana/Winamac", @"America/Indiana/Marengo", @"America/Indiana/Petersburg", @"America/Indiana/Vevay", nil];
        NSArray *central = [NSArray arrayWithObjects:@"America/Chicago", @"America/Indiana/Tell_City", @"America/Indiana/Knox", @"America/Menominee", @"America/North_Dakota/Center", @"America/North_Dakota/New_Salem", nil];
        NSArray *mountain = [NSArray arrayWithObjects:@"America/Denver", @"America/Boise", @"America/Shiprock", nil];
        NSArray *arizona = [NSArray arrayWithObjects:@"America/Phoenix", nil];
        NSArray *pacific = [NSArray arrayWithObjects:@"America/Los_Angeles", nil];
        NSArray *alaska = [NSArray arrayWithObjects:@"America/Anchorage", @"America/Juneau", @"America/Yakutat", @"America/Nome", nil];
        NSArray *hawaii = [NSArray arrayWithObjects:@"Pacific/Honolulu", nil];
        
        NSDictionary *timeZones = [[[NSDictionary alloc] initWithObjectsAndKeys:
            eastern, @"America/New_York",
            central, @"America/Chicago",
            mountain, @"America/Denver",
            arizona, @"America/Phoenix",
            pacific, @"America/Los_Angeles",
            alaska, @"America/Juneau",
            hawaii, @"Pacific/Honolulu", nil] autorelease];
        
        // Normalize timezone
        [timeZones enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop){
            if ([timeZone isEqualToString:key] || [obj indexOfObject:timeZone] != NSNotFound)
            {
                timeZone = key;
                *stop = YES;
            }
        }];
    }
    return self;
}

- (void)dealloc {
    
    if (uaTags != nil)
    {
        [uaTags release];
    }
    
    if (tvPrograms != nil)
    {
        [tvPrograms release];
    }
    
    if (allTvPrograms != nil)
    {
        [allTvPrograms release];
    }
    
    [timeZone release];
    [super dealloc];
}

- (BOOL)searchTagById:(NSInteger)item {
    BOOL hasItem = NO;
    for (NSString *tag in uaTags)
    {
        NSArray *uaTagComps = [tag componentsSeparatedByString:@" "];
        if ([uaTagComps count] > 1) {
            NSString *uaTagId = [uaTagComps objectAtIndex:UA_TAG_ID];
            if ([uaTagId integerValue] == item ) {
                hasItem = YES;
                break;
            }
        }
    }
    return hasItem;
}

- (NSString *)retrieveTagById:(NSInteger)item {
    NSString *foundTag = nil;
    for (NSString *tag in uaTags)
    {
        NSArray *uaTagComps = [tag componentsSeparatedByString:@" "];
        if ([uaTagComps count] > 1) {
            NSString *uaTagId = [uaTagComps objectAtIndex:UA_TAG_ID];
            if ([uaTagId integerValue] == item ) {
                foundTag = tag;
                break;
            }
        }
    }
    return foundTag;
}

- (void)addTagAndNotify:(NSString *)tag
{
    [self willChangeValueForKey:@"uaTags"];
    [uaTags addObject:tag];
    [self didChangeValueForKey:@"uaTags"];
}

- (void)removeTagAndNotify:(NSString *)tag
{
    [self willChangeValueForKey:@"uaTags"];
    [uaTags removeObject:tag];
    [self didChangeValueForKey:@"uaTags"];    
}

#pragma mark -
#pragma mark TV Programs

- (void)fetchPrograms
{ 
    fetchingPrograms = YES;
    
    NSString *urlString = [NSString stringWithFormat:@"%@programs",ServerName];
    NSString *encodedString = [urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSURL *url = [NSURL URLWithString:encodedString];
    
    __block ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
    [request setRequestMethod:@"GET"];
    
    [request setCompletionBlock:^{
        if ([request responseStatusCode] == 412) {
            [request failWithError:nil];
            return;
        }
        
        fetchingPrograms = NO;
        hasValidPrograms = YES;
        
        NSData *XMLData = [request responseData];
        CXMLDocument *doc = [[[CXMLDocument alloc] initWithData:XMLData options:0 error:nil] autorelease];
        NSArray *programs = [app nodesForXPath:@"//Program" ofNode:doc error:nil];
        
        NSMutableDictionary *newDict = [[NSMutableDictionary alloc] init];
        self.tvPrograms = newDict;
        [newDict release];
        newDict = nil;
        
        newDict = [[NSMutableDictionary alloc] init];
        self.allTvPrograms = newDict;
        [newDict release];
    
        for (CXMLElement *program in programs)
        {
            NSString *programName = [app stringForXPath:@"ProgramName" ofNode:program];
            NSString *programId = [app stringForXPath:@"ReminderId" ofNode:program];
            NSString *programStatus = [app stringForXPath:@"Status" ofNode:program];
            
            if (programName != nil && programId != nil)
            {
                NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
                [f setNumberStyle:NSNumberFormatterDecimalStyle];
                NSNumber *programIdNum = [f numberFromString:programId];
                [f release];
                
                // programIdNum will be nil if formatting fails
                if (programIdNum != nil)
                {
                    if ([programStatus isEqualToString:@"Active"])
                    {
                        [self.tvPrograms setObject:programName forKey:programIdNum];
                    }
                    [self.allTvPrograms setObject:programName forKey:programIdNum];
                }
            }
        }
        
        NSLog(@"Programs: %@", tvPrograms);
    }];
    
    [request setFailedBlock:^{
        fetchingPrograms = NO;
        hasValidPrograms = NO;
        
        NSMutableDictionary *newDict = [[NSMutableDictionary alloc] init];
        self.tvPrograms = newDict;
        [newDict release];
        newDict = nil;
        
        newDict = [[NSMutableDictionary alloc] init];
        self.allTvPrograms = newDict;
        [newDict release];
    }];

    [request startAsynchronous];
}

#pragma mark -
#pragma mark Urban Airship calls

- (void)fetchUaTags
{ 
    fetchingUaTags = YES;
    
    NSString *urlString = [NSString stringWithFormat:@"%@/api/device_tokens/%@/tags/",
                           [[UAirship shared] server],
                           [[UAirship shared] deviceToken]];
    NSString *encodedString = [urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSURL *url = [NSURL URLWithString:encodedString];
    
    __block ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
    [request setRequestMethod:@"GET"];
    request.username = [UAirship shared].appId;
    request.password = [UAirship shared].appSecret;
    request.timeOutSeconds = 60;
    
    [request setCompletionBlock:^{
        if ([request responseStatusCode] == 404) {
            [request failWithError:nil];
            return;
        }
        
        fetchingUaTags = NO;
        hasValidUaTags = YES;
        
        NSString *responseString = [request responseString];
        NSDictionary *tagsDic = [responseString JSONValue];
        NSArray *tags = [tagsDic objectForKey:@"tags"];
        self.uaTags = [tags mutableCopy];
        [self checkUaTagsTimezones];
        
        //NSLog(@"fetchUaTags: %@", uaTags);
    }];
    
    [request setFailedBlock:^{
        fetchingUaTags = NO;
        hasValidUaTags = NO;
        
        NSMutableArray *newArray = [[NSMutableArray alloc] init];
        self.uaTags = newArray;
        [newArray release];
    }];
    
    [request startAsynchronous];
}

-(void)checkUaTagsTimezones
{
    if (!checkedUaTagsTimezones && (timeZone.length != 0))
    {
        __block BOOL needToUpdateAU = NO;
        
        NSArray *tempArray = [NSArray arrayWithArray:uaTags];
        [tempArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
        {
            NSArray *uaTagComps = [(NSString*)obj componentsSeparatedByString:@" "];
            
            if ([uaTagComps count] > 1)
            {
                NSString *uaTagId = [uaTagComps objectAtIndex:UA_TAG_ID];
                NSString *uaTagTimezone = [uaTagComps objectAtIndex:UA_TAG_TIMEZONE];
                
                // If the UA tag exists for a different timezone
                if (![timeZone isEqualToString:uaTagTimezone])
                {
                    // Modify timezone
                    [uaTags replaceObjectAtIndex:idx withObject:[NSString stringWithFormat:@"%@ %@", uaTagId, timeZone]];
                    needToUpdateAU = YES;
                }
                else
                {
                    if (needToUpdateAU) NSLog(@"WARN: Urban Airship show groups exist for different timezones!");
                }
            }            
        }];
        
        // TODO: Would be nice if we could call UAPush's saveDefaults but it's private
        [UAPush shared].tags = uaTags;
        
        if (needToUpdateAU)
        {
            // Update Urban Airship with modified tags
            [[UAPush shared] updateRegistration];
        }
        
        checkedUaTagsTimezones = YES;
    }
}

- (void)addTagToCurrentDevice:(NSString *)tag delegate:(id)delegate withExtraInfo:(NSMutableDictionary *)extraInfo
{
    NSLog(@"UA: Attempting to add: %@", tag);  
    NSString *urlString = [NSString stringWithFormat:@"%@/api/device_tokens/%@/tags/%@",
                           [[UAirship shared] server],
                           [[UAirship shared] deviceToken],
                           tag];
    NSString *encodedString = [urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSURL *url = [NSURL URLWithString:encodedString];
    
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
    [request setRequestMethod:@"PUT"];
    request.username = [UAirship shared].appId;
    request.password = [UAirship shared].appSecret;
    [request setDidFinishSelector:@selector(addTagToDeviceSucceeded:)];
    [request setDidFailSelector:@selector(addTagToDeviceFailed:)];
    [request setDelegate:delegate];
    
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    [userInfo setValue:tag forKey:@"tag"];
    if (extraInfo) {
        [userInfo setValue:extraInfo forKey:@"extraInfo"];
    }
    request.userInfo = userInfo;
    
    [request startAsynchronous];
}

- (void)removeTagFromCurrentDevice:(NSString *)tag delegate:(id)delegate withExtraInfo:(NSMutableDictionary *)extraInfo
{
    NSLog(@"UA: Attempting to remove: %@", tag);  
    NSString *urlString = [NSString stringWithFormat:@"%@/api/device_tokens/%@/tags/%@",
                           [[UAirship shared] server],
                           [[UAirship shared] deviceToken],
                           tag];
    NSString *encodedString = [urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSURL *url = [NSURL URLWithString:encodedString];
    
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
    [request setRequestMethod:@"DELETE"];
    request.username = [UAirship shared].appId;
    request.password = [UAirship shared].appSecret;
    request.timeOutSeconds = 60;
    [request setDidFinishSelector:@selector(removeTagFromDeviceSucceeded:)];
    [request setDidFailSelector:@selector(removeTagFromDeviceFailed:)];
    [request setDelegate:delegate];
    
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    [userInfo setValue:tag forKey:@"tag"];
    if (extraInfo) {
        [userInfo setValue:extraInfo forKey:@"extraInfo"];
    }
    request.userInfo = userInfo;
    
    [request startAsynchronous];
}


@end
