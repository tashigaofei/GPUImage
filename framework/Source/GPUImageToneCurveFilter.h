#import "GPUImage.h"

@interface GPUImageToneCurveFilter :GPUImageTwoInputFilter
{
    GPUImagePicture *_lightPicture;
    GLint brightnessUniform;
    GLint contrastUniform;
    GLint enableBlurUniform;
}
@property(readwrite, nonatomic, copy) NSArray *redControlPoints;
@property(readwrite, nonatomic, copy) NSArray *greenControlPoints;
@property(readwrite, nonatomic, copy) NSArray *blueControlPoints;
@property(readwrite, nonatomic, copy) NSArray *rgbCompositeControlPoints;
@property(readwrite, nonatomic) CGFloat brightness;
@property(readwrite, nonatomic) CGFloat contrast;

/** The radius of the circular area being excluded from the blur
 */
@property (readwrite, nonatomic) CGFloat excludeCircleRadius;
/** The center of the circular area being excluded from the blur
 */
@property (readwrite, nonatomic) CGPoint excludeCirclePoint;
/** The size of the area between the blurred portion and the clear circle
 */
@property (readwrite, nonatomic) CGFloat excludeBlurSize;
/** A multiplier for the size of the blur, ranging from 0.0 on up, with a default of 1.0
 */
@property (readwrite, nonatomic) CGFloat blurSize;
/** The aspect ratio of the image, used to adjust the circularity of the in-focus region. By default, this matches the image aspect ratio, but you can override this value.
 */
@property (readwrite, nonatomic) CGFloat aspectRatio;

@property (readwrite, nonatomic) int isEnableBlur;



// Initialization and teardown
- (id)initWithACV:(NSString*)curveFile;

// This lets you set all three red, green, and blue tone curves at once.
// NOTE: Deprecated this function because this effect can be accomplished
// using the rgbComposite channel rather then setting all 3 R, G, and B channels.
- (void)setRGBControlPoints:(NSArray *)points DEPRECATED_ATTRIBUTE;

- (void)setPointsWithACV:(NSString*)curveFile;

// Curve calculation
- (NSMutableArray *)getPreparedSplineCurve:(NSArray *)points;
- (NSMutableArray *)splineCurve:(NSArray *)points;
- (NSMutableArray *)secondDerivative:(NSArray *)cgPoints;
- (void)updateToneCurveTexture;
   
@end
