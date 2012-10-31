//
//  GameKitCenter.m
//  GameKitCenter
//
//  Created by Hasyimi Bahrudin on 8/14/12.
//
//

#import "GameKitCenter.h"
#import <dispatch/dispatch.h>

/******************************************
 * Helper functions
 ******************************************/

BOOL IsGameCenterAPIAvailable()
{
    // Check for presence of GKLocalPlayer class.
    BOOL isClassAvailable = (NSClassFromString(@"GKLocalPlayer")) != nil;
    
    // The device must be running iOS 4.1 or later.
    NSString *requiredVersion = @"4.1";
    NSString *currentVersion = [[UIDevice currentDevice] systemVersion];
    BOOL isOSVersionSupported = ([currentVersion compare:requiredVersion options:NSNumericSearch] != NSOrderedAscending);
    
    return (isClassAvailable && isOSVersionSupported);
}

BOOL IsGKGameCenterControllerDelegateAvailable()
{
    BOOL isProtocolAvailable = (NSProtocolFromString(@"GKGameCenterControllerDelegate")) != nil;
    
    // The device must be running iOS 6.0 or later.
    NSString *requiredVersion = @"6.0";
    NSString *currentVersion = [[UIDevice currentDevice] systemVersion];
    BOOL isOSVersionSupported = ([currentVersion compare:requiredVersion options:NSNumericSearch] != NSOrderedAscending);
    
    return (isProtocolAvailable && isOSVersionSupported);
}






/******************************************
 * GameKitCenter private methods
 ******************************************/

@interface GameKitCenter ()

- (void)invokeDelegatesWithSelector:(SEL)selector andObject:(id<NSObject>)object;

/** Synchronizes Game Center's achievements with local achievements.
 This ensures that achievements on both side are equal.
 This method is automatically when the local player is authenicated.
 */
- (void)syncAchievementsWithGameCenter;

/** Reports achievements that failed to be submitted to GC.
 This method will be scheduled automatically.
 This method is only used for iOS 4.3 and lower.
 */
- (void)reportFailedAchievements;

/** Synchronizes Game Center's leaderboards with local leaderboards.
 This ensures that leaderboards on both side are equal.
 This method is automatically when the local player is authenicated.
 */
- (void)syncLeaderboardsWithGameCenter;

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

/** Loads leaderboards from GC.
 */
- (void)loadGCLeaderboards;

/** Compares the local leaderboards with the GC achievements.
 Warnings will be issued when leaderboards on both sides are inconsistent.
 */
- (void)compareLeaderboardsWithGameCenter;

@end

/******************************************
 * GameKitCenter
 ******************************************/

@implementation GameKitCenter
{
    BOOL shouldManuallyReportFailedAchievements;
    BOOL isReportFailedAchievementsScheduled;
}

#pragma mark Public methods
#pragma mark -

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

- (id)initWithAchievements:(NSArray *)achievementArray andLeaderboards:(NSArray *)leaderboardArray andViewController:(UIViewController *)aViewController
{
	if ((self = [super init]))
	{
        assert(achievementArray);
        assert(leaderboardArray);
        
        viewController = aViewController;
        
        // Initialize achievements ------------
        
        achievementsList = [[NSMutableArray alloc] init];
        achievementsDictionary = [[NSMutableDictionary alloc] init];
        gkAchievementsDictionary = [[NSMutableDictionary alloc] init];
        queuedAchievements = [[NSMutableDictionary alloc] init];
        failedAchievements = [[NSMutableArray alloc] init];
        delegates = [[NSMutableArray alloc] init];
        
        for (NSDictionary *info in achievementArray)
        {
            id<GameKitAchievement> achievement = [self achievementWithDictionary:info];
            assert([achievementsDictionary objectForKey:achievement.identifier] == nil);
            [achievementsDictionary setObject:achievement forKey:achievement.identifier];
            [achievementsList addObject:achievement];
        }
        
        // Initialize leaderboards -----------------------
        
        leaderboardDictionary = [[NSMutableDictionary alloc] init];
        gkScores = [[NSMutableArray alloc] init];
        
        for (NSDictionary *info in leaderboardArray)
        {
            id<GameKitLeaderboard> leaderboard = [self leaderboardWithDictionary:info];
            assert(leaderboardDictionary[leaderboard.identifier] == nil);
            [leaderboardDictionary setObject:leaderboard forKey:leaderboard.identifier];
        }
        
        // -----------------------------------------------
        
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
    [gkScores release];
    [leaderboardDictionary release];
    
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

- (id<GameKitLeaderboard>)leaderboardWithDictionary:(NSDictionary *)dictionary
{
    return [StandardGameKitLeaderboard leaderboardWithDictionary:dictionary];
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
         INVOKE_ON_MAIN_THREAD_BEGIN();
         
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
             [self loadGCLeaderboards];
         }
         
         INVOKE_ON_MAIN_THREAD_END();
     }];
}

- (NSDictionary *)save
{
    NSMutableDictionary *_achievements = [NSMutableDictionary dictionary];
    for (id<GameKitAchievement> achievement in achievementsList)
        [_achievements setObject:[achievement save] forKey:achievement.identifier];
    
    NSMutableDictionary *_leaderboards = [NSMutableDictionary dictionary];
    for (NSString *key in [leaderboardDictionary allKeys])
    {
        id<GameKitLeaderboard> leaderboard = leaderboardDictionary[key];
        [_leaderboards setObject:[leaderboard save] forKey:leaderboard.identifier];
    }
    
    return @{ @"Achievements" : _achievements, @"Leaderboards" : _leaderboards };
}

- (void)loadFromDictionary:(NSDictionary *)dictionary
{
    assert(dictionary);
    
    NSLog(@"INFO: Loading saved achievements...");
    NSDictionary *_achievements = dictionary[@"Achievements"];
    assert(_achievements);
    
    for (NSString *identifier in [_achievements allKeys])
    {
        NSDictionary *achievementSaveFile = [_achievements objectForKey:identifier];
        
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
    
    NSLog(@"INFO: Loading saved leaderboards...");
    NSDictionary *_leaderboards = dictionary[@"Leaderboards"];
    assert(_leaderboards);
    
    for (NSString *identifier in [_leaderboards allKeys])
    {
        NSDictionary *leaderboardsSaveFile = _leaderboards[identifier];
        
        id<GameKitLeaderboard> leaderboard = leaderboardDictionary[identifier];
        if (leaderboard == nil)
        {
            NSLog(@"INFO: Leaderboard '%@' is not in the save file", identifier);
        }
        else
        {
            [leaderboard loadFromDictionary:leaderboardsSaveFile];
        }
    }
}

- (void)reportQueuedAchievements
{
    for (NSString *identifier in [queuedAchievements allKeys])
    {
        id<GameKitAchievement> achievement = [achievementsDictionary objectForKey:identifier];
        double percentageCompleted = [[queuedAchievements objectForKey:identifier] doubleValue];
        achievement.percentageCompleted = percentageCompleted;
        
        [achievement progressReported];
        
        
        // Ignore non-GC achievements
        GKAchievement *gkAchievement = [gkAchievementsDictionary objectForKey:achievement.identifier];
        if (gkAchievement == nil)
        {
            NSLog(@"WARNING: Achievement '%@' is missing in GC. Progress will not be reported.", achievement.identifier);
            continue;
        }
        
        if (isGCEnabled && shouldCommunicateWithGC)
        {
            gkAchievement.percentComplete = achievement.percentageCompleted;
            
            [gkAchievement reportAchievementWithCompletionHandler:^(NSError *error)
             {
                 if (error)
                 {
                     NSLog(@"ERROR: Achievement report failed (ID: %@, %%completed: %.2f)", gkAchievement.identifier, gkAchievement.percentComplete);
                     
                     if (shouldManuallyReportFailedAchievements)
                     {
                         INVOKE_ON_MAIN_THREAD_BEGIN();
                         
                         NSLog(@"INFO: Failed achievement report queued (ID: %@, %%completed: %.2f)", gkAchievement.identifier, gkAchievement.percentComplete);
                         [failedAchievements addObject:achievement];
                         
                         if (!isReportFailedAchievementsScheduled)
                         {
                             [self performSelector:@selector(reportFailedAchievements) withObject:self afterDelay:10.0];
                             isReportFailedAchievementsScheduled = YES;
                         }
                         
                         INVOKE_ON_MAIN_THREAD_END();
                     }
                 }
                 else
                     NSLog(@"INFO: Achievement report successful (ID: %@, %%completed: %.2f)", gkAchievement.identifier, gkAchievement.percentComplete);
             }];
        }
    }
    
    [queuedAchievements removeAllObjects];
}

- (void)reportAchievementWithIdentifier:(NSString *)identifier percentageCompleted:(double)percentageCompleted
{
    assert(percentageCompleted > 0.0 && percentageCompleted <= 100.0);
    
    id<GameKitAchievement> achievement = [achievementsDictionary objectForKey:identifier];
    assert(achievement);
    
    double currentPercentageCompleted = achievement.percentageCompleted;
    
    NSNumber *queuedProgress = [queuedAchievements objectForKey:identifier];
    if (queuedProgress)
    {
        currentPercentageCompleted = [queuedProgress doubleValue];
        NSLog(@"INFO: Overwriting queued achievement report (ID: %@, %%completed: %.2f)", identifier, currentPercentageCompleted);
    }
    
    if (percentageCompleted > currentPercentageCompleted)
    {
        [queuedAchievements setObject:[NSNumber numberWithDouble:percentageCompleted] forKey:identifier];
        
        if (percentageCompleted == 100.0)
            [self invokeDelegatesWithSelector:@selector(achievementCompleted:) andObject:achievement];
        else
            [self invokeDelegatesWithSelector:@selector(achievementProgressed:) andObject:achievement];
        
        NSLog(@"INFO: Achievement report queued (ID: %@, %%completed: %.2f)", identifier, percentageCompleted);
    }
}

- (void)flushQueuedAchievements
{
    for (NSString *identifier in [queuedAchievements allKeys])
    {
        id<GameKitAchievement> achievement = [achievementsDictionary objectForKey:identifier];
        [achievement progressFlushed];
    }
    
    [queuedAchievements removeAllObjects];
}

- (NSArray *)achievements
{
    return [NSArray arrayWithArray:achievementsList];
}

- (void)resetAchievements
{
    for (id<GameKitAchievement> achievement in achievementsList)
        achievement.percentageCompleted = 0.0;
    
    NSArray *oldAchievements = [gkAchievementsDictionary allValues];
    for (GKAchievement *achievement in oldAchievements)
    {
        NSString *identifier = [[achievement.identifier copy] autorelease];
        GKAchievement *newAchievement = [[[GKAchievement alloc] initWithIdentifier:identifier] autorelease];
        [gkAchievementsDictionary setObject:newAchievement forKey:identifier];
    }
    
    NSLog(@"INFO: Achievements reset.");
    [self invokeDelegatesWithSelector:@selector(achievementsReset) andObject:nil];
    
    if (!isGCEnabled) return;
    if (!shouldCommunicateWithGC) return;
    
    [GKAchievement resetAchievementsWithCompletionHandler:^(NSError *error)
     {
         INVOKE_ON_MAIN_THREAD_BEGIN();
         
         if (error)
             [self handleError:error];
         else
         {
             NSLog(@"INFO: GC achievements reset");
         }
         
         INVOKE_ON_MAIN_THREAD_END();
     }];
}

- (void)reportScore:(double)aScore leaderboardID:(NSString *)aLeaderboardID
{
    id<GameKitLeaderboard> leaderboard = leaderboardDictionary[aLeaderboardID];
    assert(leaderboard);
    id<GameKitScore> score = [leaderboard addScoreWithPlayerID:[[GKLocalPlayer localPlayer] playerID] andValue:aScore andDate:[NSDate date]];
    
    if (score)
    {
        [self invokeDelegatesWithSelector:@selector(scoreReported:) andObject:score];
    }
    
    if (!isGCEnabled) return;
    if (!shouldCommunicateWithGC) return;
    
    GKScore *scoreReporter = [[GKScore alloc] initWithCategory:aLeaderboardID];
    
    scoreReporter.value = aScore;
    scoreReporter.context = 0;
    
    [scoreReporter reportScoreWithCompletionHandler:^(NSError *error)
     {
         INVOKE_ON_MAIN_THREAD_BEGIN();
         
         if (error != nil)
         {
             [self handleError:error];
         }
         else
         {
             NSLog(@"INFO: Leaderboard report successful (ID: %@, playerID: %@, value: %.2f)", leaderboard.identifier, [[GKLocalPlayer localPlayer] playerID], aScore);
         }
         
         INVOKE_ON_MAIN_THREAD_END();
     }];
}

- (NSArray *)scoresWithLeaderboardID:(NSString *)aLeaderboardID playerIDs:(NSArray *)playerIDs timeScope:(GKLeaderboardTimeScope)timeScope range:(NSRange)range
{
    id<GameKitLeaderboard> leaderboard = leaderboardDictionary[aLeaderboardID];
    assert(leaderboard);
    
    return [leaderboard scoresWithPlayerIDs:playerIDs timeScope:timeScope range:range];
}

- (NSArray *)scoresWithLeaderboardID:(NSString *)aLeaderboardID playerScope:(GKLeaderboardPlayerScope)playerScope timeScope:(GKLeaderboardTimeScope)timeScope range:(NSRange)range
{
    id<GameKitLeaderboard> leaderboard = leaderboardDictionary[aLeaderboardID];
    assert(leaderboard);
    
    return [leaderboard scoresWithPlayerScope:playerScope timeScope:timeScope range:range];
}

- (void)showAchievements
{
    if (viewController)
    {
        if (IsGKGameCenterControllerDelegateAvailable())
        {
            GKGameCenterViewController *gameCenterController = [[GKGameCenterViewController alloc] init];
            if (gameCenterController != nil)
            {
                gameCenterController.gameCenterDelegate = self;
                gameCenterController.viewState = GKGameCenterViewControllerStateAchievements;
                [viewController presentViewController:gameCenterController animated:YES completion:nil];
            }
        }
        else
        {
            GKAchievementViewController *achievementsViewController = [[GKAchievementViewController alloc] init];
            if (achievementsViewController != nil)
            {
                achievementsViewController.achievementDelegate = self;
                [viewController presentViewController: achievementsViewController animated: YES completion:nil];
            }
            [achievementsViewController release];
        }
    }
}

- (void)showLeaderboard:(NSString *)aLeaderboardID
{
    if (viewController)
    {
        assert(aLeaderboardID);
        
        if (IsGKGameCenterControllerDelegateAvailable())
        {
            GKGameCenterViewController *gameCenterController = [[GKGameCenterViewController alloc] init];
            if (gameCenterController != nil)
            {
                gameCenterController.gameCenterDelegate = self;
                gameCenterController.viewState = GKGameCenterViewControllerStateLeaderboards;
                gameCenterController.leaderboardTimeScope = GKLeaderboardTimeScopeToday;
                gameCenterController.leaderboardCategory = aLeaderboardID;
                [viewController presentViewController:gameCenterController animated:YES completion:nil];
            }
        }
        else
        {
            GKLeaderboardViewController *leaderboardViewController = [[GKLeaderboardViewController alloc] init];
            if (leaderboardViewController != nil)
            {
                leaderboardViewController.leaderboardDelegate = self;
                leaderboardViewController.timeScope = GKLeaderboardTimeScopeToday;
                leaderboardViewController.category = aLeaderboardID;
                [viewController presentViewController: leaderboardViewController animated: YES completion:nil];
            }
            [leaderboardViewController release];
        }
    }
}







#pragma mark Protocol methods
#pragma mark -

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    // Run the Game Center app
    if (buttonIndex == 1)
    {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"gamecenter:"]];
    }
}

- (void)achievementViewControllerDidFinish:(GKAchievementViewController *)achievementsViewController
{
    [viewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)leaderboardViewControllerDidFinish:(GKLeaderboardViewController *)leaderboardViewController
{
    [viewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)gameCenterViewControllerDidFinish:(GKGameCenterViewController *)gameCenterViewController
{
    [viewController dismissViewControllerAnimated:YES completion:nil];
}







#pragma mark Private methods
#pragma mark -

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
        
        if (gkAchievement && achievement.percentageCompleted > gkAchievement.percentComplete)
        {
            gkAchievement.percentComplete = achievement.percentageCompleted;
            
            [gkAchievement reportAchievementWithCompletionHandler:^(NSError *error)
             {
                 INVOKE_ON_MAIN_THREAD_BEGIN();
                 
                 if (error)
                     [self handleError:error];
                 else
                 {
                     NSLog(@"INFO: Sync achievement succesful (ID: %@, %%completed: %.2f)", gkAchievement.identifier, gkAchievement.percentComplete);
                 }
                 
                 INVOKE_ON_MAIN_THREAD_END();
             }];
        }
    }
}

- (void)syncLeaderboardsWithGameCenter
{
    if (!isGCEnabled) return;
    if (!shouldCommunicateWithGC) return;
    
    NSLog(@"INFO: Syncing leaderboards with GC...");
    
    for (GKScore *aScore in gkScores)
    {
        id<GameKitLeaderboard> leaderboard = leaderboardDictionary[aScore.category];
        
        if (leaderboard)
        {
            NSArray *scores = [leaderboard scoresWithPlayerIDs:@[aScore.playerID] timeScope:GKLeaderboardTimeScopeAllTime range:NSMakeRange(1, 1)];
            if (scores.count > 0)
            {
                id<GameKitScore> _score = (id<GameKitScore>)scores[0];
                if (_score.value > (double)aScore.value)
                {
                    GKScore *scoreReporter = [[GKScore alloc] initWithCategory:aScore.category];
                    scoreReporter.value = (int64_t)_score.value;
                    scoreReporter.context = 0;
                    
                    [scoreReporter reportScoreWithCompletionHandler:^(NSError *error)
                     {
                         INVOKE_ON_MAIN_THREAD_BEGIN();
                         
                         if (error)
                         {
                             [self handleError:error];
                         }
                         else
                         {
                             NSLog(@"INFO: Sync leaderboard succesful (ID: %@, playerID: %@, value: %.2f)", _score.leaderboardID, _score.playerID, _score.value);
                         }
                         
                         INVOKE_ON_MAIN_THREAD_END();
                     }];
                    
                    [scoreReporter release];
                }
            }
        }
    }
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
             INVOKE_ON_MAIN_THREAD_BEGIN();
             
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
             
             INVOKE_ON_MAIN_THREAD_END();
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
    {
        NSLog(@"ERROR: %@", error.description);
    }
}

- (void)loadGCAchievements
{
    if (!isGCEnabled) return;
    if (!shouldCommunicateWithGC) return;
    
    [GKAchievement loadAchievementsWithCompletionHandler:^(NSArray *achievements, NSError *error)
     {
         INVOKE_ON_MAIN_THREAD_BEGIN();
         
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
         
         INVOKE_ON_MAIN_THREAD_END();
     }];
}

- (void)loadGCLeaderboards
{
    if (!isGCEnabled) return;
    if (!shouldCommunicateWithGC) return;
    
    GKLeaderboard *leaderboardRequest = [[GKLeaderboard alloc] init];
    assert(leaderboardRequest);
    
    leaderboardRequest.playerScope = GKLeaderboardPlayerScopeGlobal;
    leaderboardRequest.timeScope = GKLeaderboardTimeScopeAllTime;
    leaderboardRequest.category = nil;
    leaderboardRequest.range = NSMakeRange(1, 100);
    [leaderboardRequest loadScoresWithCompletionHandler: ^(NSArray *scores, NSError *error)
     {
         INVOKE_ON_MAIN_THREAD_BEGIN();
         
         if (error != nil)
         {
             [self handleError:error];
         }
         
         if (scores != nil)
         {
             [gkScores removeAllObjects];
             
             for (GKScore *aScore in scores)
             {
                 id<GameKitLeaderboard> leaderboard = leaderboardDictionary[aScore.category];
                 assert(leaderboard);
                 
                 [gkScores addObject:aScore];
                 
                 NSLog(@"INFO: Found score (ID: %@, player: %@, value: %.2f)", aScore.category, aScore.playerID, (double)aScore.value);
                 
                 [leaderboard addScoreWithPlayerID:aScore.playerID andValue:aScore.value andDate:aScore.date];
             }
             
             [self compareLeaderboardsWithGameCenter];
         }
         
         INVOKE_ON_MAIN_THREAD_END();
     }];
    
    [leaderboardRequest release];
    
    [self performSelector:@selector(loadGCLeaderboards) withObject:nil afterDelay:5.0f];
}

- (void)compareAchievementsWithGameCenter
{
    if (!isGCEnabled) return;
    if (!shouldCommunicateWithGC) return;
    
    [GKAchievementDescription loadAchievementDescriptionsWithCompletionHandler:^(NSArray *descriptions, NSError *error)
     {
         INVOKE_ON_MAIN_THREAD_BEGIN();
         
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
         
         INVOKE_ON_MAIN_THREAD_END();
     }];
}

- (void)compareLeaderboardsWithGameCenter
{
    if (!isGCEnabled) return;
    if (!shouldCommunicateWithGC) return;
    
    [self invokeDelegatesWithSelector:@selector(scoresLoaded) andObject:nil];
    [self syncLeaderboardsWithGameCenter];
}

- (void)localPlayerAuthenticationChanged:(NSNotification *)notification
{
}

- (void)popupGCAlert
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Game Center Disabled" message:@"Sign in with the Game Center application to enable." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Sign In", nil];
    [alert show];
    [alert release];
}

@end





/******************************************
 * StandardGameKitAchievement
 ******************************************/

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

- (void)progressReported
{
    
}

- (void)progressFlushed
{
    
}

@end





/******************************************
 * StandardGameKitLeaderboard
 ******************************************/

@implementation StandardGameKitLeaderboard

+ (id)leaderboardWithDictionary:(NSDictionary *)aDictionary
{
    return [[[self alloc] initWithDictionary:aDictionary] autorelease];
}

@synthesize name, scoreFormatSuffixSingular, scoreFormatSuffixPlural, identifier, scoreRange;

- (id)initWithDictionary:(NSDictionary *)aDictionary
{
	if ((self = [super init]))
	{
        assert(aDictionary[@"Identifier"]);
        identifier = [aDictionary[@"Identifier"] copy];
        
        assert(aDictionary[@"Name"]);
        name = [aDictionary[@"Name"] copy];
        
        assert(aDictionary[@"ScoreFormatSuffixSingular"]);
        scoreFormatSuffixSingular = [aDictionary[@"ScoreFormatSuffixSingular"] copy];
        
        assert(aDictionary[@"ScoreFormatSuffixPlural"]);
        scoreFormatSuffixPlural = [aDictionary[@"ScoreFormatSuffixPlural"] copy];
        
        assert(aDictionary[@"ScoreRange"]);
        scoreRange = NSRangeFromString(aDictionary[@"ScoreRange"]);
        
        scores = [[NSMutableArray alloc] init];
	}
	
	return self;
}

- (void)dealloc
{
    [scores release];
    [scoreFormatSuffixPlural release];
    [scoreFormatSuffixSingular release];
    [name release];
    [identifier release];
	[super dealloc];
}

- (id<GameKitScore>)addScoreWithPlayerID:(NSString *)aPlayerID andValue:(double)aValue andDate:(NSDate *)aDate
{
    if (!NSLocationInRange((NSUInteger)aValue, scoreRange))
    {
        return nil;
    }
    
    for (StandardGameKitScore *aScore in scores)
    {
        // If the playerID and time stamp are the same, then this
        // score has already been added, so ignore it!
        if ([aScore.playerID isEqualToString:aPlayerID] && [aScore.date isEqualToDate:aDate])
        {
            return nil;
        }
    }

    StandardGameKitScore *score = [[[StandardGameKitScore alloc] initWithPlayerID:aPlayerID leaderboardID:identifier date:aDate value:aValue formattedValue:@"" rank:0] autorelease];

    [scores addObject:score];
    return score;
}

- (void)removeAllScores
{
    [scores removeAllObjects];
}

- (NSArray *)scoresWithPlayerIDs:(NSArray *)playerIDs timeScope:(GKLeaderboardTimeScope)timeScope range:(NSRange)range
{
    NSMutableArray *filteredScores = [NSMutableArray array];
    
    for (StandardGameKitScore *aScore in scores)
    {
        // 1. check player scope
        if (![playerIDs containsObject:aScore.playerID]) continue;
        
        // 2. check time scope
        if (timeScope != GKLeaderboardTimeScopeAllTime)
        {
            NSDate *currentDate = [NSDate date];
            NSDate *date = aScore.date;
            
            if (timeScope == GKLeaderboardTimeScopeToday && ![date isEqualToDate:currentDate])
                continue;
            else if (timeScope == GKLeaderboardTimeScopeWeek && [date timeIntervalSinceNow] > 60 * 24 * 7)
                continue;
        }
        
        [filteredScores addObject:aScore];
    }
    
    if (filteredScores.count > 0)
    {
        [filteredScores sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
           
            StandardGameKitScore *score1 = (StandardGameKitScore *)obj1;
            StandardGameKitScore *score2 = (StandardGameKitScore *)obj2;
            if (score1.value < score2.value)
                return NSOrderedDescending;
            if (score1.value > score2.value)
                return NSOrderedAscending;
            return NSOrderedSame;
            
        }];
        
        NSMutableDictionary *uniqueScores = [NSMutableDictionary dictionary];
        for (id<GameKitScore> aScore in filteredScores)
        {
            if (uniqueScores[aScore.playerID] == nil)
                uniqueScores[aScore.playerID] = aScore;
        }
        
        [filteredScores removeAllObjects];
        [filteredScores addObjectsFromArray:[uniqueScores allValues]];
        
        [filteredScores sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            
            StandardGameKitScore *score1 = (StandardGameKitScore *)obj1;
            StandardGameKitScore *score2 = (StandardGameKitScore *)obj2;
            if (score1.value < score2.value)
                return NSOrderedDescending;
            if (score1.value > score2.value)
                return NSOrderedAscending;
            return NSOrderedSame;
            
        }];
        
        //If out of range, remove the rest
        while (!NSLocationInRange(filteredScores.count, range))
            [filteredScores removeLastObject];
    }
    
    return [NSArray arrayWithArray:filteredScores];
}

- (NSArray *)scoresWithPlayerScope:(GKLeaderboardPlayerScope)playerScope timeScope:(GKLeaderboardTimeScope)timeScope range:(NSRange)range
{
    NSMutableArray *filteredScores = [NSMutableArray array];
    NSArray *friends = [[GKLocalPlayer localPlayer] friends];
    
    for (StandardGameKitScore *aScore in scores)
    {
        // 1. check player scope
        BOOL isFriend = [aScore.playerID isEqualToString:[[GKLocalPlayer localPlayer] playerID]];
        
        if (playerScope == GKLeaderboardPlayerScopeFriendsOnly)
        {
            for (NSString *aFriendID in friends)
            {
                if ([aScore.playerID isEqualToString:aFriendID])
                {
                    isFriend = YES;
                    break;
                }
            }
        }
        
        if (playerScope == GKLeaderboardPlayerScopeFriendsOnly && !isFriend) continue;
        
        // 2. check time scope
        if (timeScope != GKLeaderboardTimeScopeAllTime)
        {
            NSDate *date = aScore.date;
            
            if (timeScope == GKLeaderboardTimeScopeToday && [date timeIntervalSinceNow] > 60 * 24)
                continue;
            else if (timeScope == GKLeaderboardTimeScopeWeek && [date timeIntervalSinceNow] > 60 * 24 * 7)
                continue;
        }
        
        [filteredScores addObject:aScore];
    }
    
    if (filteredScores.count > 0)
    {
        [filteredScores sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            
            StandardGameKitScore *score1 = (StandardGameKitScore *)obj1;
            StandardGameKitScore *score2 = (StandardGameKitScore *)obj2;
            if (score1.value < score2.value)
                return NSOrderedDescending;
            if (score1.value > score2.value)
                return NSOrderedAscending;
            return NSOrderedSame;
            
        }];
        
        NSMutableDictionary *uniqueScores = [NSMutableDictionary dictionary];
        for (id<GameKitScore> aScore in filteredScores)
        {
            if (uniqueScores[aScore.playerID] == nil)
                uniqueScores[aScore.playerID] = aScore;
        }

        [filteredScores removeAllObjects];
        [filteredScores addObjectsFromArray:[uniqueScores allValues]];

        [filteredScores sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {

            StandardGameKitScore *score1 = (StandardGameKitScore *)obj1;
            StandardGameKitScore *score2 = (StandardGameKitScore *)obj2;
            if (score1.value < score2.value)
                return NSOrderedDescending;
            if (score1.value > score2.value)
                return NSOrderedAscending;
            return NSOrderedSame;
            
        }];
        
        //If out of range, remove the rest
        while (!NSLocationInRange(filteredScores.count, range))
            [filteredScores removeLastObject];
    }
    
    return [NSArray arrayWithArray:filteredScores];
}

- (NSDictionary *)save
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    dictionary[@"Identifier"] = identifier;
    dictionary[@"Name"] = name;
    dictionary[@"ScoreFormatSuffixSingular"] = scoreFormatSuffixSingular;
    dictionary[@"ScoreFormatSuffixPlural"] = scoreFormatSuffixPlural;
    dictionary[@"ScoreRange"] = NSStringFromRange(scoreRange);
    dictionary[@"Scores"] = scores;
    return dictionary;
}

- (void)loadFromDictionary:(NSDictionary *)aDictionary
{
//    [identifier release];
//    identifier = [aDictionary[@"Identifier"] copy];
//    
//    [name release];
//    name = [aDictionary[@"Name"] copy];
//    
//    [scoreFormatSuffixSingular release];
//    scoreFormatSuffixSingular = [aDictionary[@"ScoreFormatSuffixSingular"] copy];
//    
//    [scoreFormatSuffixPlural release];
//    scoreFormatSuffixPlural = [aDictionary[@"ScoreFormatSuffixPlural"] copy];
//    
//    scoreRange = NSRangeFromString(aDictionary[@"ScoreRange"]);
    
    [scores release];
    scores = [aDictionary[@"Scores"] retain];
}

@end





/******************************************
 * StandardGameKitScore
 ******************************************/

@implementation StandardGameKitScore

@synthesize playerID, leaderboardID, date, value, formattedValue, rank;

- (id)initWithPlayerID:(NSString *)aPlayerID leaderboardID:(NSString *)aLeaderboardID date:(NSDate *)aDate value:(double)aValue formattedValue:(NSString *)aFormattedValue rank:(int)aRank
{
    if ((self = [super init]))
	{
        assert(aPlayerID);
        playerID = [aPlayerID copy];
        
        assert(aLeaderboardID);
        leaderboardID = [aLeaderboardID copy];
        
        assert(aDate);
        date = [aDate copy];
        
        assert(aValue > 0);
        value = aValue;
        
        assert(aFormattedValue);
        formattedValue = [aFormattedValue copy];
        
        assert(rank >= 0);
        rank = aRank;
	}
	
	return self;
}

- (id)initWithCoder:(NSCoder*)aDecoder
{
    if ((self = [super init]))
    {
        playerID = [[aDecoder decodeObjectForKey:@"PlayerID"] retain];
        assert(playerID);
        
        leaderboardID = [[aDecoder decodeObjectForKey:@"LeaderboardID"] retain];
        assert(leaderboardID);
        
        date = [[aDecoder decodeObjectForKey:@"Date"] retain];
        assert(date);
        
        value = [aDecoder decodeDoubleForKey:@"Value"];
        assert(value > 0);
        
        formattedValue = [[aDecoder decodeObjectForKey:@"FormattedValue"] retain];
        assert(formattedValue);
        
        rank = [aDecoder decodeIntForKey:@"Rank"];
        assert(rank >= 0);
    }
    
    return self;
}

- (void)dealloc
{
    [formattedValue release];
    [date release];
    [leaderboardID release];
    [playerID release];
    [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:playerID forKey:@"PlayerID"];
    [aCoder encodeObject:leaderboardID forKey:@"LeaderboardID"];
    [aCoder encodeObject:date forKey:@"Date"];
    [aCoder encodeDouble:value forKey:@"Value"];
    [aCoder encodeObject:formattedValue forKey:@"FormattedValue"];
    [aCoder encodeInt:rank forKey:@"Rank"];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@, %@ -> %.2f", leaderboardID, playerID, value];
}

@end
