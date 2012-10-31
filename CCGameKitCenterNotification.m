//
//  CCGameKitCenterNotification.m
//  GameKitCenterTest
//
//  Created by Hasyimi Bahrudin on 10/31/12.
//
//

#import "CCGameKitCenterNotification.h"

@implementation CCNode (RecursiveSchedulerMethods)

- (void)resumeSchedulerAndActionsRecursive
{
    [self resumeSchedulerAndActions];
    for (CCNode *aChild in self.children)
    {
        [aChild resumeSchedulerAndActionsRecursive];
    }
}

@end

@implementation CCGKCNotificationPanel

@synthesize delegate;

- (id)initWithAchievement:(id<GameKitAchievement>)aAchievement
{
	if ((self = [super init]))
	{
        CGSize winSize = [[CCDirector sharedDirector] winSize];
        
        // This panel will appear in the center of the screen
        self.position = ccp(winSize.width / 2, winSize.height);
        
        CCLayerColor *layerColor = [CCLayerColor layerWithColor:ccc4(100, 100, 100, 255) width:300 height:40];
        [layerColor setIsRelativeAnchorPoint:YES];
        layerColor.anchorPoint                  = ccp(0.5f, 0);
        [self addChild:layerColor];
        
        CCLabelTTF *title = [CCLabelTTF labelWithString:aAchievement.title fontName:@"Marker Felt" fontSize:20];
        title.anchorPoint = ccp(0, 0.5f);
        title.position = ccp(10, layerColor.contentSize.height / 2);
        [layerColor addChild:title];
        
        CCLabelTTF *pointsLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%d", aAchievement.points] fontName:@"Marker Felt" fontSize:20];
        pointsLabel.anchorPoint = ccp(1, 0.5f);
        pointsLabel.position = ccp(layerColor.contentSize.width - 10, layerColor.contentSize.height / 2);
        [layerColor addChild:pointsLabel];
        
        [layerColor runAction:[CCSequence actions:[CCMoveBy actionWithDuration:0.5f position:ccp(0, -layerColor.contentSize.height)], [CCDelayTime actionWithDuration:2.0f], [CCMoveBy actionWithDuration:0.5f position:ccp(0, layerColor.contentSize.height)], nil]];
        
        // This panel will disappear after 3 seconds.
        [self runAction:[CCSequence actionOne:[CCDelayTime actionWithDuration:3.0f] two:[CCCallBlock actionWithBlock:^{
            
            [self.delegate panelFinishedDisplaying:self];
            
        }]]];
	}
	
	return self;
}

- (void)dealloc
{
	[super dealloc];
}

@end



@interface CCGKCNotification ()
- (void)notifyNextQueuedAchievement;
@end

@implementation CCGKCNotification

#pragma mark Public methods
#pragma mark -

@synthesize panelClass;

- (void)setPanelClass:(Class)aPanelClass
{
    if (aPanelClass)
    {
        id test = [aPanelClass node];
        assert([test conformsToProtocol:@protocol(GKCNotificationPanel)]);
        panelClass = aPanelClass;
    }
    else
    {
        panelClass = nil;
    }
}

- (id)init
{
	if ((self = [super init]))
	{
        panelClass  = nil;
        panel       = nil;
        achievementQueue = [[NSMutableArray alloc] init];
	}
	
	return self;
}

- (void)dealloc
{
    [achievementQueue release];
	[super dealloc];
}

- (void)notifyAchievement:(id<GameKitAchievement>)aAchievement
{
    if (panelClass)
    {
        if (panel == nil)
        {
            panel = [[[panelClass alloc] initWithAchievement:aAchievement] autorelease];
            assert(panel);
            
            panel.delegate = self;
            [panel retain];
            
            [panel resumeSchedulerAndActionsRecursive];
        }
        else
        {
            [achievementQueue addObject:aAchievement];
        }
    }
}

- (void)visit
{
    [panel visit];
}

#pragma mark Protocol methods
#pragma mark -

- (void)panelFinishedDisplaying:(CCNode<GKCNotificationPanel> *)aPanel
{
    assert(panel == aPanel);
    [panel release];
    panel = nil;
    [self notifyNextQueuedAchievement];
}

- (void)achievementCompleted:(id<GameKitAchievement>)achievement
{
    [self notifyAchievement:achievement];
}

#pragma mark Private methods
#pragma mark -

- (void)notifyNextQueuedAchievement
{
    assert(panel == nil);
    
    if (achievementQueue.count > 0)
    {
        id<GameKitAchievement> achievement = achievementQueue[0];
        [achievementQueue removeObjectAtIndex:0];
        [self notifyAchievement:achievement];
    }
}

@end