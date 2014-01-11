//
//  QueueMonitor.h
//  MKNetworkKit-iOS
//
//  Created by Ewan Mellor on 1/10/14.
//  Copyright (c) 2014 Tipbit. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface QueueMonitorJob : NSObject

@property (readonly) NSString* jobName;
@property (readonly) NSUInteger queueLengthWhenAdded;
@property (readonly) NSUInteger queueLengthWhenScheduled;
@property (readonly) bool isCancelled;
@property (readonly) bool isExecuting;
@property (readonly) bool isFinished;

@end


@interface QueueMonitor : NSObject

@property (readonly) NSString* queueName;
@property (readonly) NSUInteger queueLength;
@property (readonly) NSUInteger queueLengthPeak;
@property (readonly) NSInteger queueMaxConcurrentOperationCount;
@property (readonly) NSArray* jobs;

-(id)init:(NSOperationQueue*)queue;

/**
 * Add the given operation to this monitor, assuming that you've already added it to the queue.
 *
 * @param name May be nil, in which case the job will be marked <unnamed>.
 */
-(void)monitorOperation:(NSOperation*)op name:(NSString*)name;

/**
 * Add the given operation to self.queue, and add it to the monitoring with the given name.
 *
 * @param name May be nil, in which case the job will be marked <unnamed>.
 */
-(void)addOperationToQueue:(NSOperation*)op name:(NSString*)name;

/**
 * Create an NSBlockOperation with the given block, add it to self.queue, and add it to the monitoring with the given name.
 *
 * @param name May be nil, in which case the job will be marked <unnamed>.
 */
-(void)addOperationToQueueWithBlock:(void(^)(void))block name:(NSString*)name;

-(void)resetStats;

+(NSArray*)all;

@end
