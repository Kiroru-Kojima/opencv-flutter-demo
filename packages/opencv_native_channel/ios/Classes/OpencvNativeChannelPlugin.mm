#import "OpencvNativeChannelPlugin.h"

#import <UIKit/UIKit.h>
#import <opencv2/core.hpp>
#import <opencv2/imgproc.hpp>

@implementation OpencvNativeChannelPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel methodChannelWithName:@"opencv_native_channel"
                                                              binaryMessenger:[registrar messenger]];
  OpencvNativeChannelPlugin* instance = [[OpencvNativeChannelPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"getPlatformVersion" isEqualToString:call.method]) {
    result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
    return;
  }

  if ([@"cannyBgrToRgba" isEqualToString:call.method]) {
    NSDictionary* args = (NSDictionary*)call.arguments;
    FlutterStandardTypedData* bgrTyped = args[@"bgr"];
    NSNumber* widthNum = args[@"width"];
    NSNumber* heightNum = args[@"height"];
    NSNumber* t1Num = args[@"threshold1"];
    NSNumber* t2Num = args[@"threshold2"];
    NSNumber* apertureNum = args[@"apertureSize"] ?: @(3);
    NSNumber* l2Num = args[@"l2gradient"] ?: @(NO);

    if (bgrTyped == nil || widthNum == nil || heightNum == nil || t1Num == nil || t2Num == nil) {
      result([FlutterError errorWithCode:@"BAD_ARGS" message:@"Missing arguments" details:nil]);
      return;
    }

    const int width = widthNum.intValue;
    const int height = heightNum.intValue;
    const NSUInteger expected = (NSUInteger)width * (NSUInteger)height * 3u;
    const NSData* bgrData = bgrTyped.data;
    if (bgrData.length != expected) {
      result([FlutterError errorWithCode:@"BAD_ARGS"
                                 message:[NSString stringWithFormat:@"bgr length mismatch (expected=%lu actual=%lu)",
                                                                  (unsigned long)expected,
                                                                  (unsigned long)bgrData.length]
                                 details:nil]);
      return;
    }

    @try {
      cv::Mat src(height, width, CV_8UC3, (void*)bgrData.bytes);
      cv::Mat gray;
      cv::cvtColor(src, gray, cv::COLOR_BGR2GRAY);
      cv::Mat edges;
      cv::Canny(gray,
                edges,
                t1Num.doubleValue,
                t2Num.doubleValue,
                apertureNum.intValue,
                l2Num.boolValue);
      cv::Mat rgba;
      cv::cvtColor(edges, rgba, cv::COLOR_GRAY2RGBA);

      const size_t outLen = rgba.total() * rgba.elemSize();
      NSData* outData = [NSData dataWithBytes:rgba.data length:outLen];
      result([FlutterStandardTypedData typedDataWithBytes:outData]);
    } @catch (NSException* ex) {
      result([FlutterError errorWithCode:@"OPENCV_ERROR" message:ex.reason details:nil]);
    }
    return;
  }

  if ([@"cannyBgrToRgbaProfile" isEqualToString:call.method]) {
    NSDictionary* args = (NSDictionary*)call.arguments;
    FlutterStandardTypedData* bgrTyped = args[@"bgr"];
    NSNumber* widthNum = args[@"width"];
    NSNumber* heightNum = args[@"height"];
    NSNumber* t1Num = args[@"threshold1"];
    NSNumber* t2Num = args[@"threshold2"];
    NSNumber* apertureNum = args[@"apertureSize"] ?: @(3);
    NSNumber* l2Num = args[@"l2gradient"] ?: @(NO);

    if (bgrTyped == nil || widthNum == nil || heightNum == nil || t1Num == nil || t2Num == nil) {
      result([FlutterError errorWithCode:@"BAD_ARGS" message:@"Missing arguments" details:nil]);
      return;
    }

    const int width = widthNum.intValue;
    const int height = heightNum.intValue;
    const NSUInteger expected = (NSUInteger)width * (NSUInteger)height * 3u;
    const NSData* bgrData = bgrTyped.data;
    if (bgrData.length != expected) {
      result([FlutterError errorWithCode:@"BAD_ARGS"
                                 message:[NSString stringWithFormat:@"bgr length mismatch (expected=%lu actual=%lu)",
                                                                  (unsigned long)expected,
                                                                  (unsigned long)bgrData.length]
                                 details:nil]);
      return;
    }

    @try {
      const CFAbsoluteTime t0 = CFAbsoluteTimeGetCurrent();
      cv::Mat src(height, width, CV_8UC3, (void*)bgrData.bytes);
      const CFAbsoluteTime t1 = CFAbsoluteTimeGetCurrent();
      cv::Mat gray;
      cv::cvtColor(src, gray, cv::COLOR_BGR2GRAY);
      const CFAbsoluteTime t2 = CFAbsoluteTimeGetCurrent();
      cv::Mat edges;
      cv::Canny(gray,
                edges,
                t1Num.doubleValue,
                t2Num.doubleValue,
                apertureNum.intValue,
                l2Num.boolValue);
      const CFAbsoluteTime t3 = CFAbsoluteTimeGetCurrent();
      cv::Mat rgba;
      cv::cvtColor(edges, rgba, cv::COLOR_GRAY2RGBA);
      const CFAbsoluteTime t4 = CFAbsoluteTimeGetCurrent();

      const size_t outLen = rgba.total() * rgba.elemSize();
      NSData* outData = [NSData dataWithBytes:rgba.data length:outLen];
      const CFAbsoluteTime t5 = CFAbsoluteTimeGetCurrent();

      int (^toUs)(CFAbsoluteTime) = ^int(CFAbsoluteTime seconds) {
        return (int)llround(seconds * 1000.0 * 1000.0);
      };

      NSDictionary* stages = @{
        @"matWrapUs" : @(toUs(t1 - t0)),
        @"cvtColorGrayUs" : @(toUs(t2 - t1)),
        @"cannyUs" : @(toUs(t3 - t2)),
        @"cvtColorRgbaUs" : @(toUs(t4 - t3)),
        @"copyOutUs" : @(toUs(t5 - t4)),
      };

      NSDictionary* payload = @{
        @"rgba" : [FlutterStandardTypedData typedDataWithBytes:outData],
        @"nativeTotalUs" : @(toUs(t5 - t0)),
        @"stagesUs" : stages,
      };
      result(payload);
    } @catch (NSException* ex) {
      result([FlutterError errorWithCode:@"OPENCV_ERROR" message:ex.reason details:nil]);
    }
    return;
  }

  result(FlutterMethodNotImplemented);
}

@end
