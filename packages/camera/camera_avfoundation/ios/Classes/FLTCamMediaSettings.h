// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

/**
 * Media settings configuration parameters.
 */
@interface FLTCamMediaSettings : NSObject

/**
 * @property framesPerSecond optional frame rate of video being recorded.
 */
@property(atomic, readonly, strong) NSNumber *framesPerSecond;

/**
 * @property videoBitrate optional bitrate of video being recorded.
 */
@property(atomic, readonly, strong) NSNumber *videoBitrate;

/**
 * @property audioBitrate optional bitrate of audio being recorded.
 */
@property(atomic, readonly, strong) NSNumber *audioBitrate;

/**
 * @property enableAudio should be audio recorded.
 */
@property(atomic, readonly) BOOL enableAudio;

/**
 * @method initWithFramesPerSecond:videoBitrate:audioBitrate:enableAudio:
 *
 * @abstract Initialize `FLTCamMediaSettings`.
 *
 * @param framesPerSecond optional frame rate of video being recorded.
 * @param videoBitrate optional bitrate of video being recorded.
 * @param audioBitrate optional bitrate of audio being recorded.
 * @param enableAudio should be audio recorded.
 *
 * @result FLTCamMediaSettings instance
 */
- (instancetype)initWithFramesPerSecond:(nullable NSNumber *)framesPerSecond
                           videoBitrate:(nullable NSNumber *)videoBitrate
                           audioBitrate:(nullable NSNumber *)audioBitrate
                            enableAudio:(BOOL)enableAudio;
@end

NS_ASSUME_NONNULL_END
