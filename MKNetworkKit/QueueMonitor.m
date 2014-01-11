//
//  QueueMonitor.m
//  MKNetworkKit-iOS
//
//  Created by Ewan Mellor on 1/10/14.
//  Copyright (c) 2014 Tipbit. All rights reserved.
//

#import "QueueMonitor.h"


@interface QueueMonitorJob ()

@property (nonatomic) NSString* jobName;
@property (nonatomic) NSUInteger queueLengthWhenAdded;
@property (nonatomic) NSUInteger queueLengthWhenScheduled;
@property (nonatomic) bool isCancelled;
@property (nonatomic) bool isExecuting;
@property (nonatomic) bool isFinished;

@property (nonatomic, weak) NSOperationQueue* queue;
@property (nonatomic, weak) NSOperation* operation;

@end


@interface QueueMonitor ()

@property (nonatomic, weak, readonly) NSOperationQueue* queue;
@property (atomic) NSUInteger queueLengthPeak;

/**
 * May only be accessed under @synchronized (jobs_).
 */
@property (nonatomic, readonly) NSMutableArray* jobs_;

@end


/**
 * May only be accessed under @synchronized (allMonitors).
 */
static NSMutableArray* allMonitors;


@implementation QueueMonitor


+(void)initialize {
    allMonitors = [NSMutableArray array];
}


+(NSArray *)all {
    @synchronized (allMonitors) {
        return [allMonitors copy];
    }
}


-(id)init:(NSOperationQueue*)queue {
    self = [super init];
    if (self) {
        _queue = queue;
        _jobs_ = [NSMutableArray array];

        [queue addObserver:self forKeyPath:@"operationCount" options:0 context:NULL];

        @synchronized (allMonitors) {
            [allMonitors addObject:self];
        }
    }
    return self;
}


-(void)dealloc {
    [_queue removeObserver:self forKeyPath:@"operationCount"];
}


-(NSArray *)jobs {
    NSMutableArray* result = [NSMutableArray array];
    @synchronized (self.jobs_) {
        NSUInteger dead_ones = 0;
        for (QueueMonitorJob* job in self.jobs_) {
            NSOperation* op = job.operation;

            if (op == nil) {
                job.isExecuting = false;
                job.isFinished = true;
                dead_ones++;
            }
            else {
                job.isExecuting = op.isExecuting;
                job.isFinished = op.isFinished;
            }

            [result addObject:job];
            if (dead_ones > 50)
                break;
        }
        if (self.jobs_.count > result.count)
            [self.jobs_ removeObjectsInRange:NSMakeRange(result.count, self.jobs_.count - result.count)];
    }
    return result;
}


-(NSString *)queueName {
    return self.queue.name;
}


-(NSUInteger)queueLength {
    return self.queue.operationCount;
}


-(NSInteger)queueMaxConcurrentOperationCount {
    return self.queue.maxConcurrentOperationCount;
}


-(void)resetStats {
    self.queueLengthPeak = 0;

    @synchronized (self.jobs_) {
        NSMutableArray* to_remove = [NSMutableArray array];
        for (QueueMonitorJob* job in self.jobs_) {
            NSOperation* op = job.operation;

            if (op == nil)
                [to_remove addObject:job];
        }
        if (to_remove.count > 0)
            [self.jobs_ removeObjectsInArray:to_remove];
    }
}


-(void)addOperationToQueue:(NSOperation *)op name:(NSString *)name {
    [self.queue addOperation:op];
    [self monitorOperation:op name:name];
}


-(void)addOperationToQueueWithBlock:(void(^)(void))block name:(NSString *)name {
    NSBlockOperation* op = [NSBlockOperation blockOperationWithBlock:block];
    [self.queue addOperation:op];
    [self monitorOperation:op name:name];
}


-(void)monitorOperation:(NSOperation *)op name:(NSString *)name {
    QueueMonitorJob* job = [[QueueMonitorJob alloc] init];
    job.queue = self.queue;
    job.operation = op;
    job.jobName = name == nil ? @"<unnamed>" : name;
    job.queueLengthWhenAdded = self.queueLength;

    @synchronized (self.jobs_) {
        [self.jobs_ insertObject:job atIndex:0];
    }
}


-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    assert(object == self.queue);
    assert([keyPath isEqualToString:@"operationCount"]);

    NSUInteger n = self.queue.operationCount;
    if (n > self.queueLengthPeak)
        self.queueLengthPeak = n;
    [[NSNotificationCenter defaultCenter] postNotificationName:kMKNetworkEngineOperationCountChanged object:@(n)];
#if TARGET_OS_IPHONE
    [UIApplication sharedApplication].networkActivityIndicatorVisible = [QueueMonitor anyActivity];
#endif
}


-(NSString *)description {
    NSOperationQueue* q = self.queue;
    return [NSString stringWithFormat:NSLocalizedString(@"%@, current length %u, peak length %u", @"QueueMonitor.description"),
            q.name, q.operationCount, self.queueLengthPeak];
}


+(bool)anyActivity {
    bool result = false;
    @synchronized (allMonitors) {
        NSMutableArray* to_remove = nil;
        for (QueueMonitor* qm in allMonitors) {
            NSOperationQueue* q = qm.queue;
            if (q == nil) {
                if (to_remove == nil)
                    to_remove = [NSMutableArray array];
                [to_remove addObject:qm];
            }
            else if (q.operationCount > 0) {
                result = true;
            }
        }
        if (to_remove.count > 0)
            [allMonitors removeObjectsInArray:to_remove];
    }
    return result;
}


@end


@implementation QueueMonitorJob


-(void)dealloc {
    self.operation = nil; // Call removeObserver implicitly.
}


-(void)setOperation:(NSOperation *)new_operation {
    NSOperation* old_operation = _operation;
    _operation = new_operation;
    [old_operation removeObserver:self forKeyPath:@"isCancelled"];
    [old_operation removeObserver:self forKeyPath:@"isExecuting"];
    [old_operation removeObserver:self forKeyPath:@"isFinished"];
    [new_operation addObserver:self forKeyPath:@"isCancelled" options:0 context:NULL];
    [new_operation addObserver:self forKeyPath:@"isExecuting" options:0 context:NULL];
    [new_operation addObserver:self forKeyPath:@"isFinished" options:0 context:NULL];
}


-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    NSOperation* op = self.operation;
    assert(object == op);
    self.isCancelled = op.isCancelled;
    self.isExecuting = op.isExecuting;
    self.isFinished = op.isFinished;

    if ([keyPath isEqualToString:@"isExecuting"] && self.isExecuting) {
        self.queueLengthWhenScheduled = self.queue.operationCount;
    }
}


-(NSString *)description {
    return [NSString stringWithFormat:NSLocalizedString(@"%@ %@", @"QueueMonitorJob.description"),
            self.isFinished ? @"F" : self.isExecuting ? @"X" : @"w", self.jobName];
}


-(NSString *)debugDescription {
    return [NSString stringWithFormat:NSLocalizedString(@"%@ %2u -> %2u %@", @"QueueMonitorJob.debugDescription"),
            self.isFinished ? @"F" : self.isExecuting ? @"X" : @"w", self.queueLengthWhenAdded, self.queueLengthWhenScheduled, self.jobName];
}


@end
