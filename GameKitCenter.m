//
//  GameKitCenter.m
//  GameKitCenter
//
//  Created by Hasyimi Bahrudin on 8/14/12.
//
//

#import "GameKitCenter.h"
#import <dispatch/dispatch.h>

BOOL IsGameCenterAPIAvailable()
{
    // Check for presence of GKLocalPlayer class.
    BOOL localPlayerClassAvailable = (NSClassFromString(@"GKLocalPlayer")) != nil;
    
    // The device must be running iOS 4.1 or later.
    NSString *reqSysVer = @"4.1";
    NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
    BOOL osVersionSupported = ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending);
    
    return (localPlayerClassAvailable && osVersionSupported);
}

//####################################################################################
// Default achievement class
//####################################################################################

@implementation StandardGameKitAchievement

@synthesize identifier, percentageCompleted, points;

+ (id)achievementWithDictionary:(NSDictionary *)dictionary
{
    return [[[self alloc] initWithDictionary:dictionary] autorelease];
}

- (id)initWithDictionary:(NSDictionary *)dictionary
{
	if ((self = [super init]))
	{
        identifier = [[dictionary objectForKey:@"Identifier"] copy];
        assert(identifier);
        
        points = [[dictionary objectForKey:@"Points"] intValue];
        assert(points > 0 && points <= 100);
        
        percentageCompleted = 0.0f;
	}
	
	return self;
}

- (void)dealloc
{
    [identifier release];
	[super dealloc];
}

- (NSDictionary *)save
{
    NSMutableDictionary *temp = [NSMutableDictionary dictionary];
    [temp setObject:[NSNumber numberWithDouble:percentageCompleted] forKey:@"PercentageCompleted"];
    return [NSDictionary dictionaryWithDictionary:temp];
}

- (void)loadFromDictionary:(NSDictionary *)dictionary
{
    assert([dictionary objectForKey:@"PercentageCompleted"]);
    percentageCompleted = [[dictionary objectForKey:@"PercentageCompleted"] doubleValue];
    assert(percentageCompleted >= 0.0 && percentageCompleted <= 100.0);
}

@end

//####################################################################################
// GameKitCenter private methods
//####################################################################################

@interface GameKitCenter ()

- (void)invokeDelegatesWithSelector:(SEL)selector andObject:(id<NSObject>)object;

/** Synchronizes Game Center's achievements with local achievements.
 This ensures that achievements on both side are equal.
 This method is automatically when the local player is authenicated.
 */
- (void)syncAchievementsWithGameCenter;

/** Synchronizes Game Center's scores with local scores.
 This ensures that scores on both side are equal.
 This method is automatically when the local player is authenicated.
 */
- (void)syncScoresWithGameCenter;

/** Reports achievements that failed to be submitted to GC.
    This method will be scheduled automatically.
    This method is only used for iOS 4.3 and lower.
 */
- (void)reportFailedAchievements;

/** Loads achievements progress from GC.
 */
- (void)loadGCAchievements;

/** Compares the local achievements with the GC achievements.
    Warnings will be issued when achievements on both sides are inconsistent.
 */
- (void)compareAchievementsWithGameCenter;

/** Handles error from completion handlers.
 */
- (void)handleError:(NSError *)error;

/** This method is called when the local player's authentication is changed.
 */
- (void)localPlayerAuthenticationChanged:(NSNotification *)notification;

/** Popups a UIAlertView which provides the option to open Game Center app.
 */
- (void)popupGCAlert;
@end

//####################################################################################
// GameKitCenter class
//####################################################################################

@implementation GameKitCenter
{
    BOOL shouldManuallyReportFailedAchievements;
    BOOL isReportFailedAchievementsScheduled;
}

//####################################################################################
#pragma mark Public methods
#pragma mark -
//####################################################################################

@synthesize delegate;
@dynamic shouldCommunicateWithGC;

- (BOOL)shouldCommunicateWithGC
{
    return shouldCommunicateWithGC;
}

- (void)setShouldCommunicateWithGC:(BOOL)_shouldCommunicateWithGC
{
    if (!isGCSupported)
    {
        NSLog(@"ERROR: GC is not supported on this iOS version");
        isGCEnabled = NO;
        shouldCommunicateWithGC = NO;
    }
    else
    {
        if (!isGCEnabled)
        {
            shouldCommunicateWithGC = NO;
            
            if (_shouldCommunicateWithGC)
                [self popupGCAlert];
        }
        else if (isGCEnabled && shouldCommunicateWithGC != _shouldCommunicateWithGC)
        {
            shouldCommunicateWithGC = _shouldCommunicateWithGC;
        
            if (shouldCommunicateWithGC)
            {
                NSLog(@"INFO: GC connection is now enabled.");
                [self loadGCAchievements];
            }
            else
                NSLog(@"INFO: GC connection is now disabled. Achievements and scores will not be synced.");
        }
    }
}

- (id)initWithDictionaries:(NSArray *)achievementsInfo
{
	if ((self = [super init]))
	{
        achievementsList = [[NSMutableArray alloc] init];
        achievementsDictionary = [[NSMutableDictionary alloc] init];
        gkAchievementsDictionary = [[NSMutableDictionary alloc] init];
        queuedAchievements = [[NSMutableDictionary alloc] init];
        failedAchievements = [[NSMutableArray alloc] init];
        delegates = [[NSMutableArray alloc] init];
        
        for (NSDictionary *info in achievementsInfo)
        {
            id<GameKitAchievement> achievement = [self achievementWithDictionary:info];
            assert([achievementsDictionary objectForKey:achievement.identifier] == nil);
            [achievementsDictionary setObject:achievement forKey:achievement.identifier];
            [achievementsList addObject:achievement];
        }
        
        if (IsGameCenterAPIAvailable())
        {
            isGCEnabled = YES;
            isGCSupported = YES;
            shouldCommunicateWithGC = YES;
            
            NSString *systemVersion = [[UIDevice currentDevice] systemVersion];
            if ([systemVersion compare:@"4.3" options:NSNumericSearch] == NSOrderedAscending)
            {
                shouldManuallyReportFailedAchievements = YES;
            }
            else
                shouldManuallyReportFailedAchievements = NO;
        }
        else
        {
            isGCEnabled = NO;
            isGCSupported = NO;
            shouldCommunicateWithGC = NO;
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Game Center Disabled" message:@"Game Center is not supported. Upgrade your iOS to 4.1 or newer to enable Game Center." delegate:nil cancelButtonTitle:@"Continue" otherButtonTitles:nil];
            [alert show];
            [alert release];
        }
        
        isSynced = YES;
        hasChangedDevice = NO;
        
        isReportFailedAchievementsScheduled = NO;
	}
	
	return self;
}

- (void)dealloc
{
    [delegates release];
    [failedAchievements release];
    [queuedAchievements release];
    [gkAchievementsDictionary release];
    [achievementsDictionary release];
    [achievementsList release];
    
	[super dealloc];
}

- (id<GameKitAchievement>)achievementWithDictionary:(NSDictionary *)dictionary
{
    return [StandardGameKitAchievement achievementWithDictionary:dictionary];
}

- (void)destroy
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)addDelegate:(id<GameKitCenterDelegate>)delegate
{
    assert(![delegates containsObject:delegate]);
    [delegates addObject:delegate];
}

- (void)removeDelegate:(id<GameKitCenterDelegate>)delegate
{
    assert([delegates containsObject:delegate]);
    [delegates removeObject:delegate];
}

- (void)authenticateLocalPlayer
{
    if (!isGCEnabled) return;
    if (!shouldCommunicateWithGC) return;
    
    localPlayer = [GKLocalPlayer localPlayer];
    [localPlayer authenticateWithCompletionHandler:^(NSError *error)
    {
        if (!localPlayer.isAuthenticated)
        {
            if (error.code != GKErrorAuthenticationInProgress)
            {
                isGCEnabled = NO;
                self.shouldCommunicateWithGC = NO;
                
                NSLog(@"INFO: GC is disabled");
            }
            else if (error.code == GKErrorCancelled)
            {
                [self popupGCAlert];
            }
        }
        else
        {
            if (!isGCEnabled)
            {
                isGCEnabled = YES;
                self.shouldCommunicateWithGC = YES;
            }
            
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(localPlayerAuthenticationChanged:) name:GKPlayerAuthenticationDidChangeNotificationName object:nil];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self invokeDelegatesWithSelector:@selector(localPlayerAuthenticated) andObject:nil];
            });
            
            [self loadGCAchievements];
        }
    }];
}

- (NSDictionary *)save
{
    NSMutableDictionary *temp = [NSMutableDictionary dictionary];
    for (id<GameKitAchievement> achievement in achievementsList)
        [temp setObject:[achievement save] forKey:achievement.identifier];
    
    return [NSDictionary dictionaryWithDictionary:temp];
}

- (void)loadFromDictionary:(NSDictionary *)dictionary
{
    assert(dictionary);
    
    NSLog(@"INFO: Loading saved achievements...");
    
    for (NSString *identifier in [dictionary allKeys])
    {
        NSDictionary *achievementSaveFile = [dictionary objectForKey:identifier];
        
        id<GameKitAchievement> achievement = [achievementsDictionary objectForKey:identifier];
        if (achievement == nil)
        {
            NSLog(@"INFO: Achievement '%@' is not in the save file", identifier);
        }
        else
        {
            NSLog(@"INFO: %@ -> %.2f", identifier, [[achievementSaveFile objectForKey:@"PercentageCompleted"] doubleValue]);
            [achievement loadFromDictionary:achievementSaveFile];
        }
    }
}

- (void)reportQueuedAchievements
{
    if (!isGCEnabled) return;
    if (!shouldCommunicateWithGC) return;
    
    for (id<GameKitAchievement> achievement in [queuedAchievements allValues])
    {
        // Ignore non-GC achievements
        GKAchievement *gkAchievement = [gkAchievementsDictionary objectForKey:achievement.identifier];
        if (gkAchievement == nil)
        {
            NSLog(@"WARNING: Achievement '%@' is missing in GC. Progress will not be reported.", achievement.identifier);
            continue;
        }
        
        gkAchievement.percentComplete = achievement.percentageCompleted;
        
        [gkAchievement reportAchievementWithCompletionHandler:^(NSError *error)
        {
            if (error)
            {
                NSLog(@"ERROR: Achievement report failed (ID: %@, %%completed: %.2f)", gkAchievement.identifier, gkAchievement.percentComplete);
                
                if (shouldManuallyReportFailedAchievements)
                {
                    NSLog(@"INFO: Failed achievement report queued (ID: %@, %%completed: %.2f)", gkAchievement.identifier, gkAchievement.percentComplete);
                    [failedAchievements addObject:achievement];
                    
                    if (!isReportFailedAchievementsScheduled)
                    {
                        [self performSelector:@selector(reportFailedAchievements) withObject:self afterDelay:10.0];
                        isReportFailedAchievementsScheduled = YES;
                    }
                }
            }
            else
                NSLog(@"INFO: Achievement report successful (ID: %@, %%completed: %.2f)", gkAchievement.identifier, gkAchievement.percentComplete);
        }];
    }
    
    [queuedAchievements removeAllObjects];
}

- (void)reportAchievementWithIdentifier:(NSString *)identifier percentageCompleted:(double)percentageCompleted
{
    assert(percentageCompleted > 0.0 && percentageCompleted <= 100.0);
    
    id<GameKitAchievement> achievement = [achievementsDictionary objectForKey:identifier];
    assert(achievement);
    
    if (percentageCompleted > achievement.percentageCompleted)
    {
        achievement.percentageCompleted = percentageCompleted;
        
        id<GameKitAchievement> queuedAchievement = [queuedAchievements objectForKey:identifier];
        if (queuedAchievement)
            NSLog(@"INFO: Overwriting queued achievement report (ID: %@, %%completed: %.2f)", queuedAchievement.identifier, queuedAchievement.percentageCompleted);
            
        [queuedAchievements setObject:achievement forKey:identifier];
        
        if (percentageCompleted == 100.0)
            [self invokeDelegatesWithSelector:@selector(achievementCompleted:) andObject:achievement];
        else
            [self invokeDelegatesWithSelector:@selector(achievementProgressed:) andObject:achievement];
        
        NSLog(@"INFO: Achievement report queued (ID: %@, %%completed: %.2f)", achievement.identifier, achievement.percentageCompleted);
    }
}

- (NSArray *)achievements
{
    return [NSArray arrayWithArray:achievementsList];
}

- (void)resetAchievements
{
    for (id<GameKitAchievement> achievement in achievementsList)
        achievement.percentageCompleted = 0.0;
    
    NSLog(@"INFO: Achievements reset.");
    [self invokeDelegatesWithSelector:@selector(achievementsReset) andObject:nil];
    
    if (!isGCEnabled) return;
    if (!shouldCommunicateWithGC) return;
    
    [GKAchievement resetAchievementsWithCompletionHandler:^(NSError *error)
    {
        if (error)
            [self handleError:error];
        else
        {
            NSLog(@"INFO: GC achievements reset");
        }
    }];
}

- (void)reportScore:(int64_t)score forCategory:(NSString *)category
{
    
}

//####################################################################################
#pragma mark Protocol methods
#pragma mark -
//####################################################################################

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    // Run the Game Center app
    if (buttonIndex == 1)
    {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"gamecenter:"]];
    }
}

//####################################################################################
#pragma mark Private methods
#pragma mark -
//####################################################################################

- (void)invokeDelegatesWithSelector:(SEL)selector andObject:(id<NSObject>)object
{
    for (id<GameKitCenterDelegate> d in delegates)
    {
        [d performSelector:selector withObject:object];
    }
}

- (void)syncAchievementsWithGameCenter
{
    if (!isGCEnabled) return;
    if (!shouldCommunicateWithGC) return;
    
    NSLog(@"INFO: Syncing achievements with GC...");
    
    for (id<GameKitAchievement> achievement in [self achievements])
    {
        GKAchievement *gkAchievement = [gkAchievementsDictionary objectForKey:achievement.identifier];
        gkAchievement.percentComplete = achievement.percentageCompleted;
        
        if (gkAchievement)
        {
            [gkAchievement reportAchievementWithCompletionHandler:^(NSError *error)
            {
                if (error)
                    [self handleError:error];
                else
                {
                    NSLog(@"INFO: Sync achievement succesful (ID: %@, %%completed: %.2f)", gkAchievement.identifier, gkAchievement.percentComplete);
                }
            }];
        }
    }
}

- (void)syncScoresWithGameCenter
{
    if (!isGCEnabled) return;
    if (!shouldCommunicateWithGC) return;
}

- (void)reportFailedAchievements
{
    if (!isGCEnabled) return;
    if (!shouldCommunicateWithGC) return;
    
     NSLog(@"INFO: Reporting achievements which failed to be reported...");
    
    isReportFailedAchievementsScheduled = NO;
    
    for (id<GameKitAchievement> achievement in failedAchievements)
    {
        // Ignore non-GC achievements
        GKAchievement *gkAchievement = [gkAchievementsDictionary objectForKey:achievement.identifier];
        assert(gkAchievement);
        
        gkAchievement.percentComplete = achievement.percentageCompleted;
        
        [gkAchievement reportAchievementWithCompletionHandler:^(NSError *error)
         {
             if (error)
             {
                 NSLog(@"ERROR: Achievement report failed (ID: %@, %%completed: %.2f)", gkAchievement.identifier, gkAchievement.percentComplete);
                 
                 if (shouldManuallyReportFailedAchievements)
                 {
                     NSLog(@"INFO: Failed achievement report queued (ID: %@, %%completed: %.2f)", gkAchievement.identifier, gkAchievement.percentComplete);
                     [failedAchievements addObject:achievement];
                     
                     if (!isReportFailedAchievementsScheduled)
                     {
                         [self performSelector:@selector(reportFailedAchievements) withObject:self afterDelay:10.0];
                         isReportFailedAchievementsScheduled = YES;
                     }
                 }
             }
             else
                 NSLog(@"INFO: Achievement report successful (ID: %@, %%completed: %.2f)", gkAchievement.identifier, gkAchievement.percentComplete);
         }];
    }
    
    [failedAchievements removeAllObjects];
}

- (void)handleError:(NSError *)error
{
    if (error.code == GKErrorNotAuthenticated)
    {
        NSLog(@"ERROR: Player is not authenticated");
    }
    else
        NSLog(@"ERROR: %@", error.description);
}

- (void)loadGCAchievements
{
    if (!isGCEnabled) return;
    if (!shouldCommunicateWithGC) return;
    
    [GKAchievement loadAchievementsWithCompletionHandler:^(NSArray *achievements, NSError *error)
    {
        if (error)
        {
            [self handleError:error];
        }
        else
        {
            hasChangedDevice = NO;
            isSynced = YES;
            
            if (achievements == nil)
            {
                for (id<GameKitAchievement> achievement in achievementsList)
                {
                    if (achievement.percentageCompleted > 0.0)
                    {
                        isSynced = NO;
                        break;
                    }
                }
            }
            else
            {
                for (GKAchievement *gkAchievement in achievements)
                {
                    NSLog(@"INFO: Found achievement progress (ID: %@, %%completed: %.2f)", gkAchievement.identifier, gkAchievement.percentComplete);
                    [gkAchievementsDictionary setObject:gkAchievement forKey:gkAchievement.identifier];
                    
                    id<GameKitAchievement> achievement = [achievementsDictionary objectForKey:gkAchievement.identifier];
                    assert(achievement);
                    if (achievement.percentageCompleted < gkAchievement.percentComplete)
                        hasChangedDevice = YES;
                    else if (achievement.percentageCompleted > gkAchievement.percentComplete)
                        isSynced = NO;
                }
            }
            
            assert(isSynced || !hasChangedDevice);
            
            [self compareAchievementsWithGameCenter];
        }
    }];
}

- (void)compareAchievementsWithGameCenter
{
    if (!isGCEnabled) return;
    if (!shouldCommunicateWithGC) return;
    
    [GKAchievementDescription loadAchievementDescriptionsWithCompletionHandler:^(NSArray *descriptions, NSError *error)
     {
         if (error)
         {
             [self handleError:error];
         }
         else
         {
             assert(descriptions);
             
             if (descriptions.count != achievementsDictionary.count)
                 NSLog(@"WARNING: There are %d local achievements, while GC has %d achievements", achievementsDictionary.count, descriptions.count);
             
             NSMutableSet *missingLocalIdentifiers = [NSMutableSet set];
             
             NSMutableSet *missingGCIdentifiers = [NSMutableSet set];
             [missingGCIdentifiers addObjectsFromArray:[achievementsDictionary allKeys]];
             
             for (GKAchievementDescription *gkDescription in descriptions)
             {
                 id<GameKitAchievement> localAchievement = [achievementsDictionary objectForKey:gkDescription.identifier];
                 if (localAchievement == nil)
                 {
                     [missingLocalIdentifiers addObject:gkDescription.identifier];
                 }
                 else
                 {
                     [missingGCIdentifiers removeObject:gkDescription.identifier];
                     
                     if (localAchievement.points != gkDescription.maximumPoints)
                         NSLog(@"WARNING: Achievement '%@' has inconsistent point", gkDescription.identifier);
                 }
                 
                 GKAchievement *gkAchievement = [gkAchievementsDictionary objectForKey:gkDescription.identifier];
                 if (gkAchievement == nil)
                 {
                     NSLog(@"INFO: Creating new GKAchievement object (ID: %@, %%completed: %.2f)", gkDescription.identifier, 0.0);
                     gkAchievement = [[[GKAchievement alloc] initWithIdentifier:gkDescription.identifier] autorelease];
                     [gkAchievementsDictionary setObject:gkAchievement forKey:gkDescription.identifier];
                 }
             }
             
             if (missingLocalIdentifiers.count > 0)
             {
                 NSLog(@"WARNING: These achievements do no appear locally:");
                 for (NSString *identifier in [missingLocalIdentifiers allObjects])
                     NSLog(@"- %@", identifier);
             }
             
             if (missingGCIdentifiers.count > 0)
             {
                 NSLog(@"WARNING: These achievements do no appear in GC:");
                 for (NSString *identifier in [missingGCIdentifiers allObjects])
                     NSLog(@"- %@", identifier);
             }
             
             [self invokeDelegatesWithSelector:@selector(achievementsLoaded) andObject:nil];
             
             if (!isSynced)
             {
                 NSLog(@"WARNING: Local achievements are not synced with GC");
                 [self syncAchievementsWithGameCenter];
             }
             else if (hasChangedDevice)
             {
                 NSLog(@"WARNING: The local player is using a different device");
             }
         }
     }];
}

- (void)localPlayerAuthenticationChanged:(NSNotification *)notification
{
}

- (void)popupGCAlert
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Game Center Disabled" message:@"Sign in with the Game Center application to enable." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Sign In", nil];
        [alert show];
        [alert release];
        
    });
}

@end
