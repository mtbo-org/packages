// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@import camera_avfoundation;
@import camera_avfoundation.Test;
@import AVFoundation;
@import XCTest;
#import <OCMock/OCMock.h>
#import "CameraTestUtils.h"

/// Includes test cases related to sample buffer handling for FLTCam class.
@interface FLTCamSampleBufferTests : XCTestCase

@end

@implementation FLTCamSampleBufferTests

- (void)testSampleBufferCallbackQueueMustBeCaptureSessionQueue {
  dispatch_queue_t captureSessionQueue = dispatch_queue_create("testing", NULL);
  NSError *error = nil;
  FLTCam *cam = FLTCreateCamWithCaptureSessionQueueWithError(captureSessionQueue, &error);
  XCTAssertNotNil(cam, @"FLTCreateCamWithCaptureSessionQueue must not be nil, error: %@", error);
  XCTAssertNotNil(cam.captureVideoOutput.sampleBufferCallbackQueue,
                  @"sampleBufferCallbackQueue must not be nil, error: %@", error);
  if (error) {
    XCTAssertNil(error, @"FLTCreateCamWithCaptureSessionQueue error: %@", error.description);
  }
  XCTAssertEqual(captureSessionQueue, cam.captureVideoOutput.sampleBufferCallbackQueue,
                 @"Sample buffer callback queue must be the capture session queue.");
}

- (void)testCopyPixelBuffer {
  NSError *error = nil;
  FLTCam *cam = FLTCreateCamWithCaptureSessionQueue(dispatch_queue_create("test", NULL), &error);
  CMSampleBufferRef capturedSampleBuffer = FLTCreateTestSampleBuffer();
  CVPixelBufferRef capturedPixelBuffer = CMSampleBufferGetImageBuffer(capturedSampleBuffer);
  // Mimic sample buffer callback when captured a new video sample
  [cam captureOutput:cam.captureVideoOutput
      didOutputSampleBuffer:capturedSampleBuffer
             fromConnection:OCMClassMock([AVCaptureConnection class])];
  CVPixelBufferRef deliveriedPixelBuffer = [cam copyPixelBuffer];
  XCTAssertEqual(deliveriedPixelBuffer, capturedPixelBuffer,
                 @"FLTCam must deliver the latest captured pixel buffer to copyPixelBuffer API.");
  CFRelease(capturedSampleBuffer);
  CFRelease(deliveriedPixelBuffer);
}

- (void)testDidOutputSampleBufferIgnoreAudioSamplesBeforeVideoSamples {
  NSError *error = nil;
  FLTCam *cam = FLTCreateCamWithCaptureSessionQueue(dispatch_queue_create("testing", NULL), &error);
  CMSampleBufferRef videoSample = FLTCreateTestSampleBuffer();
  CMSampleBufferRef audioSample = FLTCreateTestAudioSampleBuffer();

  id connectionMock = OCMClassMock([AVCaptureConnection class]);

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

  __block NSArray *writtenSamples = @[];

  id videoMock = OCMClassMock([AVAssetWriterInputPixelBufferAdaptor class]);
  OCMStub([videoMock assetWriterInputPixelBufferAdaptorWithAssetWriterInput:OCMOCK_ANY
                                                sourcePixelBufferAttributes:OCMOCK_ANY])
      .andReturn(videoMock);
  OCMStub([videoMock appendPixelBuffer:[OCMArg anyPointer] withPresentationTime:kCMTimeZero])
      .ignoringNonObjectArgs()
      .andDo(^(NSInvocation *invocation) {
        writtenSamples = [writtenSamples arrayByAddingObject:@"video"];
      });

  id audioMock = OCMClassMock([AVAssetWriterInput class]);
  OCMStub([audioMock assetWriterInputWithMediaType:[OCMArg isEqual:AVMediaTypeAudio]
                                    outputSettings:OCMOCK_ANY])
      .andReturn(audioMock);
  OCMStub([audioMock isReadyForMoreMediaData]).andReturn(YES);
  OCMStub([audioMock appendSampleBuffer:[OCMArg anyPointer]]).andDo(^(NSInvocation *invocation) {
    writtenSamples = [writtenSamples arrayByAddingObject:@"audio"];
  });

  FLTThreadSafeFlutterResult *result =
      [[FLTThreadSafeFlutterResult alloc] initWithResult:^(id result){
      }];
  [cam startVideoRecordingWithResult:result];

  [cam captureOutput:nil didOutputSampleBuffer:audioSample fromConnection:connectionMock];
  [cam captureOutput:nil didOutputSampleBuffer:audioSample fromConnection:connectionMock];
  [cam captureOutput:cam.captureVideoOutput
      didOutputSampleBuffer:videoSample
             fromConnection:connectionMock];
  [cam captureOutput:nil didOutputSampleBuffer:audioSample fromConnection:connectionMock];

  NSArray *expectedSamples = @[ @"video", @"audio" ];
  XCTAssertEqualObjects(writtenSamples, expectedSamples, @"First appended sample must be video.");

  CFRelease(videoSample);
  CFRelease(audioSample);
}

@end
