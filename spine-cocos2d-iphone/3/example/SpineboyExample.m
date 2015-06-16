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

#import <CoreGraphics/CoreGraphics.h>
#import "SpineboyExample.h"
#import "GoblinsExample.h"

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

//    skeletonNode = [SkeletonAnimation skeletonWithFile:@"spineboy.json" atlasFile:@"spineboy.atlas" scale:0.6];
	skeletonNode = [SkeletonAnimation skeletonWithFile:@"tiktok.json" atlasFile:@"tiktok.atlas" scale:0.6];
//	skeletonNode = [SkeletonAnimation skeletonWithFile:@"goldanic.json" atlasFile:@"goldanic.atlas" scale:0.6];
//	skeletonNode1 = [SkeletonAnimation skeletonWithFile:@"goldanic_n.json" atlasFile:@"goldanic_n.atlas" scale:0.6];

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

    CCSpriteFrame *normalMap = [CCSpriteFrame frameWithImageNamed:@"tiktok_n.png"];
//    CCSpriteFrame *normalMap = [CCSpriteFrame frameWithImageNamed:@"goldanic_n.png"];

	[skeletonNode setAnimationForTrack:0 name:@"idle" loop:YES];
    CGSize size = [[CCDirector sharedDirector] viewSize];

    [self addLights:size];

    skeletonNode.normalMapSpriteFrame = normalMap;

	[skeletonNode setPosition:ccp(size.width / 2, size.height / 2)];
    [skeletonNode updateWorldTransform];

    skeletonNode.effect = [CCEffectLighting effectWithGroups:@[@"g1"] specularColor:[CCColor whiteColor] shininess:1];
    skeletonNode.visible = YES;
    [self addChild:skeletonNode];

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
                 specularColor:[CCColor blueColor] specularIntensity:0.4
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
