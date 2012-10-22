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

- (void)progressReported;
- (void)progressFlushed;

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

@protocol GameKitLeaderboard <NSObject>

- (id)initWithDictionary:(NSDictionary *)aDictionary;

- (BOOL)addScoreWithPlayerID:(NSString *)aPlayerID andValue:(double)aValue;
- (void)removeAllScores;

- (NSArray *)scoresWithPlayerIDs:(NSArray *)playerIDs timeScope:(GKLeaderboardTimeScope)timeScope range:(NSRange)range;
- (NSArray *)scoresWithPlayerScope:(GKLeaderboardPlayerScope)playerScope timeScope:(GKLeaderboardTimeScope)timeScope range:(NSRange)range;

- (NSDictionary *)save;
- (void)loadFromDictionary:(NSDictionary *)dictionary;

@property (readonly, copy, nonatomic) NSString * name;
@property (readonly, copy, nonatomic) NSString * scoreFormatSuffixSingular;
@property (readonly, copy, nonatomic) NSString * scoreFormatSuffixPlural;
@property (readonly, copy, nonatomic) NSString * identifier;
@property (readonly, nonatomic) NSRange scoreRange;

@end

@interface StandardGameKitLeaderboard : NSObject<GameKitLeaderboard>
{
    NSString *identifier;
    NSString *name;
    NSString *scoreFormatSuffixSingular;
    NSString *scoreFormatSuffixPlural;
    NSRange scoreRange;
    
    NSMutableArray *scores;
}

+ (id)leaderboardWithDictionary:(NSDictionary *)aDictionary;

@end

@protocol GameKitScore <NSObject, NSCoding>

- (id)initWithPlayerID:(NSString *)aPlayerID leaderboardID:(NSString *)aLeaderboardID date:(NSDate *)aDate value:(double)aValue formattedValue:(NSString *)aFormattedValue rank:(int)aRank;

@property (readonly, copy, nonatomic) NSString * playerID;
@property (readonly, copy, nonatomic) NSString * leaderboardID;
@property (readonly, copy, nonatomic) NSDate * date;
@property (readonly, nonatomic) double value;
@property (readonly, copy, nonatomic) NSString * formattedValue;
@property (readonly, nonatomic) int rank;

@end

@interface StandardGameKitScore : NSObject<GameKitScore>
{
    NSString *playerID;
    NSString *leaderboardID;
    NSDate *date;
    double value;
    NSString *formattedValue;
    int rank;
}

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
    
    NSMutableDictionary *leaderboardDictionary;
    NSMutableArray *gkScores;
    
    BOOL isGCEnabled;
    BOOL isGCSupported;
    
    BOOL shouldCommunicateWithGC;
    BOOL isSynced;
    BOOL hasChangedDevice;
    
    NSMutableArray *delegates;
}

/** Initializes GameKitCenter with a dictionary.
 */
- (id)initWithDictionary:(NSDictionary *)aDictionary;

/** Creates an autoreleased achievement object with a dictionary.
    Override this method to use your own custom achievement class.
 */
- (id<GameKitAchievement>)achievementWithDictionary:(NSDictionary *)dictionary;

/** Creates an autoreleased leaderboard object with a dictionary.
 Override this method to use your own custom leaderboard class.
 */
- (id<GameKitLeaderboard>)leaderboardWithDictionary:(NSDictionary *)dictionary;

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

- (void)flushQueuedAchievements;

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
- (void)reportScore:(double)aScore leaderboardID:(NSString *)aLeaderboardID;

//- (NSArray *)scoresWithPlayerIDs:(NSArray *)playerIDs timeScope:(GKLeaderboardTimeScope)timeScope range:(NSRange)range;
//
//- (NSArray *)scoresWithPlayerScope:(GKLeaderboardPlayerScope)playerScope timeScope:(GKLeaderboardTimeScope)timeScope range:(NSRange)range;

@property (readwrite, nonatomic) BOOL shouldCommunicateWithGC;

@end
