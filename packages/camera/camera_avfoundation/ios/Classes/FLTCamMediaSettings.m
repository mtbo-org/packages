// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "FLTCamMediaSettings.h"

@implementation FLTCamMediaSettings

#define AssertPositiveNumberOrNil(param)                                                        \
  if (param != nil) {                                                                           \
    NSAssert([param isKindOfClass:[NSNumber class]], @"%@ is not a number: %@", @ #param, param); \
    NSAssert(!isnan([param doubleValue]), @"%@ is NaN", @ #param);                              \
    NSAssert([param doubleValue] > 0, @"%@ is not positive: %@", @ #param, param);              \
  }

- (instancetype)initWithFramesPerSecond:(nullable NSNumber *)framesPerSecond
                           videoBitrate:(nullable NSNumber *)videoBitrate
                           audioBitrate:(nullable NSNumber *)audioBitrate
                            enableAudio:(BOOL)enableAudio {
  AssertPositiveNumberOrNil(framesPerSecond);
  AssertPositiveNumberOrNil(videoBitrate);
  AssertPositiveNumberOrNil(audioBitrate);

  _framesPerSecond = framesPerSecond;
  _videoBitrate = videoBitrate;
  _audioBitrate = audioBitrate;
  _enableAudio = enableAudio;

  return self;
}

@end
