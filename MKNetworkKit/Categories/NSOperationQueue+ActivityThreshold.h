//
//  NSOperationQueue+ActivityThreshold.h
//  MKNetworkKit-iOS
//
//  Created by Ewan Mellor on 5/13/14.
//  Copyright (c) 2014 Steinlogic. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSOperationQueue (ActivityThreshold)

/**
 * The threshold that self.queue.operationCount must be greater than before we show the activity indicator.
 * This is normally 0, but can be set to a larger number if the queue contains "long-poll" operations
 * (i.e. those with MKNetworkOperation.hideActivityIndicator set).
 */
@property (nonatomic, assign) NSUInteger activityThreshold;

@property (nonatomic) NSNumber * baseMaxConcurrentOperationCount;

@end
