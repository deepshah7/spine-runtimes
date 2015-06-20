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

@implementation SpineboyExample {
    CCLightNode *lightNode;
    CCLightNode *lightNode1;
}

+ (CCScene*) scene {
	CCScene *scene = [CCScene node];
	[scene addChild:[SpineboyExample node]];
	return scene;
}

-(id) init {
	self = [super init];
	if (!self) return nil;

//    NSString *characterName = @"hypno";
    NSString *characterName = @"goblins-mesh";
    NSString *jsonFileName = [NSString stringWithFormat:@"%@.json", characterName];
    NSString *atlasFileName = [NSString stringWithFormat:@"%@.atlas", characterName];
    NSString *mainFileFileName = [NSString stringWithFormat:@"%@.png", characterName];
    NSString *normalFileName = [NSString stringWithFormat:@"%@_n.png", characterName];
    CGSize size = [[CCDirector sharedDirector] viewSize];

	skeletonNode = [SkeletonAnimation skeletonWithFile:jsonFileName atlasFile:atlasFileName scale:1.0];
//    SkeletonAnimation *skeletonNode1 = [SkeletonAnimation skeletonWithFile:jsonFileName atlasFile:atlasFileName scale:1.0];
	[skeletonNode setSkin:@"goblin"];
//	[skeletonNode setAnimationForTrack:0 name:@"walk" loop:YES];

    CCSprite *sprite = [CCSprite spriteWithImageNamed:mainFileFileName];
//    CCSpriteFrame *normalMap = [CCSpriteFrame frameWithImageNamed:normalFileName];
//    CCSpriteFrame *normalMap1 = [CCSpriteFrame frameWithImageNamed:normalFileName];

//    sprite.normalMapSpriteFrame = normalMap1;
    sprite.effect = [CCEffectLighting effectWithGroups:@[@"g1"] specularColor:[CCColor whiteColor] shininess:1];
    sprite.position = ccp(size.width / 2, 200);
    [self addChild:sprite];

//	[skeletonNode setAnimationForTrack:0 name:@"hand_wave" loop:YES];
//	[skeletonNode setAnimationForTrack:0 name:@"idle" loop:YES];
//	[skeletonNode setAnimationForTrack:1 name:@"antenna_glow" loop:YES];

    [self addLights:size];

//    skeletonNode.debugBones = YES;
//    skeletonNode.debugSlots = YES;
//    skeletonNode.normalMapSpriteFrame = normalMap;

	[skeletonNode setPosition:ccp(size.width / 2, size.height / 2)];
    [skeletonNode updateWorldTransform];

    skeletonNode.effect = [CCEffectLighting effectWithGroups:@[@"g1"] specularColor:[CCColor whiteColor] shininess:1];
    skeletonNode.visible = YES;
    [self addChild:skeletonNode];

//	[skeletonNode1 setPosition:ccp(size.width / 4, size.height / 2)];
//    [skeletonNode1 updateWorldTransform];

//    skeletonNode1.visible = YES;
//    [self addChild:skeletonNode1];

    self.userInteractionEnabled = YES;
    self.contentSize = size;

	return self;
}

- (void)addLights:(CGSize)size {
    lightNode = [CCLightNode lightWithType:CCLightPoint groups:@[@"g1"]
                         color:[CCColor whiteColor] intensity:0.8
                 specularColor:[CCColor greenColor] specularIntensity:0.4
                  ambientColor:[CCColor whiteColor] ambientIntensity:0.0];

    lightNode.position = ccp(10, size.height/2);
    lightNode.visible = YES;
    lightNode.depth = 200;
    lightNode.halfRadius = 0.5;
    lightNode.scale = 1;
    lightNode.name = @"light";
    [self addChild:lightNode z:200];

    lightNode1 = [CCLightNode lightWithType:CCLightPoint groups:@[@"g1"]
                         color:[CCColor whiteColor] intensity:0.8
                 specularColor:[CCColor yellowColor] specularIntensity:0.4
                  ambientColor:[CCColor whiteColor] ambientIntensity:0.0];

    lightNode1.position = ccp(size.width - 10, size.height/2);
    lightNode1.visible = YES;
    lightNode1.depth = 200;
    lightNode1.halfRadius = 0.5;
    lightNode1.scale = 1;
    lightNode1.name = @"light1";
    [self addChild:lightNode1 z:200];
}

- (void)onEnter {
    [super onEnter];
}

- (void)touchBegan:(CCTouch *)touch withEvent:(CCTouchEvent *)event {
    CGPoint touchLocation = [touch locationInView:[touch view]];
    lightNode.position = ccp([[CCDirector sharedDirector] viewSize].width - touchLocation.x, [[CCDirector sharedDirector] viewSize].height - touchLocation.y);
    lightNode1.position = ccp(touchLocation.x, touchLocation.y);
}

-(void)touchMoved:(CCTouch *)touch withEvent:(CCTouchEvent*)event {
    CGPoint touchLocation = [touch locationInView:[touch view]];
    lightNode.position = ccp([[CCDirector sharedDirector] viewSize].width - touchLocation.x, [[CCDirector sharedDirector] viewSize].height - touchLocation.y);
    lightNode1.position = ccp(touchLocation.x, touchLocation.y);
}

@end
