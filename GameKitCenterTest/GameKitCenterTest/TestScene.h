//
//  TestScene.h
//  GameKitCenterTest
//
//  Created by Hasyimi Bahrudin on 10/23/12.
//
//

#import "cocos2d.h"
#import "GameKitCenter.h"

@interface TestScene : CCScene<GameKitCenterDelegate>
{
    GameKitCenter *gkCenter;
    
    CCMenu *menu;
    
    GKLeaderboardTimeScope currentTimeScope;
    CCMenuItemLabel *timeScopeLabel;
    
    GKLeaderboardPlayerScope currentPlayerScope;
    CCMenuItemLabel *playerScopeLabel;
    
    int scoreToReport;
    CCMenuItemLabel *reportScoreLabel;
    CCMenuItemLabel *decreaseScoreLabel;
    CCMenuItemLabel *increaseScoreLabel;
    
    CCLayerColor *leaderboardBg;
}

@end
