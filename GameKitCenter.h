//
//  GameKitCenter.h
//  GameKitCenter
//
//  Created by Hasyimi Bahrudin on 8/14/12.
//
//

#import <Foundation/Foundation.h>
#import <GameKit/GameKit.h>

//####################################################################################
// GameKitAchievement protocol
//####################################################################################

@protocol GameKitAchievement<NSObject>

- (id)initWithDictionary:(NSDictionary *)dictionary;

- (NSDictionary *)save;
- (void)loadFromDictionary:(NSDictionary *)dictionary;

@property (readonly, copy, nonatomic) NSString * identifier;
@property (readwrite, nonatomic) double percentageCompleted;
@property (readonly, nonatomic) int points;
@end

//####################################################################################
// Default achievement class
//####################################################################################

@interface StandardGameKitAchievement : NSObject<GameKitAchievement>
{
    NSString *identifier;
    double percentageCompleted;
    int points;
}

+ (id)achievementWithDictionary:(NSDictionary *)dictionary;
@end

//####################################################################################
// GameKitCenterDelegate protocol
//####################################################################################

@protocol GameKitCenterDelegate<NSObject>
- (void)localPlayerAuthenticated;
- (void)achievementProgressed:(id<GameKitAchievement>)achievement;
- (void)achievementsLoaded;
- (void)achievementsReset;
- (void)achievementCompleted:(id<GameKitAchievement>)achievement;
@end

//####################################################################################
// GameKitCenter class
//####################################################################################

@interface GameKitCenter : NSObject<UIAlertViewDelegate>
{
    GKLocalPlayer *localPlayer;
    
    NSMutableArray *achievementsList;
    NSMutableDictionary *achievementsDictionary;
    NSMutableDictionary *gkAchievementsDictionary;
    NSMutableDictionary *queuedAchievements;
    NSMutableArray *failedAchievements;
    
    BOOL isGCEnabled;
    BOOL isGCSupported;
    
    BOOL shouldCommunicateWithGC;
    BOOL isSynced;
    BOOL hasChangedDevice;
    
    NSMutableArray *delegates;
}

/** Initializes GameKitCenter with a dictionary.
 */
- (id)initWithDictionaries:(NSArray *)achievementsInfo;

/** Creates an autoreleased achievement object with a dictionary.
    Override this method to use your own custom achievement class.
 */
- (id<GameKitAchievement>)achievementWithDictionary:(NSDictionary *)dictionary;

/** Unregisters GameKitCenter form NSNotificationCenter.
    @warning You MUST call this before deallocating GameKitCenter, or memory will be leaked.
 */
- (void)destroy;

/** Registers a class as a delegate.
 */
- (void)addDelegate:(id<GameKitCenterDelegate>)delegate;

/** Unregisters a class as a delegate.
 */
- (void)removeDelegate:(id<GameKitCenterDelegate>)delegate;

/** Authenticate the local player.
    This will display the login form if no local player is authenticated.
    @warning Only call this method ONCE, preferrably during initialization.
 */
- (void)authenticateLocalPlayer;

/** Returns the encoded achievements progress.
 */
- (NSDictionary *)save;

/** Loads achievements progress from a dictionary.
 */
- (void)loadFromDictionary:(NSDictionary *)dictionary;

/** Reports an achievement progress.
    If the percentageCompleted is 100.0, the achievementCompleted: delegate method will be called.
    @warning This method DOES NOT report the progress to Game Center nor does it save the progress locally.
    @warning The actual reporting and saving is done when reportQueuedAchievements is called.
 */
- (void)reportAchievementWithIdentifier:(NSString *)identifier percentageCompleted:(double)percentageCompleted;

/** Reports queued achievements.
    This method does the actual reporting to Game Center.
 */
- (void)reportQueuedAchievements;

/** Returns all local achievements.
 */
- (NSArray *)achievements;

/** Resets achievements progress in Game Center and locally.
 */
- (void)resetAchievements;

/** Reports a score.
    @warning This method DOES NOT report the score to Game Center nor does it save the score locally.
    @warning The actual reporting and saving is done when processQueuedScores is called.
 */
- (void)reportScore:(int64_t)score forCategory:(NSString *)category;

//- (NSArray *)scoresWithPlayerIDs:(NSArray *)playerIDs timeScope:(GKLeaderboardTimeScope)timeScope range:(NSRange)range;
//
//- (NSArray *)scoresWithPlayerScope:(GKLeaderboardPlayerScope)playerScope timeScope:(GKLeaderboardTimeScope)timeScope range:(NSRange)range;

@property (readwrite, nonatomic) BOOL shouldCommunicateWithGC;
@property (readwrite, assign, nonatomic) id<GameKitCenterDelegate> delegate;

@end
