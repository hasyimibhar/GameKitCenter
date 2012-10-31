//
//  GameKitCenterNotification.h
//  GameKitCenterTest
//
//  Created by Hasyimi Bahrudin on 10/31/12.
//
//

#import "GameKitCenter.h"

@protocol GKCNotificationPanel;

@protocol GKCNotificationPanelDelegate <NSObject>
- (void)panelFinishedDisplaying:(id<GKCNotificationPanel>)aPanel;
@end

@protocol GKCNotificationPanel<NSObject>
- (id)initWithAchievement:(id<GameKitAchievement>)aAchievement;
@property (readwrite, assign, nonatomic) id<GKCNotificationPanelDelegate> delegate;
@end

@protocol GKCNotification <GKCNotificationPanelDelegate, GameKitCenterDelegate>
- (void)notifyAchievement:(id<GameKitAchievement>)aAchievement;

@property (readwrite, assign, nonatomic) Class panelClass;
@end
