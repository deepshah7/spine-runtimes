/******************************************************************************
 * Spine Runtimes Software License
 * Version 2.3
 * 
 * Copyright (c) 2013-2015, Esoteric Software
 * All rights reserved.
 * 
 * You are granted a perpetual, non-exclusive, non-sublicensable and
 * non-transferable license to use, install, execute and perform the Spine
 * Runtimes Software (the "Software") and derivative works solely for personal
 * or internal use. Without the written permission of Esoteric Software (see
 * Section 2 of the Spine Software License Agreement), you may not (a) modify,
 * translate, adapt or otherwise create derivative works, improvements of the
 * Software or develop new applications using the Software or (b) remove,
 * delete, alter or obscure any trademarks or any copyright, trademark, patent
 * or other intellectual property or proprietary rights notices on or in the
 * Software, including any copy thereof. Redistributions in binary or source
 * form must include this license and terms.
 * 
 * THIS SOFTWARE IS PROVIDED BY ESOTERIC SOFTWARE "AS IS" AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL ESOTERIC SOFTWARE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************/

#import "SpineboyExample.h"
#import "GoblinsExample.h"

@implementation SpineboyExample

+ (CCScene*) scene {
	CCScene *scene = [CCScene node];
	[scene addChild:[SpineboyExample node]];
	return scene;
}

-(id) init {
	self = [super init];
	if (!self) return nil;

//    skeletonNode = [SkeletonAnimation skeletonWithFile:@"spineboy.json" atlasFile:@"spineboy.atlas" scale:0.6];
	skeletonNode = [SkeletonAnimation skeletonWithFile:@"goldanic.json" atlasFile:@"goldanic.atlas" scale:0.6];
	skeletonNode1 = [SkeletonAnimation skeletonWithFile:@"goldanic_n.json" atlasFile:@"goldanic_n.atlas" scale:0.6];
//	[skeletonNode setMixFrom:@"walk" to:@"jump" duration:0.2f];
//	[skeletonNode setMixFrom:@"jump" to:@"run" duration:0.2f];

    __weak SkeletonAnimation* node = skeletonNode;
	skeletonNode.startListener = ^(int trackIndex) {
		spTrackEntry* entry = spAnimationState_getCurrent(node.state, trackIndex);
		const char* animationName = (entry && entry->animation) ? entry->animation->name : 0;
		NSLog(@"%d start: %s", trackIndex, animationName);
	};
	skeletonNode.endListener = ^(int trackIndex) {
		NSLog(@"%d end", trackIndex);
	};
	skeletonNode.completeListener = ^(int trackIndex, int loopCount) {
		NSLog(@"%d complete: %d", trackIndex, loopCount);
	};
	skeletonNode.eventListener = ^(int trackIndex, spEvent* event) {
		NSLog(@"%d event: %s, %d, %f, %s", trackIndex, event->data->name, event->intValue, event->floatValue, event->stringValue);
	};
//    skeletonNode.effect = [CCEffectLighting effectWithGroups:@[@"g1"] specularColor:[CCColor whiteColor] shininess:1.0];

//    CCSpriteFrame *normalMap = [CCSpriteFrame frameWithImageNamed:@"goldanic_n.png"];
    CCSpriteFrame *normalMap = [CCSpriteFrame frameWithImageNamed:@"goldanic_n.png"];
    CCSprite *goldanic = [CCSprite spriteWithImageNamed:@"goldanic.png"];
//    skeletonNode.normalMapSpriteFrame = [normalMap copy];
    goldanic.normalMapSpriteFrame = normalMap;
    [goldanic setPosition:ccp(500, 350)];
    goldanic.effect = [CCEffectLighting effectWithGroups:@[@"g1"] specularColor:[CCColor whiteColor] shininess:1.0];
    goldanic.name = @"goldanic";
//    [self addChild:goldanic z:10];
	[skeletonNode setAnimationForTrack:0 name:@"idle" loop:YES];
	[skeletonNode1 setAnimationForTrack:0 name:@"idle" loop:YES];
    CGSize size = [[CCDirector sharedDirector] viewSize];
    CCLightNode *lightNode = [CCLightNode lightWithType:CCLightPoint groups:@[@"g1"]
                         color:[CCColor whiteColor] intensity:0.8
                 specularColor:[CCColor greenColor] specularIntensity:0.4
                  ambientColor:[CCColor whiteColor] ambientIntensity:0.0];

    lightNode.position = ccp(100, size.height/2);
    lightNode.visible = YES;
    lightNode.depth = 200;
    lightNode.halfRadius = 0.5;
    lightNode.scale = 1;
    lightNode.name = @"light";
    [self addChild:lightNode z:11];

    CCLightNode *lightNode1 = [CCLightNode lightWithType:CCLightPoint groups:@[@"g1"]
                         color:[CCColor whiteColor] intensity:0.8
                 specularColor:[CCColor redColor] specularIntensity:0.4
                  ambientColor:[CCColor whiteColor] ambientIntensity:0.0];

    lightNode1.position = ccp(900, size.height/2);
    lightNode1.visible = YES;
    lightNode1.depth = 200;
    lightNode1.halfRadius = 0.5;
    lightNode1.scale = 1;
    lightNode1.name = @"light1";
    [self addChild:lightNode1 z:11];

//	[skeletonNode runAction:[CCEffectLighting ]]
//	spTrackEntry* jumpEntry = [skeletonNode addAnimationForTrack:0 name:@"jump" loop:NO afterDelay:3];
//	[skeletonNode addAnimationForTrack:0 name:@"run" loop:YES afterDelay:0];
//
//	[skeletonNode setListenerForEntry:jumpEntry onStart:^(int trackIndex) {
//		CCLOG(@"jumped!");
//	}];

	// [skeletonNode setAnimationForTrack:1 name:@"test" loop:YES];

	CGSize windowSize = size;
	[skeletonNode setPosition:ccp(windowSize.width / 2, 20)];
	[skeletonNode1 setPosition:ccp(windowSize.width / 2, 20)];
    [skeletonNode updateWorldTransform];
//    [self addChild:skeletonNode];
    [self createBackgroundTexture:skeletonNode];
//    [goldanic addChild:skeletonNode z:10];
//    [goldanic addChild:skeletonNode1 z:9];


	self.userInteractionEnabled = YES;
    self.contentSize = windowSize;

	return self;
}

- (void)onEnter {
    [super onEnter];
}

- (void) createBackgroundTexture:(SkeletonAnimation*)node
{
    CGSize size = node.boundingBox.size;
//    CCRenderTexture* renderedNode = [CCRenderTexture renderTextureWithWidth:size.width
//                                                                     height:size.height];
//    [renderedNode beginWithClear:0 g:0 b:0 a:1];
//    [node visit];
//    [renderedNode end];

    CCEffectNode* effectNode = [CCEffectNode effectNodeWithWidth:size.width * 2
                                                          height:size.height * 2];
//    CCSprite* nodeSprite = [CCSprite spriteWithTexture:node.texture];
//    nodeSprite.anchorPoint = ccp(0, 0);
    [effectNode addChild:node];
//    effectNode.effect = [CCEffectBlur effectWithBlurRadius:3];
    effectNode.effect = [CCEffectLighting effectWithGroups:@[@"g1"] specularColor:[CCColor whiteColor] shininess:1.0];
    effectNode.visible = YES;
    node.visible = YES;
    node.position = ccp(100, 100);
    effectNode.contentScale = 5;
    effectNode.contentSize = CGSizeMake(500, 500);
    effectNode.position = ccp(0, 0);

//    CCRenderTexture* renderedEffectNode = [CCRenderTexture renderTextureWithWidth:size.width
//                                                                           height:size.height];
//    [renderedEffectNode beginWithClear:0 g:0 b:0 a:1];
//    [effectNode visit];
//    [renderedEffectNode end];

//    CCSprite* background = [CCSprite spriteWithTexture:renderedEffectNode.texture];
//    background.position = ccp(500,100);
    [self addChild:effectNode z: 20];
}

- (void)update:(CCTime)delta {
//    [super update:delta];
    CCNode *node = [self getChildByName:@"light" recursively:NO];
    node.position = ccp(node.position.x+10, node.position.y);
    CCNode *node1 = [self getChildByName:@"light1" recursively:NO];
    node1.position = ccp(node1.position.x, node1.position.y + 10);
    if(node.position.x > 1024 || node.position.y > 768) {
        node.position = ccp(0,0);
    }
    if(node1.position.x > 1024 || node1.position.y > 768) {
        node1.position = ccp(0,0);
    }
}


#if ( TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR )
- (void)touchBegan:(UITouch *)touch withEvent:(UIEvent *)event {
	if (!skeletonNode.debugBones)
		skeletonNode.debugBones = true;
	else if (skeletonNode.timeScale == 1)
		skeletonNode.timeScale = 0.3f;
	else
		[[CCDirector sharedDirector] replaceScene:[GoblinsExample scene]];
}
#endif

@end
