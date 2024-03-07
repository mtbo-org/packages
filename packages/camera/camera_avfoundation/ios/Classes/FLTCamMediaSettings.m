// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "FLTCamMediaSettings.h"

@implementation FLTCamMediaSettings

NS_INLINE void AssertPositiveNumberOrNil(id param, const char *paramName) {
  if (param != nil) {
    NSCAssert([param isKindOfClass:[NSNumber class]], @"%s is not a number: %@", paramName, param);
    NSCAssert(!isnan([param doubleValue]), @"%s is NaN", paramName);
    NSCAssert([param doubleValue] > 0, @"%s is not positive: %@", paramName, param);
  }
}

- (instancetype)initWithFramesPerSecond:(nullable NSNumber *)framesPerSecond
                           videoBitrate:(nullable NSNumber *)videoBitrate
                           audioBitrate:(nullable NSNumber *)audioBitrate
                            enableAudio:(BOOL)enableAudio {
  AssertPositiveNumberOrNil(framesPerSecond, "framesPerSecond");
  AssertPositiveNumberOrNil(videoBitrate, "videoBitrate");
  AssertPositiveNumberOrNil(audioBitrate, "audioBitrate");

  _framesPerSecond = framesPerSecond;
  _videoBitrate = videoBitrate;
  _audioBitrate = audioBitrate;
  _enableAudio = enableAudio;

  return self;
}

@end
