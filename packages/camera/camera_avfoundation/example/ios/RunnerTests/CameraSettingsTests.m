// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@import camera_avfoundation;
@import camera_avfoundation.Test;
@import XCTest;
@import AVFoundation;
#import <OCMock/OCMock.h>
#import "CameraTestUtils.h"
#import "MockFLTThreadSafeFlutterResult.h"

static const char *gTestResolutionPreset = "medium";
static const int gTestFPS = 15;
static const int gTestVideoBitrate = 200000;
static const int gTestAudioBitrate = 32000;
static const bool gTestEnableAudio = YES;

@interface PositiveNumberOnNilTests : XCTestCase
@end

/// Expect that optional positive numbers can be parsed
@implementation PositiveNumberOnNilTests

- (void)testPositiveOrNilShouldRejectNegativeIntNumber {
  NSError *error;
  NSNumber *parsed = [CameraPlugin positiveOrNil:@(-100) error:&error];
  XCTAssert(parsed == nil && error, "should reject negative int number");
}

- (void)testPositiveOrNilShouldRejectNegativeFloatingPointNumber {
  NSError *error;
  NSNumber *parsed = [CameraPlugin positiveOrNil:@(-3.7) error:&error];
  XCTAssert(parsed == nil && error, "should accept positive floating point number");
}

- (void)testNanShouldBeParsedAsNil {
  NSError *error;
  NSNumber *parsed = [CameraPlugin positiveOrNil:@(NAN) error:&error];
  XCTAssert(parsed == nil && error, "should reject NAN");
}

- (void)testPositiveOrNilShouldRejectNil {
  NSError *error;
  NSNumber *parsed = [CameraPlugin positiveOrNil:nil error:&error];
  XCTAssert(parsed == nil && !error, "should accept nil");
}

- (void)testPositiveOrNilShouldAcceptNull {
  NSError *error;
  NSNumber *parsed = [CameraPlugin positiveOrNil:[NSNull null] error:&error];
  XCTAssert(parsed == nil && !error, "should accept [NSNull null]");
}

- (void)testPositiveOrNilShouldAcceptPositiveFloatingPointNumber {
  NSError *error;
  NSNumber *parsed = [CameraPlugin positiveOrNil:@(3.7) error:&error];
  XCTAssert(parsed != nil && !error, "should accept positive floating point number");
}

- (void)testPositiveOrNilShouldAcceptPositiveDecimalNumber {
  NSError *error;
  NSNumber *parsed = [CameraPlugin positiveOrNil:@(5) error:&error];
  XCTAssert(parsed != nil && !error, "should parse positive int number");
}

@end

@interface CameraSettingsTests : XCTestCase
@end

@interface TestMediaSettingsProvider : FLTCamMediaSettingsProvider
@property(nonatomic, readonly) XCTestExpectation *lockExpectation;
@property(nonatomic, readonly) XCTestExpectation *unlockExpectation;
@property(nonatomic, readonly) XCTestExpectation *minFrameDurationExpectation;
@property(nonatomic, readonly) XCTestExpectation *maxFrameDurationExpectation;
@property(nonatomic, readonly) XCTestExpectation *beginConfigurationExpectation;
@property(nonatomic, readonly) XCTestExpectation *commitConfigurationExpectation;
@property(nonatomic, readonly) XCTestExpectation *audioSettingsExpectation;
@property(nonatomic, readonly) XCTestExpectation *videoSettingsExpectation;
@end

@implementation TestMediaSettingsProvider

- (instancetype)initWithTestCase:(XCTestCase *)test
                             fps:(nullable NSNumber *)fps
                    videoBitrate:(nullable NSNumber *)videoBitrate
                    audioBitrate:(nullable NSNumber *)audioBitrate
                     enableAudio:(BOOL)enableAudio {
  self = [self initWithFps:fps
              videoBitrate:videoBitrate
              audioBitrate:audioBitrate
               enableAudio:enableAudio];

  _lockExpectation = [test expectationWithDescription:@"lockExpectation"];
  _unlockExpectation = [test expectationWithDescription:@"unlockExpectation"];
  _minFrameDurationExpectation = [test expectationWithDescription:@"minFrameDurationExpectation"];
  _maxFrameDurationExpectation = [test expectationWithDescription:@"maxFrameDurationExpectation"];
  _beginConfigurationExpectation =
      [test expectationWithDescription:@"beginConfigurationExpectation"];
  _commitConfigurationExpectation =
      [test expectationWithDescription:@"commitConfigurationExpectation"];
  _audioSettingsExpectation = [test expectationWithDescription:@"audioSettingsExpectation"];
  _videoSettingsExpectation = [test expectationWithDescription:@"videoSettingsExpectation"];

  return self;
}

- (BOOL)lockDevice:(AVCaptureDevice *)captureDevice error:(NSError **)outError {
  [_lockExpectation fulfill];
  return YES;
}

- (void)unlockDevice:(AVCaptureDevice *)captureDevice {
  [_unlockExpectation fulfill];
}

- (void)beginConfigurationForSession:(AVCaptureSession *)videoCaptureSession {
  [_beginConfigurationExpectation fulfill];
}

- (void)commitConfigurationForSession:(AVCaptureSession *)videoCaptureSession {
  [_commitConfigurationExpectation fulfill];
}

- (void)setMinFrameDuration:(CMTime)duration onDevice:(AVCaptureDevice *)captureDevice {
  if (duration.value == 10 && duration.timescale == gTestFPS * 10) {
    [_minFrameDurationExpectation fulfill];
  }
}

- (void)setMaxFrameDuration:(CMTime)duration onDevice:(AVCaptureDevice *)captureDevice {
  if (duration.value == 10 && duration.timescale == gTestFPS * 10) {
    [_maxFrameDurationExpectation fulfill];
  }
}

- (AVAssetWriterInput *)assetWriterAudioInputWithOutputSettings:
    (nullable NSDictionary<NSString *, id> *)outputSettings {
  if ([outputSettings[AVEncoderBitRateKey] isEqual:@(gTestAudioBitrate)]) {
    [_audioSettingsExpectation fulfill];
  }

  return [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio
                                            outputSettings:outputSettings];
}

- (AVAssetWriterInput *)assetWriterVideoInputWithOutputSettings:
    (nullable NSDictionary<NSString *, id> *)outputSettings {
  if ([outputSettings[AVVideoCompressionPropertiesKey] isKindOfClass:NSMutableDictionary.class]) {
    NSDictionary *compressionProperties = outputSettings[AVVideoCompressionPropertiesKey];

    if ([compressionProperties[AVVideoAverageBitRateKey] isEqual:@(gTestVideoBitrate)] &&
        [compressionProperties[AVVideoExpectedSourceFrameRateKey] isEqual:@(gTestFPS)]) {
      [_videoSettingsExpectation fulfill];
    }
  }

  return [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                            outputSettings:outputSettings];
}

- (void)addInput:(AVAssetWriterInput *)writerInput toAssetWriter:(AVAssetWriter *)writer {
}

- (NSMutableDictionary *)recommendedVideoSettingsForOutput:(AVCaptureVideoDataOutput *)output {
  return [NSMutableDictionary new];
}

@end

@implementation CameraSettingsTests

/// Expect that FPS, video and audio bitrate are passed to camera device and asset writer.
- (void)testSettings_shouldPassConfigurationToCameraDeviceAndWriter {
  TestMediaSettingsProvider *injectedProvider =
      [[TestMediaSettingsProvider alloc] initWithTestCase:self
                                                      fps:@(gTestFPS)
                                             videoBitrate:@(gTestVideoBitrate)
                                             audioBitrate:@(gTestAudioBitrate)
                                              enableAudio:gTestEnableAudio];

  FLTCam *camera = FLTCreateCamWithCaptureSessionQueueAndProvider(
      dispatch_queue_create("test", NULL), injectedProvider);

  // Expect FPS configuration is passed to camera device.
  [self waitForExpectations:@[
    injectedProvider.lockExpectation, injectedProvider.beginConfigurationExpectation,
    injectedProvider.minFrameDurationExpectation, injectedProvider.maxFrameDurationExpectation,
    injectedProvider.commitConfigurationExpectation, injectedProvider.unlockExpectation
  ]
                    timeout:1
               enforceOrder:YES];

  FLTThreadSafeFlutterResult *result =
      [[FLTThreadSafeFlutterResult alloc] initWithResult:^(id result){
      }];

  [camera startVideoRecordingWithResult:result];

  [self waitForExpectations:@[
    injectedProvider.audioSettingsExpectation, injectedProvider.videoSettingsExpectation
  ]
                    timeout:1];
}

- (void)testSettings_ShouldBeSupportedByMethodCall {
  CameraPlugin *camera = [[CameraPlugin alloc] initWithRegistry:nil messenger:nil];

  XCTestExpectation *expectation = [self expectationWithDescription:@"Result finished"];

  // Set up mocks for initWithCameraName method
  id avCaptureDeviceInputMock = OCMClassMock([AVCaptureDeviceInput class]);
  OCMStub([avCaptureDeviceInputMock deviceInputWithDevice:[OCMArg any] error:[OCMArg anyObjectRef]])
      .andReturn([AVCaptureInput alloc]);

  id avCaptureSessionMock = OCMClassMock([AVCaptureSession class]);
  OCMStub([avCaptureSessionMock alloc]).andReturn(avCaptureSessionMock);
  OCMStub([avCaptureSessionMock canSetSessionPreset:[OCMArg any]]).andReturn(YES);

  MockFLTThreadSafeFlutterResult *resultObject =
      [[MockFLTThreadSafeFlutterResult alloc] initWithExpectation:expectation];

  // Set up method call
  FlutterMethodCall *call =
      [FlutterMethodCall methodCallWithMethodName:@"create"
                                        arguments:@{
                                          @"resolutionPreset" : @(gTestResolutionPreset),
                                          @"enableAudio" : @(gTestEnableAudio),
                                          @"fps" : @(gTestFPS),
                                          @"videoBitrate" : @(gTestVideoBitrate),
                                          @"audioBitrate" : @(gTestAudioBitrate)
                                        }];

  [camera createCameraOnSessionQueueWithCreateMethodCall:call result:resultObject];
  [self waitForExpectationsWithTimeout:1 handler:nil];

  // Verify the result
  NSDictionary *dictionaryResult = (NSDictionary *)resultObject.receivedResult;
  XCTAssertNotNil(dictionaryResult);
  XCTAssert([[dictionaryResult allKeys] containsObject:@"cameraId"]);
}

@end
