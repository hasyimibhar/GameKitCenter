//
//  CCGameKitCenterNotification.h
//  GameKitCenterTest
//
//  Created by Hasyimi Bahrudin on 10/31/12.
//
//

#import "cocos2d.h"
#import "GameKitCenterNotification.h"

@interface CCNode (RecursiveSchedulerMethods)
- (void)resumeSchedulerAndActionsRecursive;
@end

@interface CCGKCNotificationPanel : CCNode<GKCNotificationPanel>
@end

@interface CCGKCNotification : CCLayer<GKCNotification>
{
    Class                           panelClass;
    CCNode<GKCNotificationPanel>    *panel;
    NSMutableArray                  *achievementQueue;
}

@end