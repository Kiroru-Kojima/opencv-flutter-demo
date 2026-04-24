#import "OpencvNativeChannelPlugin.h"

#import <UIKit/UIKit.h>
#import <opencv2/core.hpp>
#import <opencv2/imgproc.hpp>
#import <opencv2/videoio.hpp>

#include <sstream>

static NSString* _ExtractOpenCvVideoIoBuildInfo() {
  try {
    const std::string info = cv::getBuildInformation();
    std::istringstream iss(info);
    std::string line;
    bool inSection = false;
    std::string out;
    int lines = 0;

    while (std::getline(iss, line)) {
      if (!inSection) {
        if (line.find("Video I/O:") != std::string::npos) {
          inSection = true;
          out += line;
          out += "\n";
          continue;
        }
      } else {
        if (line.empty()) break;
        out += line;
        out += "\n";
        lines++;
        if (lines >= 20) break;
      }
    }

    if (out.empty()) return @"(Video I/O section not found in cv::getBuildInformation())";
    return [NSString stringWithUTF8String:out.c_str()];
  } catch (...) {
    return @"(Failed to read cv::getBuildInformation())";
  }
}

static NSString* _DescribeFileAtPath(NSString* path) {
  if (path == nil) return @"(path=nil)";
  NSString* resolved = [[path stringByStandardizingPath] stringByResolvingSymlinksInPath];

  NSFileManager* fm = [NSFileManager defaultManager];
  BOOL isDir = NO;
  const BOOL exists = [fm fileExistsAtPath:path isDirectory:&isDir];
  const BOOL existsResolved = [fm fileExistsAtPath:resolved isDirectory:&isDir];

  unsigned long long size = 0;
  unsigned long long sizeResolved = 0;
  if (exists) {
    NSDictionary* attrs = [fm attributesOfItemAtPath:path error:nil];
    size = [attrs fileSize];
  }
  if (existsResolved) {
    NSDictionary* attrs2 = [fm attributesOfItemAtPath:resolved error:nil];
    sizeResolved = [attrs2 fileSize];
  }

  NSData* head = nil;
  if (exists && size > 0) {
    NSFileHandle* fh = [NSFileHandle fileHandleForReadingAtPath:path];
    if (fh != nil) {
      @try {
        head = [fh readDataOfLength:16];
      } @catch (NSException* _) {
        head = nil;
      }
      @try {
        [fh closeFile];
      } @catch (NSException* _) {
      }
    }
  }

  NSMutableString* s = [NSMutableString string];
  [s appendFormat:@"path=%@\n", path];
  [s appendFormat:@"resolved=%@\n", resolved];
  [s appendFormat:@"exists=%@ size=%llu\n", exists ? @"YES" : @"NO", size];
  [s appendFormat:@"exists(resolved)=%@ size(resolved)=%llu\n", existsResolved ? @"YES" : @"NO", sizeResolved];
  if (head != nil && head.length > 0) {
    const unsigned char* b = (const unsigned char*)head.bytes;
    NSMutableString* hex = [NSMutableString string];
    for (NSUInteger i = 0; i < head.length; i++) {
      [hex appendFormat:@"%02X", b[i]];
      if (i + 1 < head.length) [hex appendString:@" "];
    }
    [s appendFormat:@"head16=%@\n", hex];
  }
  return s;
}

@interface OpencvNativeChannelPlugin () {
  cv::Mat _fgBg32f;
  bool _fgHasBg;
  cv::Mat _fgKernel;
}
@end

@implementation OpencvNativeChannelPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel methodChannelWithName:@"opencv_native_channel"
                                                              binaryMessenger:[registrar messenger]];
  OpencvNativeChannelPlugin* instance = [[OpencvNativeChannelPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _fgHasBg = false;
  }
  return self;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"getPlatformVersion" isEqualToString:call.method]) {
    result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
    return;
  }

  if ([@"fgExtractReset" isEqualToString:call.method]) {
    _fgHasBg = false;
    _fgBg32f.release();
    result(nil);
    return;
  }

  if ([@"fgExtractBgrProfile" isEqualToString:call.method]) {
    NSDictionary* args = (NSDictionary*)call.arguments;
    FlutterStandardTypedData* bgrTyped = args[@"bgr"];
    NSNumber* widthNum = args[@"width"];
    NSNumber* heightNum = args[@"height"];
    NSNumber* alphaNum = args[@"alpha"] ?: @(0.05);
    NSNumber* threshNum = args[@"threshold"] ?: @(25.0);
    NSNumber* morphIterNum = args[@"morphIterations"] ?: @(1);

    if (bgrTyped == nil || widthNum == nil || heightNum == nil) {
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
      if (_fgKernel.empty()) {
        _fgKernel = cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(3, 3));
      }

      const CFAbsoluteTime t0 = CFAbsoluteTimeGetCurrent();
      cv::Mat src(height, width, CV_8UC3, (void*)bgrData.bytes);
      const CFAbsoluteTime t1 = CFAbsoluteTimeGetCurrent();

      cv::Mat gray;
      cv::cvtColor(src, gray, cv::COLOR_BGR2GRAY);
      const CFAbsoluteTime t2 = CFAbsoluteTimeGetCurrent();

      cv::Mat gray32f;
      gray.convertTo(gray32f, CV_32FC1);
      if (!_fgHasBg || _fgBg32f.rows != height || _fgBg32f.cols != width) {
        _fgBg32f.release();
        _fgBg32f = gray32f.clone();
        _fgHasBg = true;
      } else {
        cv::accumulateWeighted(gray32f, _fgBg32f, alphaNum.doubleValue);
      }
      const CFAbsoluteTime t3 = CFAbsoluteTimeGetCurrent();

      cv::Mat bg8u;
      cv::convertScaleAbs(_fgBg32f, bg8u);
      cv::Mat diff;
      cv::absdiff(gray, bg8u, diff);
      cv::Mat mask;
      cv::threshold(diff, mask, threshNum.doubleValue, 255.0, cv::THRESH_BINARY);
      const CFAbsoluteTime t4 = CFAbsoluteTimeGetCurrent();

      cv::morphologyEx(mask,
                       mask,
                       cv::MORPH_OPEN,
                       _fgKernel,
                       cv::Point(-1, -1),
                       morphIterNum.intValue);
      const CFAbsoluteTime t5 = CFAbsoluteTimeGetCurrent();

      const int fgCount = cv::countNonZero(mask);
      const CFAbsoluteTime t6 = CFAbsoluteTimeGetCurrent();

      int (^toUs)(CFAbsoluteTime) = ^int(CFAbsoluteTime seconds) {
        return (int)llround(seconds * 1000.0 * 1000.0);
      };

      NSDictionary* stages = @{
        @"matWrapUs" : @(toUs(t1 - t0)),
        @"cvtColorGrayUs" : @(toUs(t2 - t1)),
        @"bgUpdateUs" : @(toUs(t3 - t2)),
        @"diffThresholdUs" : @(toUs(t4 - t3)),
        @"morphUs" : @(toUs(t5 - t4)),
        @"countUs" : @(toUs(t6 - t5)),
      };

      NSDictionary* payload = @{
        @"fgCount" : @(fgCount),
        @"nativeTotalUs" : @(toUs(t6 - t0)),
        @"stagesUs" : stages,
      };
      result(payload);
    } @catch (NSException* ex) {
      result([FlutterError errorWithCode:@"OPENCV_ERROR" message:ex.reason details:nil]);
    }
    return;
  }

  if ([@"benchmarkMp4FgExtractProfile" isEqualToString:call.method]) {
    NSDictionary* args = (NSDictionary*)call.arguments;
    NSString* path = args[@"path"];
    NSNumber* warmupNum = args[@"warmup"] ?: @(10);
    NSNumber* iterationsNum = args[@"iterations"] ?: @(100);
    NSNumber* alphaNum = args[@"alpha"] ?: @(0.05);
    NSNumber* threshNum = args[@"threshold"] ?: @(25.0);
    NSNumber* morphIterNum = args[@"morphIterations"] ?: @(1);

    if (path == nil || path.length == 0) {
      result([FlutterError errorWithCode:@"BAD_ARGS" message:@"Missing path" details:nil]);
      return;
    }

    @try {
      cv::Mat kernel = cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(3, 3));
      cv::Mat bg32f;
      bool hasBg = false;

      const int warmup = warmupNum.intValue;
      const int iterations = iterationsNum.intValue;

      NSMutableArray<NSNumber*>* totalUs = [NSMutableArray arrayWithCapacity:MAX(0, iterations)];
      NSMutableArray<NSNumber*>* decodeUs = [NSMutableArray arrayWithCapacity:MAX(0, iterations)];
      NSMutableArray<NSNumber*>* processUs = [NSMutableArray arrayWithCapacity:MAX(0, iterations)];
      NSNumber* lastFgCount = nil;

      int (^toUs)(CFAbsoluteTime) = ^int(CFAbsoluteTime seconds) {
        return (int)llround(seconds * 1000.0 * 1000.0);
      };

      auto processGray = [&](const cv::Mat& gray) -> int {
        cv::Mat gray32f;
        gray.convertTo(gray32f, CV_32FC1);

        if (!hasBg || bg32f.rows != gray.rows || bg32f.cols != gray.cols) {
          bg32f.release();
          bg32f = gray32f.clone();
          hasBg = true;
        } else {
          cv::accumulateWeighted(gray32f, bg32f, alphaNum.doubleValue);
        }

        cv::Mat bg8u;
        cv::convertScaleAbs(bg32f, bg8u);
        cv::Mat diff;
        cv::absdiff(gray, bg8u, diff);
        cv::Mat mask;
        cv::threshold(diff, mask, threshNum.doubleValue, 255.0, cv::THRESH_BINARY);
        cv::morphologyEx(mask,
                         mask,
                         cv::MORPH_OPEN,
                         kernel,
                         cv::Point(-1, -1),
                         morphIterNum.intValue);
        return cv::countNonZero(mask);
      };

	      auto openCap = [&](cv::VideoCapture& cap) -> bool {
	        NSString* p1 = path;
	        NSString* p2 = [[path stringByStandardizingPath] stringByResolvingSymlinksInPath];

	        NSArray<NSString*>* candidates = @[ p1, p2 ];
	        for (NSString* p in candidates) {
	          if (p == nil || p.length == 0) continue;
	          const std::string pu([p UTF8String]);
	          if (cap.open(pu, cv::CAP_AVFOUNDATION)) return true;
	          if (cap.open(pu, cv::CAP_ANY)) return true;

	          NSURL* fileUrl = [NSURL fileURLWithPath:p];
	          if (fileUrl != nil) {
	            const std::string urlAbs([[fileUrl absoluteString] UTF8String]);
	            const std::string urlPath([[fileUrl path] UTF8String]);
	            if (cap.open(urlAbs, cv::CAP_AVFOUNDATION)) return true;
	            if (cap.open(urlAbs, cv::CAP_ANY)) return true;
	            if (cap.open(urlPath, cv::CAP_AVFOUNDATION)) return true;
	            if (cap.open(urlPath, cv::CAP_ANY)) return true;
	          }
	        }
	        return false;
	      };

      cv::VideoCapture cap;
      if (!openCap(cap)) {
        NSMutableString* details = [NSMutableString string];
        [details appendString:_ExtractOpenCvVideoIoBuildInfo()];
        [details appendString:@"\n"];
        [details appendString:_DescribeFileAtPath(path)];

        result([FlutterError errorWithCode:@"VIDEOIO_OPEN"
                                   message:[NSString stringWithFormat:@"VideoCapture.open failed: %@", path]
                                   details:details]);
        return;
      }

	      auto rewind = [&]() -> bool {
	        if (cap.set(cv::CAP_PROP_POS_FRAMES, 0.0)) return true;
	        cap.release();
	        return openCap(cap);
	      };

	      cv::Mat frame;

	      // warmup
	      for (int i = 0; i < warmup; i++) {
	        bool ok = cap.grab();
	        if (!ok) ok = rewind() && cap.grab();
	        if (!ok) continue;
	        ok = cap.retrieve(frame);
	        if (!ok) continue;

	        cv::Mat gray;
	        if (frame.channels() == 4) {
	          cv::cvtColor(frame, gray, cv::COLOR_BGRA2GRAY);
	        } else if (frame.channels() == 3) {
	          cv::cvtColor(frame, gray, cv::COLOR_BGR2GRAY);
	        } else if (frame.channels() == 1) {
	          gray = frame;
	        } else {
	          continue;
	        }
	        (void)processGray(gray);
	      }

	      for (int i = 0; i < iterations; i++) {
	        const CFAbsoluteTime t0 = CFAbsoluteTimeGetCurrent();

	        const CFAbsoluteTime td0 = CFAbsoluteTimeGetCurrent();
	        bool ok = cap.grab();
	        if (!ok) ok = rewind() && cap.grab();
	        if (!ok) {
	          result([FlutterError errorWithCode:@"VIDEOIO_READ" message:@"VideoCapture.grab failed" details:nil]);
	          return;
	        }
	        ok = cap.retrieve(frame);
	        const CFAbsoluteTime td1 = CFAbsoluteTimeGetCurrent();
	        if (!ok) {
	          result([FlutterError errorWithCode:@"VIDEOIO_READ" message:@"VideoCapture.retrieve failed" details:nil]);
	          return;
	        }

	        const CFAbsoluteTime tp0 = CFAbsoluteTimeGetCurrent();
	        cv::Mat gray;
	        if (frame.channels() == 4) {
	          cv::cvtColor(frame, gray, cv::COLOR_BGRA2GRAY);
	        } else if (frame.channels() == 3) {
	          cv::cvtColor(frame, gray, cv::COLOR_BGR2GRAY);
	        } else if (frame.channels() == 1) {
	          gray = frame;
	        } else {
	          result([FlutterError errorWithCode:@"VIDEOIO_READ"
	                                     message:[NSString stringWithFormat:@"Unsupported frame channels=%d", frame.channels()]
	                                     details:nil]);
	          return;
	        }
	        const int fgCount = processGray(gray);
	        const CFAbsoluteTime tp1 = CFAbsoluteTimeGetCurrent();

        lastFgCount = @(fgCount);
        [totalUs addObject:@(toUs(tp1 - t0))];
        [decodeUs addObject:@(toUs(td1 - td0))];
        [processUs addObject:@(toUs(tp1 - tp0))];
      }

      NSDictionary* payload = @{
        @"totalUs" : totalUs,
        @"decodeUs" : decodeUs,
        @"processUs" : processUs,
        @"lastFgCount" : lastFgCount ?: [NSNull null],
      };
      result(payload);
    } @catch (NSException* ex) {
      result([FlutterError errorWithCode:@"OPENCV_ERROR" message:ex.reason details:nil]);
    }
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
