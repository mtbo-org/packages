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

@implementation CameraSettingsTests

/// Expect that FPS, video and audio bitrate are passed to camera device and asset writer.
- (void)testSettings_shouldPassConfigurationToCameraDeviceAndWriter {
  XCTestExpectation *lockExpectation = [self expectationWithDescription:@"lockExpectation"];
  XCTestExpectation *unlockExpectation = [self expectationWithDescription:@"unlockExpectation"];
  XCTestExpectation *minFrameDurationExpectation =
      [self expectationWithDescription:@"minFrameDurationExpectation"];
  XCTestExpectation *maxFrameDurationExpectation =
      [self expectationWithDescription:@"maxFrameDurationExpectation"];
  XCTestExpectation *beginConfigurationExpectation =
      [self expectationWithDescription:@"beginConfigurationExpectation"];
  XCTestExpectation *commitConfigurationExpectation =
      [self expectationWithDescription:@"commitConfigurationExpectation"];

  dispatch_queue_t captureSessionQueue = dispatch_queue_create("testing", NULL);

  id deviceMock = [OCMockObject niceMockForClass:[AVCaptureDevice class]];

  OCMStub([deviceMock deviceWithUniqueID:[OCMArg any]]).andReturn(deviceMock);

  OCMStub([deviceMock lockForConfiguration:[OCMArg setTo:nil]])
      .andDo(^(NSInvocation *invocation) {
        [lockExpectation fulfill];
      })
      .andReturn(YES);
  OCMStub([deviceMock unlockForConfiguration]).andDo(^(NSInvocation *invocation) {
    [unlockExpectation fulfill];
  });
  OCMStub([deviceMock setActiveVideoMinFrameDuration:CMTimeMake(10, gTestFPS * 10)])
      .andDo(^(NSInvocation *invocation) {
        [minFrameDurationExpectation fulfill];
      });
  OCMStub([deviceMock setActiveVideoMaxFrameDuration:CMTimeMake(10, gTestFPS * 10)])
      .andDo(^(NSInvocation *invocation) {
        [maxFrameDurationExpectation fulfill];
      });

  OCMStub([deviceMock devices]).andReturn(@[ deviceMock ]);

  id inputMock = OCMClassMock([AVCaptureDeviceInput class]);
  OCMStub([inputMock deviceInputWithDevice:[OCMArg any] error:[OCMArg setTo:nil]])
      .andReturn(inputMock);

  id videoSessionMock = OCMClassMock([AVCaptureSession class]);
  OCMStub([videoSessionMock beginConfiguration]).andDo(^(NSInvocation *invocation) {
    [beginConfigurationExpectation fulfill];
  });
  OCMStub([videoSessionMock commitConfiguration]).andDo(^(NSInvocation *invocation) {
    [commitConfigurationExpectation fulfill];
  });

  OCMStub([videoSessionMock addInputWithNoConnections:[OCMArg any]]);  // no-op
  OCMStub([videoSessionMock canSetSessionPreset:[OCMArg any]]).andReturn(YES);

  id audioSessionMock = OCMClassMock([AVCaptureSession class]);
  OCMStub([audioSessionMock addInputWithNoConnections:[OCMArg any]]);  // no-op
  OCMStub([audioSessionMock canSetSessionPreset:[OCMArg any]]).andReturn(YES);

  id captureVideoDataOutputMock = [OCMockObject niceMockForClass:[AVCaptureVideoDataOutput class]];

  OCMStub([captureVideoDataOutputMock new]).andReturn(captureVideoDataOutputMock);

  OCMStub([captureVideoDataOutputMock
              recommendedVideoSettingsForAssetWriterWithOutputFileType:AVFileTypeMPEG4])
      .andReturn(@{});

  OCMStub([captureVideoDataOutputMock sampleBufferCallbackQueue]).andReturn(captureSessionQueue);

  NSError *error = nil;
  FLTCam *camera = [[FLTCam alloc] initWithCameraName:@"camera"
                                     resolutionPreset:@(gTestResolutionPreset)
                                                  fps:@(gTestFPS)
                                         videoBitrate:@(gTestVideoBitrate)
                                         audioBitrate:@(gTestAudioBitrate)
                                          enableAudio:gTestEnableAudio
                                          orientation:UIDeviceOrientationPortrait
                                  videoCaptureSession:videoSessionMock
                                  audioCaptureSession:audioSessionMock
                                  captureSessionQueue:captureSessionQueue
                                                error:&error];

  XCTAssertNotNil(camera, @"FLTCreateCamWithQueue should not be nil");
  XCTAssertNil(error, @"FLTCreateCamWithQueue should not return error: %@",
               error.localizedDescription);

  id writerMock = OCMClassMock([AVAssetWriter class]);
  OCMStub([writerMock alloc]).andReturn(writerMock);
  OCMStub([writerMock initWithURL:OCMOCK_ANY fileType:OCMOCK_ANY error:[OCMArg setTo:nil]])
      .andReturn(writerMock);
  __block AVAssetWriterStatus status = AVAssetWriterStatusUnknown;
  OCMStub([writerMock startWriting]).andDo(^(NSInvocation *invocation) {
    status = AVAssetWriterStatusWriting;
  });
  OCMStub([writerMock status]).andDo(^(NSInvocation *invocation) {
    [invocation setReturnValue:&status];
  });

  // Expect FPS configuration is passed to camera device.
  [self waitForExpectations:@[
    lockExpectation, beginConfigurationExpectation, minFrameDurationExpectation,
    maxFrameDurationExpectation, commitConfigurationExpectation, unlockExpectation
  ]
                    timeout:1
               enforceOrder:YES];

  id videoMock = OCMClassMock([AVAssetWriterInputPixelBufferAdaptor class]);
  OCMStub([videoMock assetWriterInputPixelBufferAdaptorWithAssetWriterInput:OCMOCK_ANY
                                                sourcePixelBufferAttributes:OCMOCK_ANY])
      .andReturn(videoMock);

  id writerInputMock = [OCMockObject niceMockForClass:[AVAssetWriterInput class]];

  // Expect audio bitrate is passed to writer.
  XCTestExpectation *audioSettingsExpectation =
      [self expectationWithDescription:@"audioSettingsExpectation"];

  OCMStub([writerInputMock assetWriterInputWithMediaType:AVMediaTypeAudio
                                          outputSettings:[OCMArg any]])
      .andDo(^(NSInvocation *invocation) {
        NSMutableDictionary *args;
        [invocation getArgument:&args atIndex:3];

        if ([args[AVEncoderBitRateKey] isEqual:@(gTestAudioBitrate)]) {
          [audioSettingsExpectation fulfill];
        }
      })
      .andReturn(writerInputMock);

  // Expect FPS and video bitrate are passed to writer.
  XCTestExpectation *videoSettingsExpectation =
      [self expectationWithDescription:@"videoSettingsExpectation"];

  OCMStub([writerInputMock assetWriterInputWithMediaType:AVMediaTypeVideo
                                          outputSettings:[OCMArg any]])
      .andDo(^(NSInvocation *invocation) {
        NSMutableDictionary *args;
        [invocation getArgument:&args atIndex:3];

        if ([args[AVVideoCompressionPropertiesKey][AVVideoAverageBitRateKey]
                isEqual:@(gTestVideoBitrate)] &&
            [args[AVVideoCompressionPropertiesKey][AVVideoExpectedSourceFrameRateKey]
                isEqual:@(gTestFPS)]) {
          [videoSettingsExpectation fulfill];
        }
      })
      .andReturn(writerInputMock);

  FLTThreadSafeFlutterResult *result =
      [[FLTThreadSafeFlutterResult alloc] initWithResult:^(id result){
      }];

  [camera startVideoRecordingWithResult:result];

  [self waitForExpectations:@[ audioSettingsExpectation, videoSettingsExpectation ] timeout:1];
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
