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

#import <spine/SkeletonRenderer.h>
#import <spine/extension.h>
#import "CCEffect_Private.h"
#import "CCSprite_Private.h"

static const int quadTriangles[6] = {0, 1, 2, 2, 3, 0};

@interface SkeletonRenderer (Private)
- (void) initialize:(spSkeletonData*)skeletonData ownsSkeletonData:(bool)ownsSkeletonData;
@end

@implementation SkeletonRenderer {
    BOOL isDone;
    int count;
}

@synthesize skeleton = _skeleton;
@synthesize rootBone = _rootBone;
@synthesize debugSlots = _debugSlots;
@synthesize debugBones = _debugBones;

+ (id) skeletonWithData:(spSkeletonData*)skeletonData ownsSkeletonData:(bool)ownsSkeletonData {
	return [[[self alloc] initWithData:skeletonData ownsSkeletonData:ownsSkeletonData] autorelease];
}

+ (id) skeletonWithFile:(NSString*)skeletonDataFile atlas:(spAtlas*)atlas scale:(float)scale {
	return [[[self alloc] initWithFile:skeletonDataFile atlas:atlas scale:scale] autorelease];
}

+ (id) skeletonWithFile:(NSString*)skeletonDataFile atlasFile:(NSString*)atlasFile scale:(float)scale {
	return [[[self alloc] initWithFile:skeletonDataFile atlasFile:atlasFile scale:scale] autorelease];
}

- (void) initialize:(spSkeletonData*)skeletonData ownsSkeletonData:(bool)ownsSkeletonData {
    count = 0;
	_ownsSkeletonData = ownsSkeletonData;

	_worldVertices = MALLOC(float, 1000); // Max number of vertices per mesh.

	_skeleton = spSkeleton_create(skeletonData);
	_rootBone = _skeleton->bones[0];

	_blendFunc.src = GL_ONE;
	_blendFunc.dst = GL_ONE_MINUS_SRC_ALPHA;
	_drawNode = [[CCDrawNode alloc] init];
	[_drawNode setBlendMode: [CCBlendMode premultipliedAlphaMode]];
	[self addChild:_drawNode];
	
	[self setShader:[CCShader positionTextureColorShader]];

	_premultipliedAlpha = true;
	screenMode = [CCBlendMode blendModeWithOptions:@{
		CCBlendFuncSrcColor: @(GL_ONE),
		CCBlendFuncDstColor: @(GL_ONE_MINUS_SRC_COLOR)}
	];
}

- (id) initWithData:(spSkeletonData*)skeletonData ownsSkeletonData:(bool)ownsSkeletonData {
	NSAssert(skeletonData, @"skeletonData cannot be null.");

	self = [super init];
	if (!self) return nil;

	[self initialize:skeletonData ownsSkeletonData:ownsSkeletonData];

	return self;
}

- (id) initWithFile:(NSString*)skeletonDataFile atlas:(spAtlas*)atlas scale:(float)scale {
	self = [super init];
	if (!self) return nil;

	spSkeletonJson* json = spSkeletonJson_create(atlas);
	json->scale = scale;
	spSkeletonData* skeletonData = spSkeletonJson_readSkeletonDataFile(json, [skeletonDataFile UTF8String]);
	NSAssert(skeletonData, ([NSString stringWithFormat:@"Error reading skeleton data file: %@\nError: %s", skeletonDataFile, json->error]));
	spSkeletonJson_dispose(json);
	if (!skeletonData) return 0;

	[self initialize:skeletonData ownsSkeletonData:YES];

	return self;
}

- (id) initWithFile:(NSString*)skeletonDataFile atlasFile:(NSString*)atlasFile scale:(float)scale {
	self = [super init];
	if (!self) return nil;

	_atlas = spAtlas_createFromFile([atlasFile UTF8String], 0);
	NSAssert(_atlas, ([NSString stringWithFormat:@"Error reading atlas file: %@", atlasFile]));
	if (!_atlas) return 0;

	spSkeletonJson* json = spSkeletonJson_create(_atlas);
	json->scale = scale;
	spSkeletonData* skeletonData = spSkeletonJson_readSkeletonDataFile(json, [skeletonDataFile UTF8String]);
	NSAssert(skeletonData, ([NSString stringWithFormat:@"Error reading skeleton data file: %@\nError: %s", skeletonDataFile, json->error]));
	spSkeletonJson_dispose(json);
	if (!skeletonData) return 0;

	[self initialize:skeletonData ownsSkeletonData:YES];

	return self;
}

- (void) dealloc {
	if (_ownsSkeletonData) spSkeletonData_dispose(_skeleton->data);
	if (_atlas) spAtlas_dispose(_atlas);
	spSkeleton_dispose(_skeleton);
	FREE(_worldVertices);
    [super dealloc];
}

-(void)draw:(CCRenderer *)renderer transform:(const GLKMatrix4 *)transform {
	CCColor* nodeColor = self.color;
	_skeleton->r = nodeColor.red;
	_skeleton->g = nodeColor.green;
	_skeleton->b = nodeColor.blue;
	_skeleton->a = self.displayedOpacity;

	int blendMode = -1;
	const float* uvs = 0;
	int verticesCount = 0;
	const int* triangles = 0;
	int trianglesCount = 0;
	float r = 0, g = 0, b = 0, a = 0;
	for (int i = 0, n = _skeleton->slotsCount; i < n; i++) {
		spSlot* slot = _skeleton->drawOrder[i];
		if (!slot->attachment) continue;
		CCTexture *texture = 0;
		switch (slot->attachment->type) {
		case SP_ATTACHMENT_REGION: {
			spRegionAttachment* attachment = (spRegionAttachment*)slot->attachment;
			spRegionAttachment_computeWorldVertices(attachment, slot->bone, _worldVertices);
			texture = [self getTextureForRegion:attachment];
			uvs = attachment->uvs;
			verticesCount = 8;
			triangles = quadTriangles;
			trianglesCount = 6;
			r = attachment->r;
			g = attachment->g;
			b = attachment->b;
			a = attachment->a;
			break;
		}
		case SP_ATTACHMENT_MESH: {
			spMeshAttachment* attachment = (spMeshAttachment*)slot->attachment;
			spMeshAttachment_computeWorldVertices(attachment, slot, _worldVertices);
			texture = [self getTextureForMesh:attachment];
			uvs = attachment->uvs;
			verticesCount = attachment->verticesCount;
			triangles = attachment->triangles;
			trianglesCount = attachment->trianglesCount;
			r = attachment->r;
			g = attachment->g;
			b = attachment->b;
			a = attachment->a;
			break;
		}
		case SP_ATTACHMENT_SKINNED_MESH: {
			spSkinnedMeshAttachment* attachment = (spSkinnedMeshAttachment*)slot->attachment;
			spSkinnedMeshAttachment_computeWorldVertices(attachment, slot, _worldVertices);
			texture = [self getTextureForSkinnedMesh:attachment];
			uvs = attachment->uvs;
			verticesCount = attachment->uvsCount;
			triangles = attachment->triangles;
			trianglesCount = attachment->trianglesCount;
			r = attachment->r;
			g = attachment->g;
			b = attachment->b;
			a = attachment->a;
			break;
		}
		default: ;
		}
		if (texture) {
			if (slot->data->blendMode != blendMode) {
				blendMode = slot->data->blendMode;
				switch (slot->data->blendMode) {
				case SP_BLEND_MODE_ADDITIVE:
					[self setBlendMode:[CCBlendMode addMode]];
					break;
				case SP_BLEND_MODE_MULTIPLY:
					[self setBlendMode:[CCBlendMode multiplyMode]];
					break;
				case SP_BLEND_MODE_SCREEN:
					[self setBlendMode:screenMode];
					break;
				default:
					[self setBlendMode:_premultipliedAlpha ? [CCBlendMode premultipliedAlphaMode] : [CCBlendMode alphaMode]];
				}
			}
			if (_premultipliedAlpha) {
				a *= _skeleton->a * slot->a;
				r *= _skeleton->r * slot->r * a;
				g *= _skeleton->g * slot->g * a;
				b *= _skeleton->b * slot->b * a;
			} else {
				a *= _skeleton->a * slot->a;
				r *= _skeleton->r * slot->r;
				g *= _skeleton->g * slot->g;
				b *= _skeleton->b * slot->b;
			}
			self.texture = texture;
			CGSize size = texture.contentSize;
			GLKVector2 center = GLKVector2Make(size.width / 2.0, size.height / 2.0);
			GLKVector2 extents = GLKVector2Make(size.width / 2.0, size.height / 2.0);
            NSString *string = [NSString stringWithUTF8String:slot->data->name];
            isDone = YES;
            if([string isEqualToString:@"left upper leg"] && count == 0) {
                isDone = NO;
                count++;
            }
			if (CCRenderCheckVisbility(transform, center, extents)) {
				CCRenderBuffer buffer =
                        [renderer enqueueTriangles:(trianglesCount / 3) andVertexes:verticesCount
                                                         withState:self.renderState globalSortOrder:0];
                CCVertex vertexArray[verticesCount / 2 + (verticesCount % 2 == 0? 0 : 1)];
                int currentIndex = -1;
				for (int i = 0; i * 2 < verticesCount; ++i) {
					CCVertex vertex;
					vertex.position = GLKVector4Make(_worldVertices[i * 2], _worldVertices[i * 2 + 1], 0.0, 1.0);
					vertex.color = GLKVector4Make(r, g, b, 1);
					vertex.texCoord1 = GLKVector2Make(uvs[i * 2], 1 - uvs[i * 2 + 1]);
					vertex.texCoord2 = GLKVector2Make(uvs[i * 2], 1 - uvs[i * 2 + 1]);

                    currentIndex++;
                    vertexArray[currentIndex] = vertex;

                    CCRenderBufferSetVertex(buffer, i, CCVertexApplyTransform(vertex, transform));
//                    if(!self.effect) {
//                        CCRenderBufferSetVertex(buffer, i, CCVertexApplyTransform(vertex, transform));
//                    }
				}

                if(!self.effect) {
                    for (int j = 0; j * 3 < trianglesCount; ++j) {
                        CCRenderBufferSetTriangle(buffer, j, triangles[j * 3], triangles[j * 3 + 1], triangles[j * 3 + 2]);
                    }
                }
                else {
//                    for (int j = 0; j * 3 < trianglesCount; ++j) {
//                        CCRenderBufferSetTriangle(buffer, j, triangles[j * 3], triangles[j * 3 + 1], triangles[j * 3 + 2]);
//                    }
                    for (int j = 0; j * 3 < trianglesCount; ++j) {
                        if(![string isEqualToString:@"left upper leg"]) continue;

                        if(j!= 0 && j != 1 && j!= 2 && j!= 3 && j!= 4 && j!= 5 && j!= 6 && [string isEqualToString:@"left upper leg"]) {
                            NSLog(@"Debug");
                            continue;
                        }
                        CCVertex v1 = vertexArray[triangles[j * 3]];
                        CCVertex v2 = vertexArray[triangles[j * 3 + 1]];
                        CCVertex v3 = vertexArray[triangles[j * 3 + 2]];
//                        CCVertex v4 = vertexArray[triangles[j * 3 + 2]];
//                        CCRenderBufferSetTriangle(buffer, j, triangles[j * 3], triangles[j * 3 + 1], triangles[j * 3 + 2]);

                        CCVertex v11 = CCVertexApplyTransform(v1, transform);
                        CCVertex v21 = CCVertexApplyTransform(v2, transform);
                        CCVertex v31 = CCVertexApplyTransform(v3, transform);
                        if (j==0) {
                            _verts.bl = v2;
                            _verts.br = v1;
                            _verts.tl = v2;
                            _verts.tr = v3;
                        } else if(j == 1) {
                            _verts.bl = v2;
                            _verts.br = v1;
                            _verts.tl = v2;
                            _verts.tr = v3;
                        } else if(j == 2) {
                            _verts.bl = v1;
                            _verts.tr = v2;
//                            _verts.bl = v3;
                            _verts.br = v3;
                        } else if(j == 3) {
                            _verts.br = v1;
                            _verts.bl = v2;
                            _verts.tr = v3;
                            _verts.tl = v3;
                        } else if(j == 4) {
                            //TODO: Doubtful -- DEEP
                            _verts.tr = v1;
                            _verts.br = v2;
                            _verts.bl = v3;
                            _verts.tl = v3;
                        } else if(j == 5) {
                            _verts.bl = v1;
                            _verts.br = v2;
                            _verts.tr = v3;
//                            _verts.bl = v3;
                        } else if(j == 6) {
                            //TODO: Doubtful -- DEEP
                            _verts.br = v1;
                            _verts.bl = v2;
                            _verts.tl = v3;
                            _verts.tr = v3;
                        }

                        BOOL isSet = YES;
//                        for (int k = 3*(j + 1); k < trianglesCount; k+=3) {
//                            if(k == 3*j) continue;
//                            if(
//                                    (triangles[k] == triangles[j * 3]
//                                    || triangles[k] == triangles[j * 3 + 1]
//                                    || triangles[k] == triangles[j * 3 + 2])
//                                &&
//                                    (triangles[k + 1] == triangles[j * 3]
//                                    || triangles[k + 1] == triangles[j * 3 + 1]
//                                    || triangles[k + 1] == triangles[j * 3 + 2])
//
//                                    ) {
//                                v4 = vertexArray[triangles[k + 2]];
//                                isSet = YES;
//                                break;
//                            }
//                            if(
//                                    (triangles[k + 2] == triangles[j * 3]
//                                    || triangles[k + 2] == triangles[j * 3 + 1]
//                                    || triangles[k + 2] == triangles[j * 3 + 2])
//                                &&
//                                    (triangles[k + 1] == triangles[j * 3]
//                                    || triangles[k + 1] == triangles[j * 3 + 1]
//                                    || triangles[k + 1] == triangles[j * 3 + 2])
//
//                                    ) {
//                                v4 = vertexArray[triangles[k]];
//                                isSet = YES;
//                                break;
//                            }
//                            if(
//                                    (triangles[k + 2] == triangles[j * 3]
//                                    || triangles[k + 2] == triangles[j * 3 + 1]
//                                    || triangles[k + 2] == triangles[j * 3 + 2])
//                                &&
//                                    (triangles[k] == triangles[j * 3]
//                                    || triangles[k] == triangles[j * 3 + 1]
//                                    || triangles[k] == triangles[j * 3 + 2])
//
//                                    ) {
//                                v4 = vertexArray[triangles[k+1]];
//                                isSet = YES;
//                                break;
//                            }
//                        }
//                        if(!isSet) {
//                            for (int k = 0; k < 3*j; k+=3) {
//                                if(k == 3*j) continue;
//                                if(
//                                        (triangles[k] == triangles[j * 3]
//                                                || triangles[k] == triangles[j * 3 + 1]
//                                                || triangles[k] == triangles[j * 3 + 2])
//                                                &&
//                                                (triangles[k + 1] == triangles[j * 3]
//                                                        || triangles[k + 1] == triangles[j * 3 + 1]
//                                                        || triangles[k + 1] == triangles[j * 3 + 2])
//
//                                        ) {
//                                    v4 = vertexArray[triangles[k + 2]];
//                                    isSet = YES;
//                                    break;
//                                }
//                                if(
//                                        (triangles[k + 2] == triangles[j * 3]
//                                                || triangles[k + 2] == triangles[j * 3 + 1]
//                                                || triangles[k + 2] == triangles[j * 3 + 2])
//                                                &&
//                                                (triangles[k + 1] == triangles[j * 3]
//                                                        || triangles[k + 1] == triangles[j * 3 + 1]
//                                                        || triangles[k + 1] == triangles[j * 3 + 2])
//
//                                        ) {
//                                    v4 = vertexArray[triangles[k]];
//                                    isSet = YES;
//                                    break;
//                                }
//                                if(
//                                        (triangles[k + 2] == triangles[j * 3]
//                                                || triangles[k + 2] == triangles[j * 3 + 1]
//                                                || triangles[k + 2] == triangles[j * 3 + 2])
//                                                &&
//                                                (triangles[k] == triangles[j * 3]
//                                                        || triangles[k] == triangles[j * 3 + 1]
//                                                        || triangles[k] == triangles[j * 3 + 2])
//
//                                        ) {
//                                    v4 = vertexArray[triangles[k+1]];
//                                    isSet = YES;
//                                    break;
//                                }
//                            }
//                        }

                        if(!isSet) {
                            NSLog(@"Not found the vertex!");
                        }
//                        isSet = YES;
                        if(isSet) {
                            for (int m = 0; m < 1; ++m) {
//                                if(m == 0) {
//                                    v4 = v1;
//                                } else if (m == 1) {
//                                    v4 = v2;
//                                } else {
//                                    v4 = v3;
//                                }
//                                CCVertex ySorted[4];
//                                ySorted[0] = v1; ySorted[1] = v2; ySorted[2] = v3, ySorted[3] = v4;
//
//                                CCVertex xSorted[4];
//                                xSorted[0] = v1; xSorted[1] = v2; xSorted[2] = v3, xSorted[3] = v4;
//
//
//                                for (int k = 0; k < 4; ++k) {
//                                    for (int l = k+1; l < 4; ++l) {
//                                        if(ySorted[k].texCoord1.y > ySorted[l].texCoord1.y) {
//                                            CCVertex temp = ySorted[k];
//                                            ySorted[k] = ySorted[l];
//                                            ySorted[l] = temp;
//                                        } else if(ySorted[k].texCoord1.y == ySorted[l].texCoord1.y
//                                                && ySorted[k].texCoord1.x > ySorted[l].texCoord1.x) {
////                                        NSLog(@"sdfkfjklslkf#@@@@@@@@@@@@@@Y same X sorting!");
//                                            CCVertex temp = ySorted[k];
//                                            ySorted[k] = ySorted[l];
//                                            ySorted[l] = temp;
//                                        }
//                                    }
//                                }
//
//                                for (int k = 0; k < 4; ++k) {
//                                    for (int l = k+1; l < 4; ++l) {
//                                        if(xSorted[k].position.x > xSorted[l].position.x) {
//                                            CCVertex temp = xSorted[k];
//                                            xSorted[k] = xSorted[l];
//                                            xSorted[l] = temp;
//                                        } else if(xSorted[k].position.x == xSorted[l].position.x
//                                                && xSorted[k].position.y > xSorted[l].position.y) {
////                                        NSLog(@"######################X same Y sorting!");
//                                            CCVertex temp = xSorted[k];
//                                            xSorted[k] = xSorted[l];
//                                            xSorted[l] = temp;
//                                        }
//                                    }
//                                }
//
//                                if(ySorted[0].position.x < ySorted[1].position.x) {
//                                    _verts.bl = ySorted[0];
//                                    _verts.br = ySorted[1];
//                                } else {
//                                    _verts.bl = ySorted[1];
//                                    _verts.br = ySorted[0];
//                                }
//                                if(ySorted[2].position.x < ySorted[3].position.x) {
//                                    _verts.tl = ySorted[2];
//                                    _verts.tr = ySorted[3];
//                                } else {
//                                    _verts.tl = ySorted[3];
//                                    _verts.tr = ySorted[2];
//                                }

                                [self renderStuff:renderer transform:transform slot:slot j:j vertexArray:vertexArray triangles:triangles];

//                                if(xSorted[0].position.y < xSorted[1].position.y) {
//                                    _verts.bl = xSorted[0];
//                                    _verts.tl = xSorted[1];
//                                } else {
//                                    _verts.bl = xSorted[1];
//                                    _verts.tl = xSorted[0];
//                                }
//                                if(xSorted[2].position.y < xSorted[3].position.y) {
//                                    _verts.br = xSorted[2];
//                                    _verts.tr = xSorted[3];
//                                } else {
//                                    _verts.br = xSorted[3];
//                                    _verts.tr = xSorted[2];
//                                }
//
//                                _verts.br = xSorted[2];
//                                _verts.tr = xSorted[3];
//
//                                [self renderStuff:renderer transform:transform slot:slot j:j vertexArray:vertexArray triangles:triangles];

                            }

                        }

//                        float distV1V2 = ccpDistance(ccp(v1.position.x, v1.position.y), ccp(v2.position.x, v2.position.y));
//                        float distV2V3 = ccpDistance(ccp(v2.position.x, v2.position.y), ccp(v3.position.x, v3.position.y));
//                        float distV1V3 = ccpDistance(ccp(v1.position.x, v1.position.y), ccp(v3.position.x, v3.position.y));

//                        if(distV1V2 >= distV2V3 && distV1V2 >= distV1V3) {
//                            v4 = [self buildV4: v1 v2: v2 v3: v3];
//                        [self renderCyclic:renderer transform:transform triangles:triangles slot:slot vertexArray:vertexArray j:j v1:&v1 v2:&v2 v3:&v3 v4:&v4];

//                        }

//                        else if(distV2V3 >= distV1V2 && distV2V3 >= distV1V3) {
//                            v4 = [self buildV4: v2 v2: v3 v3: v1];
//                        [self renderCyclic:renderer transform:transform triangles:triangles slot:slot vertexArray:vertexArray j:j v1:&v1 v2:&v2 v3:&v3 v4:&v4];
//                        }

//                        else {
//                            v4 = [self buildMaxV4: v1 v2: v3 v3: v2];
//                        [self renderTR:renderer transform:transform triangles:triangles slot:slot vertexArray:vertexArray j:j v1:&v1 v2:&v2 v3:&v3 v4:&v4];
//                            v4 = [self buildMaxV4: v1 v2: v2 v3: v3];
//                        [self renderTR:renderer transform:transform triangles:triangles slot:slot vertexArray:vertexArray j:j v1:&v1 v2:&v3 v3:&v2 v4:&v4];
//                            v4 = [self buildMinV4: v1 v2: v3 v3: v2];
//                        [self renderBL:renderer transform:transform triangles:triangles slot:slot vertexArray:vertexArray j:j v1:&v1 v2:&v2 v3:&v3 v4:&v4];
//                            v4 = [self buildMinV4: v1 v2: v2 v3: v3];
//                        [self renderBL:renderer transform:transform triangles:triangles slot:slot vertexArray:vertexArray j:j v1:&v1 v2:&v3 v3:&v2 v4:&v4];
//                        [self renderTR:renderer transform:transform triangles:triangles slot:slot vertexArray:vertexArray j:j v1:&v1 v2:&v2 v3:&v3 v4:&v4];
//                            v4 = [self buildMaxV4: v1 v2: v3 v3: v2];
//                        [self renderTL:renderer transform:transform triangles:triangles slot:slot vertexArray:vertexArray j:j v1:&v1 v2:&v2 v3:&v3 v4:&v4];
//                            v4 = [self buildMaxMinV4: v1 v2: v3 v3: v2];
//                        [self renderBR:renderer transform:transform triangles:triangles slot:slot vertexArray:vertexArray j:j v1:&v1 v2:&v2 v3:&v3 v4:&v4];
//                            v4 = [self buildMaxMinV4: v1 v2: v3 v3: v2];
//                        [self renderBR:renderer transform:transform triangles:triangles slot:slot vertexArray:vertexArray j:j v1:&v1 v2:&v2 v3:&v3 v4:&v4];
//                        }

//                        [self renderCyclic:renderer transform:transform triangles:triangles slot:slot vertexArray:vertexArray j:j v1:&v1 v2:&v2 v3:&v3 v4:&v4];

                        /*
                        CCVertex ySorted[4];
                        ySorted[0] = v1; ySorted[1] = v2; ySorted[2] = v3, ySorted[3] = v4;

                        CCVertex xSorted[4];
                        xSorted[0] = v1; xSorted[1] = v2; xSorted[2] = v3, xSorted[3] = v4;


                        for (int k = 0; k < 4; ++k) {
                            for (int l = k+1; l < 4; ++l) {
                                if(ySorted[k].position.y > ySorted[l].position.y) {
                                    CCVertex temp = ySorted[k];
                                    ySorted[k] = ySorted[l];
                                    ySorted[l] = temp;
                                } else if(ySorted[k].position.y == ySorted[l].position.y
                                        && ySorted[k].position.x > ySorted[l].position.x) {
                                    NSLog(@"sdfkfjklslkf#@@@@@@@@@@@@@@Y same X sorting!");
                                    CCVertex temp = ySorted[k];
                                    ySorted[k] = ySorted[l];
                                    ySorted[l] = temp;
                                }
                            }
                        }

                        for (int k = 0; k < 4; ++k) {
                            for (int l = k+1; l < 4; ++l) {
                                if(xSorted[k].position.x > xSorted[l].position.x) {
                                    CCVertex temp = xSorted[k];
                                    xSorted[k] = xSorted[l];
                                    xSorted[l] = temp;
                                } else if(xSorted[k].position.x == xSorted[l].position.x
                                        && xSorted[k].position.y > xSorted[l].position.y) {
                                    NSLog(@"######################X same Y sorting!");
                                    CCVertex temp = xSorted[k];
                                    xSorted[k] = xSorted[l];
                                    xSorted[l] = temp;
                                }
                            }
                        }

                        if(ySorted[0].position.x < ySorted[1].position.x) {
                            _verts.bl = ySorted[0];
                            _verts.br = ySorted[1];
                        } else {
                            _verts.bl = ySorted[1];
                            _verts.br = ySorted[0];
                        }
                        if(ySorted[2].position.x < ySorted[3].position.x) {
                            _verts.tl = ySorted[2];
                            _verts.tr = ySorted[3];
                        } else {
                            _verts.tl = ySorted[3];
                            _verts.tr = ySorted[2];
                        }

                        [self renderStuff:renderer transform:transform slot:slot j:j vertexArray:vertexArray triangles:triangles];

                        if(xSorted[0].position.y < xSorted[1].position.y) {
                            _verts.bl = xSorted[0];
                            _verts.tl = xSorted[1];
                        } else {
                            _verts.bl = xSorted[1];
                            _verts.tl = xSorted[0];
                        }
                        if(xSorted[2].position.y < xSorted[3].position.y) {
                            _verts.br = xSorted[2];
                            _verts.tr = xSorted[3];
                        } else {
                            _verts.br = xSorted[3];
                            _verts.tr = xSorted[2];
                        }

                        [self renderStuff:renderer transform:transform slot:slot j:j vertexArray:vertexArray triangles:triangles];
                        */
                    }
                }
			}
		}
	}
    isDone = YES;
	[_drawNode clear];
	if (_debugSlots) {
		// Slots.
		CGPoint points[4];
		for (int i = 0, n = _skeleton->slotsCount; i < n; i++) {
			spSlot* slot = _skeleton->drawOrder[i];
			if (!slot->attachment || slot->attachment->type != SP_ATTACHMENT_REGION) continue;
			spRegionAttachment* attachment = (spRegionAttachment*)slot->attachment;
			spRegionAttachment_computeWorldVertices(attachment, slot->bone, _worldVertices);
			points[0] = ccp(_worldVertices[0], _worldVertices[1]);
			points[1] = ccp(_worldVertices[2], _worldVertices[3]);
			points[2] = ccp(_worldVertices[4], _worldVertices[5]);
			points[3] = ccp(_worldVertices[6], _worldVertices[7]);
			[_drawNode drawPolyWithVerts:points count:4 fillColor:[CCColor clearColor] borderWidth:1 borderColor:[CCColor blueColor]];
		}
	}
	if (_debugBones) {
		// Bone lengths.
		for (int i = 0, n = _skeleton->bonesCount; i < n; i++) {
			spBone *bone = _skeleton->bones[i];
			float x = bone->data->length * bone->m00 + bone->worldX;
			float y = bone->data->length * bone->m10 + bone->worldY;
			[_drawNode drawSegmentFrom:ccp(bone->worldX, bone->worldY) to: ccp(x, y)radius:2 color:[CCColor redColor]];
		}
		
		// Bone origins.
		for (int i = 0, n = _skeleton->bonesCount; i < n; i++) {
			spBone *bone = _skeleton->bones[i];
			[_drawNode drawDot:ccp(bone->worldX, bone->worldY) radius:4 color:[CCColor greenColor]];
			if (i == 0) [_drawNode drawDot:ccp(bone->worldX, bone->worldY) radius:4 color:[CCColor blueColor]];
		}
	}
}

- (void)renderCyclic:(CCRenderer *)renderer transform:(union _GLKMatrix4 const *)transform triangles:(int const *)triangles slot:(spSlot *)slot vertexArray:(CCVertex[])vertexArray j:(int)j v1:(CCVertex *)v1 v2:(CCVertex *)v2 v3:(CCVertex *)v3 v4:(CCVertex *)v4 {
//    _verts.bl = (*v1);
//    _verts.tl = (*v2);
//    _verts.tr = (*v3);
//    _verts.br = (*v4);
//
//    [self renderStuff:renderer transform:transform slot:slot j:j vertexArray:vertexArray triangles:triangles];

//    _verts.bl = (*v4);
//    _verts.tl = (*v1);
//    _verts.tr = (*v2);
//    _verts.br = (*v3);
//
//    [self renderStuff:renderer transform:transform slot:slot j:j vertexArray:vertexArray triangles:triangles];
//
//    _verts.bl = (*v3);
//    _verts.tl = (*v4);
//    _verts.tr = (*v1);
//    _verts.br = (*v2);
//
//    [self renderStuff:renderer transform:transform slot:slot j:j vertexArray:vertexArray triangles:triangles];
//
    _verts.bl = (*v2);
    _verts.tl = (*v3);
    _verts.tr = (*v4);
    _verts.br = (*v1);

    [self renderStuff:renderer transform:transform slot:slot j:j vertexArray:vertexArray triangles:triangles];
}

- (void)renderBL:(CCRenderer *)renderer transform:(union _GLKMatrix4 const *)transform triangles:(int const *)triangles slot:(spSlot *)slot vertexArray:(CCVertex[])vertexArray j:(int)j v1:(CCVertex *)v1 v2:(CCVertex *)v2 v3:(CCVertex *)v3 v4:(CCVertex *)v4 {
    _verts.bl = (*v4);
    _verts.tl = (*v1);
    _verts.tr = (*v2);
    _verts.br = (*v3);

    [self renderStuff:renderer transform:transform slot:slot j:j vertexArray:vertexArray triangles:triangles];
}

- (void)renderTR:(CCRenderer *)renderer transform:(union _GLKMatrix4 const *)transform triangles:(int const *)triangles slot:(spSlot *)slot vertexArray:(CCVertex[])vertexArray j:(int)j v1:(CCVertex *)v1 v2:(CCVertex *)v2 v3:(CCVertex *)v3 v4:(CCVertex *)v4 {
    _verts.tr = (*v4);
    _verts.br = (*v1);
    _verts.bl = (*v2);
    _verts.tl = (*v3);

    [self renderStuff:renderer transform:transform slot:slot j:j vertexArray:vertexArray triangles:triangles];
}

- (void)renderTL:(CCRenderer *)renderer transform:(union _GLKMatrix4 const *)transform triangles:(int const *)triangles slot:(spSlot *)slot vertexArray:(CCVertex[])vertexArray j:(int)j v1:(CCVertex *)v1 v2:(CCVertex *)v2 v3:(CCVertex *)v3 v4:(CCVertex *)v4 {
    _verts.tl = (*v4);
    _verts.tr = (*v1);
    _verts.br = (*v2);
    _verts.bl = (*v3);

    [self renderStuff:renderer transform:transform slot:slot j:j vertexArray:vertexArray triangles:triangles];
}

- (void)renderBR:(CCRenderer *)renderer transform:(union _GLKMatrix4 const *)transform triangles:(int const *)triangles slot:(spSlot *)slot vertexArray:(CCVertex[])vertexArray j:(int)j v1:(CCVertex *)v1 v2:(CCVertex *)v2 v3:(CCVertex *)v3 v4:(CCVertex *)v4 {
    _verts.br = (*v4);
    _verts.bl = (*v1);
    _verts.tl = (*v2);
    _verts.tr = (*v3);

    [self renderStuff:renderer transform:transform slot:slot j:j vertexArray:vertexArray triangles:triangles];
}

- (void)renderStuff:(CCRenderer *)renderer transform:(union _GLKMatrix4 const *)transform slot:(spSlot *)slot j:(int)j vertexArray:(CCVertex[])array triangles:(int const *)triangles {

    if(NO && !isDone) {
                            NSLog(@"Slot->Attachment %s, TriangleNumber: %d", slot->attachment->name, j);
                            NSLog(@"BL: (%f, %f), BR: (%f, %f), TR: (%f, %f), TL: (%f, %f)", _verts.bl.position.x, _verts.bl.position.y
                                    , _verts.br.position.x, _verts.br.position.y
                                    , _verts.tr.position.x, _verts.tr.position.y
                                    , _verts.tl.position.x, _verts.tl.position.y
                            );
                            NSLog(@"V1: (%f, %f), V2: (%f, %f), V3: (%f, %f)",
                                    array[triangles[j]].position.x, array[triangles[j]].position.y,
                                    array[triangles[j+1]].position.x, array[triangles[j+1]].position.y,
                                    array[triangles[j+2]].position.x, array[triangles[j+2]].position.y
                            );
                        }

    _effectRenderer.contentSize = self.boundingBox.size;

    CCEffectPrepareResult prepResult = [self.effect prepareForRenderingWithSprite:self];
    NSAssert(prepResult.status == CCEffectPrepareSuccess, @"Effect preparation failed.");

    if (prepResult.changes & CCEffectPrepareUniformsChanged)
    {
        // Preparing an effect for rendering can modify its uniforms
        // dictionary which means we need to reinitialize our copy of the
        // uniforms.
        [self updateShaderUniformsFromEffect];
    }

//    [_effectRenderer freeAllRenderTargets];
//    CCEffectRenderPass *renderPass = [self.effect renderPassAtIndex:0];
//    renderPass.debugLabel = @"CCEffectRenderer composite pass";
//    renderPass.shader = [CCEffectRenderer sharedCopyShader];
//    renderPass.beginBlocks = @[[[CCEffectRenderPassBeginBlockContext alloc] initWithBlock:^(CCEffectRenderPass *pass, CCEffectRenderPassInputs *passInputs){
//
//        passInputs.shaderUniforms[CCShaderUniformMainTexture] = passInputs.previousPassTexture;
//        passInputs.shaderUniforms[CCShaderUniformPreviousPassTexture] = passInputs.previousPassTexture;
//    }]];


//    CCEffectTexCoordFunc tc1 = selectTexCoordFunc(renderPass.texCoord1Mapping, CCEffectTexCoordSource1, fromIntermediate, padMainTexCoords);
//    CCEffectTexCoordFunc tc2 = selectTexCoordFunc(renderPass.texCoord2Mapping, CCEffectTexCoordSource2, fromIntermediate, padMainTexCoords);

//    CCSpriteVertexes paddedVerts; //= padVertices(sprite.vertexes, effect.padding, tc1, tc2);
//    paddedVerts = _verts;
////    if(isnan(paddedVerts.bl.texCoord1.x) || isnan(paddedVerts.bl.texCoord1.y)) {
////        paddedVerts = (*sprite.vertexes);
////    }
//    CCEffectRenderPassInputs *renderPassInputs = [[CCEffectRenderPassInputs alloc] init];
//    renderPassInputs.renderPassId = 0;
//    renderPassInputs.previousPassTexture = self.texture;
//    renderPassInputs.renderer = renderer;
//    renderPassInputs.sprite = self;
//    [renderPassInputs setVertsWorkAround:&paddedVerts];
//
//    renderPassInputs.texCoord1Center = GLKVector2Make((self.vertexes->tr.texCoord1.s + self.vertexes->bl.texCoord1.s) * 0.5f, (self.vertexes->tr.texCoord1.t + self.vertexes->bl.texCoord1.t) * 0.5f);
//    renderPassInputs.texCoord1Extents = GLKVector2Make(fabsf(self.vertexes->tr.texCoord1.s - self.vertexes->bl.texCoord1.s) * 0.5f, fabsf(self.vertexes->tr.texCoord1.t - self.vertexes->bl.texCoord1.t) * 0.5f);
//    renderPassInputs.texCoord2Center = renderPassInputs.texCoord1Center; //= GLKVector2Make((self.vertexes->tr.texCoord2.s + self.vertexes->bl.texCoord2.s) * 0.5f, (self.vertexes->tr.texCoord2.t + self.vertexes->bl.texCoord2.t) * 0.5f);
//    renderPassInputs.texCoord2Extents = renderPassInputs.texCoord1Extents; //= GLKVector2Make(fabsf(self.vertexes->tr.texCoord2.s - self.vertexes->bl.texCoord2.s) * 0.5f, fabsf(self.vertexes->tr.texCoord2.t - self.vertexes->bl.texCoord2.t) * 0.5f);
//
//    renderPassInputs.needsClear = YES;
//    renderPassInputs.shaderUniforms = _shaderUniforms;
////    CCEffectRenderTarget *rt = nil;
//
//    [renderer pushGroup];
//    renderPassInputs.transform = *transform;
//    renderPassInputs.ndcToNodeLocal = GLKMatrix4Invert(*transform, nil);
//
//    [renderPass begin:renderPassInputs];
//    [renderPass update:renderPassInputs];

    [_effectRenderer drawSprite:self
                     withEffect:self.effect uniforms:self.shaderUniforms
                       renderer:renderer
                      transform:transform];
}

- (CCVertex)buildV4:(CCVertex)v1 v2:(CCVertex)v2 v3:(CCVertex)v3 {
    CCVertex result;
    CGPoint v1Point = ccp(v1.position.x, v1.position.y);
    CGPoint v2Point = ccp(v2.position.x, v2.position.y);
    CGPoint midPoint = ccpMidpoint(v1Point, v2Point);
    CGPoint v1TPoint = ccp(v1.texCoord1.x, v1.texCoord1.y);
    CGPoint v2TPoint = ccp(v2.texCoord1.x, v2.texCoord1.y);
    CGPoint midTPoint = ccpMidpoint(v1TPoint, v2TPoint);

    result.position = GLKVector4Make(v3.position.x
            + (midPoint.x - v3.position.x) * 2,
            v3.position.y + (midPoint.y - v3.position.y) * 2, 0.0, 1.0);

    result.color = v1.color;
    result.texCoord1 = GLKVector2Make(v3.texCoord1.x + (midTPoint.x - v3.texCoord1.x) * 2,
            v3.texCoord1.y + (midTPoint.y - v3.texCoord1.y) * 2);
    result.texCoord2 = result.texCoord1;
    return result;
}

- (CCVertex)buildMinV4:(CCVertex)v1 v2:(CCVertex)v2 v3:(CCVertex)v3 {
    CCVertex result;
    result.position = GLKVector4Make(
            MIN(v1.position.x,v2.position.x),
            MIN(v1.position.y,v2.position.y),
            0.0, 1.0);

    result.color = v1.color;
    result.texCoord1 = GLKVector2Make(
            MIN(v1.texCoord1.x,v2.texCoord1.x),
            MIN(v1.texCoord1.y,v2.texCoord1.y)
    );
    result.texCoord2 = result.texCoord1;
    return result;
}

- (CCVertex)buildMaxV4:(CCVertex)v1 v2:(CCVertex)v2 v3:(CCVertex)v3 {
    CCVertex result;
    result.position = GLKVector4Make(
            MAX(v1.position.x,v2.position.x),
            MAX(v1.position.y,v2.position.y),
            0.0, 1.0);

    result.color = v1.color;
    result.texCoord1 = GLKVector2Make(
            MAX(v1.texCoord1.x,v2.texCoord1.x),
            MAX(v1.texCoord1.y,v2.texCoord1.y)
    );
    result.texCoord2 = result.texCoord1;
    return result;
}

- (CCVertex)buildMinMaxV4:(CCVertex)v1 v2:(CCVertex)v2 v3:(CCVertex)v3 {
    CCVertex result;
    result.position = GLKVector4Make(
            MIN(v1.position.x,v2.position.x),
            MAX(v1.position.y,v2.position.y),
            0.0, 1.0);

    result.color = v1.color;
    result.texCoord1 = GLKVector2Make(
            MIN(v1.texCoord1.x,v2.texCoord1.x),
            MAX(v1.texCoord1.y,v2.texCoord1.y)
    );
    result.texCoord2 = result.texCoord1;
    return result;
}

- (CCVertex)buildMaxMinV4:(CCVertex)v1 v2:(CCVertex)v2 v3:(CCVertex)v3 {
    CCVertex result;
    result.position = GLKVector4Make(
            MAX(v1.position.x,v2.position.x),
            MIN(v1.position.y,v2.position.y),
            0.0, 1.0);

    result.color = v1.color;
    result.texCoord1 = GLKVector2Make(
            MAX(v1.texCoord1.x,v2.texCoord1.x),
            MIN(v1.texCoord1.y,v2.texCoord1.y)
    );
    result.texCoord2 = result.texCoord1;
    return result;
}


- (CCTexture*) getTextureForRegion:(spRegionAttachment*)attachment {

    return (CCTexture*)((spAtlasRegion*)attachment->rendererObject)->page->rendererObject;
}

- (CCTexture*) getTextureForMesh:(spMeshAttachment*)attachment {
	return (CCTexture*)((spAtlasRegion*)attachment->rendererObject)->page->rendererObject;
}

- (CCTexture*) getTextureForSkinnedMesh:(spSkinnedMeshAttachment*)attachment {
	return (CCTexture*)((spAtlasRegion*)attachment->rendererObject)->page->rendererObject;
}

- (CGRect) boundingBox {
	float minX = FLT_MAX, minY = FLT_MAX, maxX = FLT_MIN, maxY = FLT_MIN;
	float scaleX = self.scaleX, scaleY = self.scaleY;
	for (int i = 0; i < _skeleton->slotsCount; ++i) {
		spSlot* slot = _skeleton->slots[i];
		if (!slot->attachment) continue;
		int verticesCount;
		if (slot->attachment->type == SP_ATTACHMENT_REGION) {
			spRegionAttachment* attachment = (spRegionAttachment*)slot->attachment;
			spRegionAttachment_computeWorldVertices(attachment, slot->bone, _worldVertices);
			verticesCount = 8;
		} else if (slot->attachment->type == SP_ATTACHMENT_MESH) {
			spMeshAttachment* mesh = (spMeshAttachment*)slot->attachment;
			spMeshAttachment_computeWorldVertices(mesh, slot, _worldVertices);
			verticesCount = mesh->verticesCount;
		} else if (slot->attachment->type == SP_ATTACHMENT_SKINNED_MESH) {
			spSkinnedMeshAttachment* mesh = (spSkinnedMeshAttachment*)slot->attachment;
			spSkinnedMeshAttachment_computeWorldVertices(mesh, slot, _worldVertices);
			verticesCount = mesh->uvsCount;
		} else
			continue;
		for (int ii = 0; ii < verticesCount; ii += 2) {
			float x = _worldVertices[ii] * scaleX, y = _worldVertices[ii + 1] * scaleY;
			minX = fmin(minX, x);
			minY = fmin(minY, y);
			maxX = fmax(maxX, x);
			maxY = fmax(maxY, y);
		}
	}
	minX = self.position.x + minX;
	minY = self.position.y + minY;
	maxX = self.position.x + maxX;
	maxY = self.position.y + maxY;
	return CGRectMake(minX, minY, maxX - minX, maxY - minY);
}

// --- Convenience methods for Skeleton_* functions.

- (void) updateWorldTransform {
	spSkeleton_updateWorldTransform(_skeleton);
}

- (void) setToSetupPose {
	spSkeleton_setToSetupPose(_skeleton);
}
- (void) setBonesToSetupPose {
	spSkeleton_setBonesToSetupPose(_skeleton);
}
- (void) setSlotsToSetupPose {
	spSkeleton_setSlotsToSetupPose(_skeleton);
}

- (spBone*) findBone:(NSString*)boneName {
	return spSkeleton_findBone(_skeleton, [boneName UTF8String]);
}

- (spSlot*) findSlot:(NSString*)slotName {
	return spSkeleton_findSlot(_skeleton, [slotName UTF8String]);
}

- (bool) setSkin:(NSString*)skinName {
	return (bool)spSkeleton_setSkinByName(_skeleton, skinName ? [skinName UTF8String] : 0);
}

- (spAttachment*) getAttachment:(NSString*)slotName attachmentName:(NSString*)attachmentName {
	return spSkeleton_getAttachmentForSlotName(_skeleton, [slotName UTF8String], [attachmentName UTF8String]);
}
- (bool) setAttachment:(NSString*)slotName attachmentName:(NSString*)attachmentName {
	return (bool)spSkeleton_setAttachment(_skeleton, [slotName UTF8String], [attachmentName UTF8String]);
}

// --- CCBlendProtocol

- (void) setBlendFunc:(ccBlendFunc)func {
	self.blendFunc = func;
}

- (ccBlendFunc) blendFunc {
	return _blendFunc;
}

- (void) setOpacityModifyRGB:(BOOL)value {
	_premultipliedAlpha = value;
}

- (BOOL) doesOpacityModifyRGB {
	return _premultipliedAlpha;
}

@end
