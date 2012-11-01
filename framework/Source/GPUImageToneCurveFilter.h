#import "GPUImage.h"

@interface GPUImageToneCurveFilter :GPUImageTwoInputFilter
{
    GPUImagePicture *_lightPicture;
//    GLint brightnessUniform;
    GLint contrastUniform;
}
@property(readwrite, nonatomic, copy) NSArray *redControlPoints;
@property(readwrite, nonatomic, copy) NSArray *greenControlPoints;
@property(readwrite, nonatomic, copy) NSArray *blueControlPoints;
@property(readwrite, nonatomic, copy) NSArray *rgbCompositeControlPoints;
//@property(readwrite, nonatomic) CGFloat brightness;
@property(readwrite, nonatomic) CGFloat contrast;

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

-(void) destroy;
@end
