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

-(void)addOperation:(NSOperation*)op name:(NSString*)name;

-(void)resetStats;

+(NSArray*)all;

@end
