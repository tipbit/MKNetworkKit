//
//  QueueMonitor.h
//  MKNetworkKit-iOS
//
//  Created by Ewan Mellor on 1/10/14.
//  Copyright (c) 2014 Tipbit. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface QueueMonitorJob : NSObject

@property (nonatomic, readonly) NSString* jobName;
@property (nonatomic, readonly) NSUInteger queueLengthWhenAdded;
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

/**
 * Total number of jobs added to this queue ever (or since the last resetStats), including ones that are running or haven't started yet.
 */
@property (readonly) NSUInteger totalJobs;

/**
 * @param isNetwork If true, then when this queue has jobs the networkActivityIndicatorVisible will be shown on iPhone.
 */
-(id)init:(NSOperationQueue*)queue isNetwork:(bool)isNetwork;

/**
 * Monitor the given NSMutableArray.  Whenever you add to this array, you must call [self refreshArrayStats].  If you need
 * any locking around access to this array, then you must handle that yourself before calling [self refreshArrayStats].
 *
 * @param isNetwork If true, then when this array is non-empty the networkActivityIndicatorVisible will be shown on iPhone.
 */
-(id)initWithArray:(NSMutableArray *)array isNetwork:(bool)isNetwork name:(NSString *)name;

/**
 * Stop monitoring the registered queue.  You should call this before
 * releasing this instance, so that the KVO on the queue is deregistered.
 * (It is not safe to just let dealloc do it, because we can't guarantee
 * deallocation order if both the queue and this monitor are released
 * in the same autoreleasepool context.
 */
-(void)deregisterQueue;

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

-(void)refreshArrayStats;

-(void)resetStats;

+(NSArray*)all;

@end
