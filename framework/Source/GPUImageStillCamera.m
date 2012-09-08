// 2448x3264 pixel image = 31,961,088 bytes for uncompressed RGBA

#import "GPUImageStillCamera.h"

void stillImageDataReleaseCallback(void *releaseRefCon, const void *baseAddress)
{
    free((void *)baseAddress);
}

void GPUImageCreateResizedSampleBuffer(CVPixelBufferRef cameraFrame, CGSize finalSize, CMSampleBufferRef *sampleBuffer)
{
    CGSize originalSize = CGSizeMake(CVPixelBufferGetWidth(cameraFrame), CVPixelBufferGetHeight(cameraFrame));

    CVPixelBufferLockBaseAddress(cameraFrame, 0);
    GLubyte *sourceImageBytes =  CVPixelBufferGetBaseAddress(cameraFrame);
    CGDataProviderRef dataProvider = CGDataProviderCreateWithData(NULL, sourceImageBytes, CVPixelBufferGetBytesPerRow(cameraFrame) * originalSize.height, NULL);
    CGColorSpaceRef genericRGBColorspace = CGColorSpaceCreateDeviceRGB();
    CGImageRef cgImageFromBytes = CGImageCreate((int)originalSize.width, (int)originalSize.height, 8, 32, CVPixelBufferGetBytesPerRow(cameraFrame), genericRGBColorspace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst, dataProvider, NULL, NO, kCGRenderingIntentDefault);
    
    GLubyte *imageData = (GLubyte *) calloc(1, (int)finalSize.width * (int)finalSize.height * 4);
    
    CGContextRef imageContext = CGBitmapContextCreate(imageData, (int)finalSize.width, (int)finalSize.height, 8, (int)finalSize.width * 4, genericRGBColorspace,  kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGContextDrawImage(imageContext, CGRectMake(0.0, 0.0, finalSize.width, finalSize.height), cgImageFromBytes);
    CGImageRelease(cgImageFromBytes);
    CGContextRelease(imageContext);
    CGColorSpaceRelease(genericRGBColorspace);
    CGDataProviderRelease(dataProvider);
    
    CVPixelBufferRef pixel_buffer = NULL;
    CVPixelBufferCreateWithBytes(kCFAllocatorDefault, finalSize.width, finalSize.height, kCVPixelFormatType_32BGRA, imageData, finalSize.width * 4, stillImageDataReleaseCallback, NULL, NULL, &pixel_buffer);
    CMVideoFormatDescriptionRef videoInfo = NULL;
    CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixel_buffer, &videoInfo);
    
    CMTime frameTime = CMTimeMake(1, 30);
    CMSampleTimingInfo timing = {frameTime, frameTime, kCMTimeInvalid};
    
    CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixel_buffer, YES, NULL, NULL, videoInfo, &timing, sampleBuffer);
    CFRelease(videoInfo);
    CVPixelBufferRelease(pixel_buffer);
}

@interface GPUImageStillCamera ()
{
    AVCaptureStillImageOutput *photoOutput;
}

@end

@implementation GPUImageStillCamera
@synthesize sampleBufferRef = _sampleBufferRef;

#pragma mark -
#pragma mark Initialization and teardown

-(void) setSampleBufferRef:(CMSampleBufferRef) buffer
{
    if (buffer) {
        CFRetain(buffer);
    }
//    CMSampleBufferCreateCopy(kCFAllocatorDefault,buffer, &_sampleBufferRef);
    
    if (_sampleBufferRef != NULL) {
        CFRelease(_sampleBufferRef);
        _sampleBufferRef = NULL;
    }
    _sampleBufferRef = buffer;
}

-(CMSampleBufferRef) sampleBufferRef
{
    if (CMSampleBufferIsValid(_sampleBufferRef)) {
        return _sampleBufferRef;
    }
    return NULL;
}

- (id)initWithSessionPreset:(NSString *)sessionPreset cameraPosition:(AVCaptureDevicePosition)cameraPosition;
{
    if (!(self = [super initWithSessionPreset:sessionPreset cameraPosition:cameraPosition]))
    {
		return nil;
    }
    
    [self.captureSession beginConfiguration];
    
    photoOutput = [[AVCaptureStillImageOutput alloc] init];
    [photoOutput setOutputSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    
    [self.captureSession addOutput:photoOutput];
    
    [self.captureSession commitConfiguration];
    
    return self;
}

- (id)init;
{
    if (!(self = [self initWithSessionPreset:AVCaptureSessionPresetHigh cameraPosition:AVCaptureDevicePositionBack]))
    {
		return nil;
    }
    return self;
}

- (void)removeInputsAndOutputs;
{
    [self.captureSession removeOutput:photoOutput];
    [super removeInputsAndOutputs];
}

#pragma mark -
#pragma mark Photography controls

- (void)capturePhotoAsSampleBufferWithCompletionHandler:(void (^)(CMSampleBufferRef imageSampleBuffer, NSError *error))block
{
    NSLog(@"If you want to use the method capturePhotoAsSampleBufferWithCompletionHandler:, you must comment out the line in GPUImageStillCamera.m in the method initWithSessionPreset:cameraPosition: which sets the CVPixelBufferPixelFormatTypeKey, as well as uncomment the rest of the method capturePhotoAsSampleBufferWithCompletionHandler:. However, if you do this you cannot use any of the photo capture methods to take a photo if you also supply a filter.");
    
    /*dispatch_semaphore_wait(frameRenderingSemaphore, DISPATCH_TIME_FOREVER);
    
    [photoOutput captureStillImageAsynchronouslyFromConnection:[[photoOutput connections] objectAtIndex:0] completionHandler:^(CMSampleBufferRef imageSampleBuffer, NSError *error) {
        block(imageSampleBuffer, error);
    }];*/
    
    return;
}

- (void)capturePhotoAsImageProcessedUpToFilter:(GPUImageOutput<GPUImageInput> *)finalFilterInChain withCompletionHandler:(void (^)(UIImage *processedImage, NSError *error))block;
{
    dispatch_semaphore_wait(frameRenderingSemaphore, DISPATCH_TIME_FOREVER);

    [photoOutput captureStillImageAsynchronouslyFromConnection:[[photoOutput connections] objectAtIndex:0] completionHandler:^(CMSampleBufferRef imageSampleBuffer, NSError *error) {

        // For now, resize photos to fix within the max texture size of the GPU
        CVImageBufferRef cameraFrame = CMSampleBufferGetImageBuffer(imageSampleBuffer);
        
        CGSize sizeOfPhoto = CGSizeMake(CVPixelBufferGetWidth(cameraFrame), CVPixelBufferGetHeight(cameraFrame));
        CGSize scaledImageSizeToFitOnGPU = [GPUImageOpenGLESContext sizeThatFitsWithinATextureForSize:sizeOfPhoto];
        if (!CGSizeEqualToSize(sizeOfPhoto, scaledImageSizeToFitOnGPU))
        {
            CMSampleBufferRef sampleBuffer;
            GPUImageCreateResizedSampleBuffer(cameraFrame, scaledImageSizeToFitOnGPU, &sampleBuffer);

            dispatch_semaphore_signal(frameRenderingSemaphore);
           [self captureOutput:photoOutput didOutputSampleBuffer:sampleBuffer fromConnection:[[photoOutput connections] objectAtIndex:0]];
            dispatch_semaphore_wait(frameRenderingSemaphore, DISPATCH_TIME_FOREVER);
            CFRelease(sampleBuffer);
        }
        else
        {
            // This is a workaround for the corrupt images that are sometimes returned when taking a photo with the front camera and using the iOS 5.0 texture caches
            AVCaptureDevicePosition currentCameraPosition = [[videoInput device] position];
            if ( (currentCameraPosition != AVCaptureDevicePositionFront) || (![GPUImageOpenGLESContext supportsFastTextureUpload]))
            {
                dispatch_semaphore_signal(frameRenderingSemaphore);
                [self captureOutput:photoOutput didOutputSampleBuffer:imageSampleBuffer fromConnection:[[photoOutput connections] objectAtIndex:0]];
                dispatch_semaphore_wait(frameRenderingSemaphore, DISPATCH_TIME_FOREVER);
            }
        }

        UIImage *filteredPhoto = [finalFilterInChain imageFromCurrentlyProcessedOutput];
        dispatch_semaphore_signal(frameRenderingSemaphore);
        
        block(filteredPhoto, error);        
    }];
    
    return;
}

- (void)capturePhotoAsJPEGProcessedUpToFilter:(GPUImageOutput<GPUImageInput> *)finalFilterInChain withCompletionHandler:(void (^)(NSData *processedJPEG, NSError *error))block;
{
//    reportAvailableMemoryForGPUImage(@"Before still image capture");
    dispatch_semaphore_wait(frameRenderingSemaphore, DISPATCH_TIME_FOREVER);

    [photoOutput captureStillImageAsynchronouslyFromConnection:[[photoOutput connections] objectAtIndex:0] completionHandler:^(CMSampleBufferRef imageSampleBuffer, NSError *error) {
//        reportAvailableMemoryForGPUImage(@"Before filter processing");

        // For now, resize photos to fix within the max texture size of the GPU
        CVImageBufferRef cameraFrame = CMSampleBufferGetImageBuffer(imageSampleBuffer);

        CGSize sizeOfPhoto = CGSizeMake(CVPixelBufferGetWidth(cameraFrame), CVPixelBufferGetHeight(cameraFrame));
        CGSize scaledImageSizeToFitOnGPU = [GPUImageOpenGLESContext sizeThatFitsWithinATextureForSize:sizeOfPhoto];
        if (!CGSizeEqualToSize(sizeOfPhoto, scaledImageSizeToFitOnGPU))
        {
            CMSampleBufferRef sampleBuffer;

            GPUImageCreateResizedSampleBuffer(cameraFrame, scaledImageSizeToFitOnGPU, &sampleBuffer);
            
            dispatch_semaphore_signal(frameRenderingSemaphore);
            [self captureOutput:photoOutput didOutputSampleBuffer:sampleBuffer fromConnection:[[photoOutput connections] objectAtIndex:0]];
            dispatch_semaphore_wait(frameRenderingSemaphore, DISPATCH_TIME_FOREVER);
            CFRelease(sampleBuffer);
        }
        else
        {
            // This is a workaround for the corrupt images that are sometimes returned when taking a photo with the front camera and using the iOS 5.0 texture caches
            AVCaptureDevicePosition currentCameraPosition = [[videoInput device] position];
            if ( (currentCameraPosition != AVCaptureDevicePositionFront) || (![GPUImageOpenGLESContext supportsFastTextureUpload]))
            {
                dispatch_semaphore_signal(frameRenderingSemaphore);
                [self captureOutput:photoOutput didOutputSampleBuffer:imageSampleBuffer fromConnection:[[photoOutput connections] objectAtIndex:0]];
                dispatch_semaphore_wait(frameRenderingSemaphore, DISPATCH_TIME_FOREVER);
           }
        }        

//        reportAvailableMemoryForGPUImage(@"After filter processing");
        
        __strong NSData *dataForJPEGFile = nil;
        @autoreleasepool {
            UIImage *filteredPhoto = [finalFilterInChain imageFromCurrentlyProcessedOutput];
            dispatch_semaphore_signal(frameRenderingSemaphore);
            
//            reportAvailableMemoryForGPUImage(@"After UIImage generation");

            dataForJPEGFile = UIImageJPEGRepresentation(filteredPhoto, 0.8);
//            reportAvailableMemoryForGPUImage(@"After JPEG generation");
        }

//        reportAvailableMemoryForGPUImage(@"After autorelease pool");

        block(dataForJPEGFile, error);        
    }];
    
    return;
}

- (void)capturePhotoAsPNGProcessedUpToFilter:(GPUImageOutput<GPUImageInput> *)finalFilterInChain withCompletionHandler:(void (^)(NSData *processedPNG, NSError *error))block;
{
    dispatch_semaphore_wait(frameRenderingSemaphore, DISPATCH_TIME_FOREVER);

    [photoOutput captureStillImageAsynchronouslyFromConnection:[[photoOutput connections] objectAtIndex:0] completionHandler:^(CMSampleBufferRef imageSampleBuffer, NSError *error) {
        
        // For now, resize photos to fix within the max texture size of the GPU
        CVImageBufferRef cameraFrame = CMSampleBufferGetImageBuffer(imageSampleBuffer);
        
        CGSize sizeOfPhoto = CGSizeMake(CVPixelBufferGetWidth(cameraFrame), CVPixelBufferGetHeight(cameraFrame));
        CGSize scaledImageSizeToFitOnGPU = [GPUImageOpenGLESContext sizeThatFitsWithinATextureForSize:sizeOfPhoto];
        if (!CGSizeEqualToSize(sizeOfPhoto, scaledImageSizeToFitOnGPU))
        {
            CMSampleBufferRef sampleBuffer;
            GPUImageCreateResizedSampleBuffer(cameraFrame, scaledImageSizeToFitOnGPU, &sampleBuffer);

            dispatch_semaphore_signal(frameRenderingSemaphore);
            [self captureOutput:photoOutput didOutputSampleBuffer:sampleBuffer fromConnection:[[photoOutput connections] objectAtIndex:0]];
            dispatch_semaphore_wait(frameRenderingSemaphore, DISPATCH_TIME_FOREVER);
            CFRelease(sampleBuffer);
        }
        else
        {
            // This is a workaround for the corrupt images that are sometimes returned when taking a photo with the front camera and using the iOS 5.0 texture caches
            AVCaptureDevicePosition currentCameraPosition = [[videoInput device] position];
            if ( (currentCameraPosition != AVCaptureDevicePositionFront) || (![GPUImageOpenGLESContext supportsFastTextureUpload]))
            {
                dispatch_semaphore_signal(frameRenderingSemaphore);
                [self captureOutput:photoOutput didOutputSampleBuffer:imageSampleBuffer fromConnection:[[photoOutput connections] objectAtIndex:0]];
                dispatch_semaphore_wait(frameRenderingSemaphore, DISPATCH_TIME_FOREVER);
            }
        }
        
        NSData *dataForPNGFile = nil;
        @autoreleasepool { 
            UIImage *filteredPhoto = [finalFilterInChain imageFromCurrentlyProcessedOutput];
            dispatch_semaphore_signal(frameRenderingSemaphore);
            dataForPNGFile = UIImagePNGRepresentation(filteredPhoto);
        }
        
        block(dataForPNGFile, error);        
    }];
    
    return;
}

- (void)captureSampleBufferWithCompletionHandler:(void (^)(CMSampleBufferRef imageSampleBuffer, NSError *error))block
{
//     reportAvailableMemoryForGPUImage(@"before filter processing");

    [photoOutput captureStillImageAsynchronouslyFromConnection:[[photoOutput connections] objectAtIndex:0] completionHandler: ^(CMSampleBufferRef imageDataSampleBuffer, NSError *error){
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(imageDataSampleBuffer);
        CMSampleBufferRef sampleBuffer = NULL;
        GPUImageCreateResizedSampleBuffer(imageBuffer, CGSizeMake(1152, 1536), &sampleBuffer);
        block(sampleBuffer, error);
        
    }];
}


-(UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer {
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer.
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    
    // Get the number of bytes per row for the pixel buffer.
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height.
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // Create a device-dependent RGB color space.
    static CGColorSpaceRef colorSpace = NULL;
    if (colorSpace == NULL) {
        colorSpace = CGColorSpaceCreateDeviceRGB();
        if (colorSpace == NULL) {
            // Handle the error appropriately.
            return nil;
        }
    }
    
    // Get the base address of the pixel buffer.
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    // Get the data size for contiguous planes of the pixel buffer.
    size_t bufferSize = CVPixelBufferGetDataSize(imageBuffer);
    
    // Create a Quartz direct-access data provider that uses data we supply.
    CGDataProviderRef dataProvider =
    CGDataProviderCreateWithData(NULL, baseAddress, bufferSize, NULL);
    // Create a bitmap image from data supplied by the data provider.
    CGImageRef cgImage =
    CGImageCreate(width, height, 8, 32, bytesPerRow,
                  colorSpace, kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little,
                  dataProvider, NULL, true, kCGRenderingIntentDefault);
    CGDataProviderRelease(dataProvider);
    
    // Create and return an image object to represent the Quartz image.
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    return image;
}

-(BOOL) isFocusSupport
{
    AVCaptureDevice *device =  videoInput.device;
    if (device) {
        if ([device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
            return YES;
        }
    }
    return NO;
}


@end
