//
//  TestScene.m
//  GameKitCenterTest
//
//  Created by Hasyimi Bahrudin on 10/23/12.
//
//

#import "TestScene.h"
#import "AppDelegate.h"

#import "CCGameKitCenterNotification.h"

@interface TestScene ()
- (void)saveToFile;
- (void)loadFromFile;

- (void)changeTimeScope;
- (void)changePlayerScope;
- (void)updateLeaderboard;

- (void)updateScoreToReport;
- (void)reportScore;
@end

@implementation TestScene

- (id)init
{
	if ((self = [super init]))
	{
        NSDictionary *gameKitCenterDictionary = [NSDictionary dictionaryWithContentsOfFile:[[CCFileUtils sharedFileUtils] fullPathFromRelativePath:@"GameKitCenter.plist"]];
        
        AppController *appDelegate = (AppController *)[[UIApplication sharedApplication] delegate];
        UIViewController *viewController = appDelegate.navController;
        
        gkCenter = [[GameKitCenter alloc] initWithAchievements:gameKitCenterDictionary[@"Achievements"] andLeaderboards:gameKitCenterDictionary[@"Leaderboards"] andViewController:viewController];
        [gkCenter addDelegate:self];
        [self loadFromFile];
        [gkCenter authenticateLocalPlayer];
        
        CCGKCNotification *notification = [CCGKCNotification node];
        notification.panelClass = CCGKCNotificationPanel.class;
        [gkCenter addDelegate:notification];
        [[CCDirector sharedDirector] setNotificationNode:notification];
        
        menu = [CCMenu menuWithItems:nil];
        menu.position = CGPointZero;
        menu.anchorPoint = CGPointZero;
        [self addChild:menu z:100];
        
        CCLayerColor *bg = [CCLayerColor layerWithColor:ccc4(255, 255, 255, 255)];
        [self addChild:bg z:0];
        
        CGSize winSize = [[CCDirector sharedDirector] winSize];
        
        CCLabelTTF *title = [CCLabelTTF labelWithString:@"GameKitCenter Test" fontName:@"Marker Felt" fontSize:36];
        title.color = ccBLACK;
        title.position = ccp(winSize.width / 2, winSize.height - 50);
        [self addChild:title];
        
        
        
        
        CCMenuItemLabel *completeAchievement1Label = [CCMenuItemLabel itemWithLabel:[CCLabelTTF labelWithString:@"Complete Achievement One" fontName:@"Marker Felt" fontSize:28] block:^(id sender)
        {
            [gkCenter reportAchievementWithIdentifier:@"Achievement_One" percentageCompleted:100.0];
            [gkCenter reportQueuedAchievements];
        }];
        completeAchievement1Label.color = ccBLACK;
        completeAchievement1Label.position = ccp(winSize.width / 4, 50);
        [menu addChild:completeAchievement1Label];
        
        CCMenuItemLabel *completeAchievement2Label = [CCMenuItemLabel itemWithLabel:[CCLabelTTF labelWithString:@"Complete Achievement Two" fontName:@"Marker Felt" fontSize:28] block:^(id sender)
        {
            [gkCenter reportAchievementWithIdentifier:@"Achievement_Two" percentageCompleted:100.0];
            [gkCenter reportQueuedAchievements];
        }];
        completeAchievement2Label.color = ccBLACK;
        completeAchievement2Label.position = ccp(winSize.width / 4, 100);
        [menu addChild:completeAchievement2Label];
        
        CCMenuItemLabel *resetAchievementsLabel = [CCMenuItemLabel itemWithLabel:[CCLabelTTF labelWithString:@"Reset Achievements" fontName:@"Marker Felt" fontSize:28] block:^(id sender)
        {
            [gkCenter resetAchievements];
        }];
        resetAchievementsLabel.color = ccBLACK;
        resetAchievementsLabel.position = ccp(winSize.width / 4, 150);
        [menu addChild:resetAchievementsLabel];

        
        
        
        currentTimeScope = GKLeaderboardTimeScopeAllTime;
        timeScopeLabel = [CCMenuItemLabel itemWithLabel:[CCLabelTTF labelWithString:@"Time scope: All time" fontName:@"Marker Felt" fontSize:20] target:self selector:@selector(changeTimeScope)];
        timeScopeLabel.color = ccBLACK;
        timeScopeLabel.position = ccp(winSize.width * 3 / 4, winSize.height * 3 / 4);
        [menu addChild:timeScopeLabel];
        
        currentPlayerScope = GKLeaderboardPlayerScopeGlobal;
        playerScopeLabel = [CCMenuItemLabel itemWithLabel:[CCLabelTTF labelWithString:@"Player scope: Global" fontName:@"Marker Felt" fontSize:20] target:self selector:@selector(changePlayerScope)];
        playerScopeLabel.color = ccBLACK;
        playerScopeLabel.position = ccp(winSize.width * 3 / 4, winSize.height * 3 / 4 - 30);
        [menu addChild:playerScopeLabel];
        
        leaderboardBg = [CCLayerColor layerWithColor:ccc4(200, 200, 200, 255) width:300 height:400];
        leaderboardBg.anchorPoint = ccp(0.5f, 0.5f);
        leaderboardBg.ignoreAnchorPointForPosition = NO;
        leaderboardBg.position = ccp(winSize.width * 3 / 4, winSize.height / 8 * 3);
        [self addChild:leaderboardBg];
        
        scoreToReport = 100;
        reportScoreLabel = [CCMenuItemLabel itemWithLabel:[CCLabelTTF labelWithString:@"Report score: 100" fontName:@"Marker Felt" fontSize:20] target:self selector:@selector(reportScore)];
        reportScoreLabel.position = ccp(winSize.width * 3 / 4, 50);
        reportScoreLabel.label.color = ccBLACK;
        [menu addChild:reportScoreLabel];
        
        increaseScoreLabel = [CCMenuItemLabel itemWithLabel:[CCLabelTTF labelWithString:@"+" fontName:@"Marker Felt" fontSize:36] block:^(id sender) {
            scoreToReport += 10;
            [self updateScoreToReport];
        }];
        increaseScoreLabel.position = ccp(winSize.width * 3 / 4 + 100, 50);
        increaseScoreLabel.label.color = ccBLACK;
        [menu addChild:increaseScoreLabel];
        
        decreaseScoreLabel = [CCMenuItemLabel itemWithLabel:[CCLabelTTF labelWithString:@"-" fontName:@"Marker Felt" fontSize:36] block:^(id sender) {
            scoreToReport -= 10;
            [self updateScoreToReport];
        }];
        decreaseScoreLabel.position = ccp(winSize.width * 3 / 4 - 100, 50);
        decreaseScoreLabel.label.color = ccBLACK;
        [menu addChild:decreaseScoreLabel];
        
        CCMenuItemLabel *showAchievementsLabel = [CCMenuItemLabel itemWithLabel:[CCLabelTTF labelWithString:@"Show Achievements" fontName:@"Marker Felt" fontSize:36] block:^(id sender)
        {
            [gkCenter showAchievements];
        }];
        showAchievementsLabel.position = ccp(winSize.width / 4, winSize.height / 2 + 50);
        showAchievementsLabel.label.color = ccBLACK;
        [menu addChild:showAchievementsLabel];
        
        CCMenuItemLabel *showLeaderboardLabel = [CCMenuItemLabel itemWithLabel:[CCLabelTTF labelWithString:@"Show Leaderboard" fontName:@"Marker Felt" fontSize:36] block:^(id sender)
                                                  {
                                                      [gkCenter showLeaderboard:@"Leaderboard_1"];
                                                  }];
        showLeaderboardLabel.position = ccp(winSize.width / 4, winSize.height / 2 - 50);
        showLeaderboardLabel.label.color = ccBLACK;
        [menu addChild:showLeaderboardLabel];
        
        [self updateLeaderboard];
	}
	
	return self;
}

- (void)dealloc
{
    [gkCenter release];
	[super dealloc];
}

- (void)onEnter
{
	[super onEnter];
}

- (void)onExit
{
    [gkCenter removeDelegate:self];
    [menu removeFromParentAndCleanup:YES];
    [super onExit];
}

#pragma mark Protocol methods
#pragma mark -

- (void)scoresLoaded
{
    [self saveToFile];
    [self updateLeaderboard];
}

#pragma mark Private methods
#pragma mark -

- (void)saveToFile
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *gameSavePath = [documentsDirectory stringByAppendingPathComponent:@"savegame.dat"];
    NSMutableData *gameData = [NSMutableData data];
    
    NSKeyedArchiver *encoder = [[NSKeyedArchiver alloc] initForWritingWithMutableData:gameData];
    
    [encoder encodeObject:[gkCenter save] forKey:@"GameKitCenter"];
    
    [encoder finishEncoding];
    [gameData writeToFile:gameSavePath atomically:YES];
    [encoder release];
}

- (void)loadFromFile
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *gameSavePath = [documentsDirectory stringByAppendingPathComponent:@"savegame.dat"];
    NSMutableData *gameData = [NSMutableData dataWithContentsOfFile:gameSavePath];
    
    if (gameData)
    {
        NSKeyedUnarchiver *decoder = [[NSKeyedUnarchiver alloc] initForReadingWithData:gameData];
        
        [gkCenter loadFromDictionary:[decoder decodeObjectForKey:@"GameKitCenter"]];
        
        [decoder release];
    }
}

- (void)changeTimeScope
{
    currentTimeScope = (currentTimeScope + 1) % 3;
    
    switch (currentTimeScope) {
        case GKLeaderboardTimeScopeAllTime:
            timeScopeLabel.label.string = @"Time scope: All time";
            break;
            
        case GKLeaderboardTimeScopeWeek:
            timeScopeLabel.label.string = @"Time scope: This week";
            break;
            
        case GKLeaderboardTimeScopeToday:
            timeScopeLabel.label.string = @"Time scope: Today";
            break;
            
        default:
            break;
    }
    
    [self updateLeaderboard];
}

- (void)changePlayerScope
{
    currentPlayerScope = (currentPlayerScope + 1) % 2;
    
    switch (currentPlayerScope) {
        case GKLeaderboardPlayerScopeGlobal:
            playerScopeLabel.label.string = @"Player scope: Global";
            break;
            
        case GKLeaderboardPlayerScopeFriendsOnly:
            playerScopeLabel.label.string = @"Player scope: Friends only";
            break;
            
        default:
            break;
    }
    
    [self updateLeaderboard];
}

- (void)updateLeaderboard
{
    [leaderboardBg removeAllChildrenWithCleanup:YES];
    NSArray *scores = [gkCenter scoresWithLeaderboardID:@"Leaderboard_1" playerScope:currentPlayerScope timeScope:currentTimeScope range:NSMakeRange(1, 10)];
    
    for (int i = 0; i < scores.count; ++i)
    {
        id<GameKitScore> aScore = scores[i];
        
        CCLabelTTF *scoreLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"[%@] -> %.2f", aScore.playerID, aScore.value] fontName:@"Marker Felt" fontSize:20];
        scoreLabel.color = ccBLACK;
        scoreLabel.anchorPoint = ccp(0, 0.5f);
        scoreLabel.position = ccp(10, leaderboardBg.contentSize.height - 20 - i * 25);
        [leaderboardBg addChild:scoreLabel];
    }
}

- (void)updateScoreToReport
{
    reportScoreLabel.label.string = [NSString stringWithFormat:@"Report score: %d", scoreToReport];
}

- (void)reportScore
{
    [gkCenter reportScore:(double)scoreToReport leaderboardID:@"Leaderboard_1"];
    [self saveToFile];
    [self updateLeaderboard];
}

@end
