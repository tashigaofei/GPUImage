#import <Foundation/Foundation.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreMedia/CoreMedia.h>
#import "GLProgram.h"

#define GPUImageRotationSwapsWidthAndHeight(rotation) ((rotation) == kGPUImageRotateLeft || (rotation) == kGPUImageRotateRight || (rotation) == kGPUImageRotateRightFlipVertical || (rotation) == kGPUImageRotateLeftFlipHorizonal || (rotation) == kGPUImageRotateRightFlipHorizonal)

typedef enum { kGPUImageNoRotation = 0, kGPUImageOrientationDown, kGPUImageRotateLeft, kGPUImageRotateRight, kGPUImageFlipHorizonal,kGPUImageRotate180FlipHorizonal,kGPUImageRotateLeftFlipHorizonal, kGPUImageRotateRightFlipHorizonal, kGPUImageFlipVertical ,kGPUImageRotateRightFlipVertical, kGPUImageRotate180 } GPUImageRotationMode;

@interface GPUImageOpenGLESContext : NSObject

@property(readonly, retain, nonatomic) EAGLContext *context;
@property(readonly, nonatomic) dispatch_queue_t contextQueue;
@property(readwrite, retain, nonatomic) GLProgram *currentShaderProgram;

+ (GPUImageOpenGLESContext *)sharedImageProcessingOpenGLESContext;
+ (dispatch_queue_t)sharedOpenGLESQueue;
+ (void)useImageProcessingContext;
+ (void)setActiveShaderProgram:(GLProgram *)shaderProgram;
+ (GLint)maximumTextureSizeForThisDevice;
+ (GLint)maximumTextureUnitsForThisDevice;
+ (CGSize)sizeThatFitsWithinATextureForSize:(CGSize)inputSize;

- (void)presentBufferForDisplay;
- (GLProgram *)programForVertexShaderString:(NSString *)vertexShaderString fragmentShaderString:(NSString *)fragmentShaderString;

// Manage fast texture upload
+ (BOOL)supportsFastTextureUpload;
- (void)useSharegroup:(EAGLSharegroup *)sharegroup;

@end

@protocol GPUImageInput <NSObject>
- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex;
- (void)setInputTexture:(GLuint)newInputTexture atIndex:(NSInteger)textureIndex;
- (NSInteger)nextAvailableTextureIndex;
- (void)setInputSize:(CGSize)newSize atIndex:(NSInteger)textureIndex;
- (void)setInputRotation:(GPUImageRotationMode)newInputRotation atIndex:(NSInteger)textureIndex;
- (CGSize)maximumOutputSize;
- (void)endProcessing;
- (BOOL)shouldIgnoreUpdatesToThisTarget;
- (BOOL)enabled;
@end
