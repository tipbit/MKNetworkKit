//
//  NSOperation+ActivityIndicator.h
//  MKNetworkKit-iOS
//
//  Created by Ewan Mellor on 3/5/15.
//  Copyright (c) 2015 Steinlogic. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSOperation (ActivityIndicator)

/**
 * YES if this operation should not cause the activity indicator to show.
 *
 * Use this for "long-poll" operations where the network connection is intended to block for a long time,
 * and you don't want this to look like there is ongoing network traffic.
 *
 * Set this flag before enqueuing this operation.
 */
@property (nonatomic) BOOL hideActivityIndicator;

@end
