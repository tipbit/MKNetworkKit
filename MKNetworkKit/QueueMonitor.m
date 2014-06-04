//
//  QueueMonitor.m
//  MKNetworkKit-iOS
//
//  Created by Ewan Mellor on 1/10/14.
//  Copyright (c) 2014 Tipbit. All rights reserved.
//

#import "NSOperationQueue+ActivityThreshold.h"

#import "QueueMonitor.h"


// Warn if the queue length reaches this * queue.maxConcurrentCount.
#define QUEUE_LENGTH_WARNING_MULTIPLIER 20


@interface QueueMonitorJob ()

@property (nonatomic) NSUInteger queueLengthWhenScheduled;
@property (nonatomic) bool isCancelled;
@property (nonatomic) bool isExecuting;
@property (nonatomic) bool isFinished;

@property (nonatomic, readonly, weak) NSOperationQueue* queue;
@property (nonatomic, weak) NSOperation* operation;

/**
 * true if an offset that has been applied to self.queue.activityThreshold to account for this job.
 * This will be false if the job does not have hideActivityIndicator set, or is finished; true otherwise.
 */
@property (nonatomic) bool activityThresholdAdjusted;

-(id)init:(NSOperationQueue *)queue operation:(NSOperation *)operation jobName:(NSString *)jobName queueLength:(NSUInteger)queueLength;

@end


@interface QueueMonitor ()

/**
 * The NSOperationQueue that is being monitored.
 */
@property (nonatomic, weak, readonly) NSOperationQueue* queue;

/**
 * The NSMutableArray that is being monitored.  This is an alternative to using NSOperationQueue; self.array and self.queue are mutually exclusive.
 */
@property (nonatomic, weak, readonly) NSMutableArray * array;

/**
 * The name for this monitor.  Only used when using self.array; when using self.queue, the queue's name is used.
 */
@property (nonatomic, strong, readonly) NSString * name;

@property (nonatomic, readonly) bool isNetwork;

@property (atomic) NSUInteger queueLengthPeak;
@property (atomic) NSUInteger totalJobs;

/**
 * May only be accessed under @synchronized (jobs_).
 */
@property (nonatomic, readonly) NSMutableArray* jobs_;

/**
 * Only used when using self.array.
 */
@property (atomic) NSUInteger lastArrayLength;

@end


/**
 * May only be accessed under @synchronized (allMonitors).
 */
static NSMutableArray* allMonitors;

/**
 * Main thread only.
 */
static bool lastNetworkActivity;

/**
 * Main thread only.
 */
static NSNumber* pendingNetworkActivity;


@implementation QueueMonitor


+(void)initialize {
    allMonitors = [NSMutableArray array];
}


+(NSArray *)all {
    @synchronized (allMonitors) {
        return [allMonitors copy];
    }
}


-(id)init:(NSOperationQueue*)queue isNetwork:(bool)isNetwork {
    self = [super init];
    if (self) {
        _queue = queue;
        _isNetwork = isNetwork;
        _jobs_ = [NSMutableArray array];

        [queue addObserver:self forKeyPath:@"operationCount" options:0 context:NULL];

        @synchronized (allMonitors) {
            [allMonitors addObject:self];
        }
    }
    return self;
}


-(id)initWithArray:(NSMutableArray *)array isNetwork:(bool)isNetwork name:(NSString *)name {
    self = [super init];
    if (self) {
        _array = array;
        _name = name;
        _isNetwork = isNetwork;
        _jobs_ = [NSMutableArray array];

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
    return self.queue == nil ? self.name : self.queue.name;
}


-(NSUInteger)queueLength {
    return self.queue == nil ? self.array.count : self.queue.operationCount;
}


-(NSInteger)queueMaxConcurrentOperationCount {
    return self.queue.maxConcurrentOperationCount;
}


-(void)resetStats {
    self.queueLengthPeak = 0;
    self.totalJobs = 0;

    @synchronized (self.jobs_) {
        NSMutableArray* to_remove = [NSMutableArray array];
        for (QueueMonitorJob* job in self.jobs_) {
            NSOperation* op = job.operation;

            if (op == nil) {
                [to_remove addObject:job];
            }
        }
        if (to_remove.count > 0) {
            [self.jobs_ removeObjectsInArray:to_remove];
        }
    }
}


-(void)addOperationToQueue:(NSOperation *)op name:(NSString *)name {
    // These two need to be this way around, because the addOperation call
    // will trigger a KVO notification on operationCount, and that's when
    // we're calling checkActivity and updateNetworkActivityIndicator.
    [self monitorOperation:op name:name];
    [self.queue addOperation:op];
}


-(void)addOperationToQueueWithBlock:(void(^)(void))block name:(NSString *)name {
    NSBlockOperation* op = [NSBlockOperation blockOperationWithBlock:block];
    // Same as comment above.
    [self monitorOperation:op name:name];
    [self.queue addOperation:op];
}


-(void)monitorOperation:(NSOperation *)op name:(NSString *)name {
    // Any thread.

    self.totalJobs++;

    NSString * jobName = name == nil ? @"<unnamed>" : name;
    QueueMonitorJob* job = [[QueueMonitorJob alloc] init:self.queue operation:op jobName:jobName queueLength:self.queueLength];

    if (job.queueLengthWhenAdded > QUEUE_LENGTH_WARNING_MULTIPLIER * self.queueMaxConcurrentOperationCount)
        NSLog(@"Performance warning: %@ queue has %lu items", self.queueName, (unsigned long)job.queueLengthWhenAdded);

    @synchronized (self.jobs_) {
        [self.jobs_ insertObject:job atIndex:0];
        NSUInteger cap = job.queueLengthWhenAdded + 50;
        if (self.jobs_.count > cap)
            [self.jobs_ removeObjectsInRange:NSMakeRange(cap, self.jobs_.count - cap)];
    }
}


-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    assert(object == self.queue);
    assert([keyPath isEqualToString:@"operationCount"]);

    NSUInteger n = self.queue.operationCount;
    if (n > self.queueLengthPeak)
        self.queueLengthPeak = n;
    [[NSNotificationCenter defaultCenter] postNotificationName:kMKNetworkEngineOperationCountChanged object:@(n)];
    bool networkActivity = [QueueMonitor checkActivity];
#if TARGET_OS_IPHONE
    dispatch_async(dispatch_get_main_queue(), ^{
        [QueueMonitor updateNetworkActivityIndicator:networkActivity];
    });
#else
    __unused bool dummy = networkActivity;
#endif
}


-(void)refreshArrayStats {
    NSUInteger newArrayLength = self.array.count;
    if (newArrayLength > self.lastArrayLength) {
        self.totalJobs += newArrayLength - self.lastArrayLength;
    }
    if (newArrayLength > self.queueLengthPeak) {
        self.queueLengthPeak = newArrayLength;
    }
    self.lastArrayLength = newArrayLength;
}


+(void)updateNetworkActivityIndicator:(bool)activity {
    assert([NSThread isMainThread]);

    NSNumber* pending = pendingNetworkActivity;
    if ((pending == nil && activity == lastNetworkActivity) ||
        (pending != nil && activity == [pending boolValue])) {
        return;
    }

    if (pending != nil)
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateNetworkActivityIndicator_) object:nil];
    pendingNetworkActivity = @(activity);

    [self performSelector:@selector(updateNetworkActivityIndicator_) withObject:nil afterDelay:0.3];
}


+(void)updateNetworkActivityIndicator_ {
    assert([NSThread isMainThread]);

    lastNetworkActivity = [pendingNetworkActivity boolValue];
    pendingNetworkActivity = nil;
    [UIApplication sharedApplication].networkActivityIndicatorVisible = lastNetworkActivity;
}


-(NSString *)description {
    return [NSString stringWithFormat:NSLocalizedString(@"%@, current length %u, peak length %u, total jobs %u", @"QueueMonitor.description"),
            self.queueName, self.queueLength, self.queueLengthPeak, self.totalJobs];
}


/**
 * Go through allMonitors, discarding any that are no longer valid.
 *
 * @return Whether any of the remaining monitors are showing network activity.
 */
+(bool)checkActivity {
    bool result = false;
    @synchronized (allMonitors) {
        NSMutableArray* to_remove = nil;
        for (QueueMonitor* qm in allMonitors) {
            if (qm.array != nil) {
                continue;
            }
            NSOperationQueue* q = qm.queue;
            if (q == nil) {
                if (to_remove == nil) {
                    to_remove = [NSMutableArray array];
                }
                [to_remove addObject:qm];
            }
            else if (qm.isNetwork && q.operationCount > q.activityThreshold) {
                result = true;
            }
        }
        if (to_remove.count > 0) {
            [allMonitors removeObjectsInArray:to_remove];
        }
    }
    return result;
}


@end


@implementation QueueMonitorJob


-(id)init:(NSOperationQueue *)queue operation:(NSOperation *)operation jobName:(NSString *)jobName queueLength:(NSUInteger)queueLength {
    self = [super init];
    if (self) {
        _queue = queue;
        _jobName = jobName;
        _queueLengthWhenAdded = queueLength;

        self.operation = operation;  // Call addObserver and setActivityThresholdAdjusted implicitly.
    }
    return self;
}


-(void)dealloc {
    self.operation = nil; // Call removeObserver and setActivityThresholdAdjusted implicitly.
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

    self.activityThresholdAdjusted = getHideActivityIndicator(new_operation);
}


-(void)setActivityThresholdAdjusted:(bool)new_activityThresholdAdjusted {
    if (new_activityThresholdAdjusted == _activityThresholdAdjusted) {
        return;
    }
    _activityThresholdAdjusted = new_activityThresholdAdjusted;
    NSInteger offset = new_activityThresholdAdjusted ? 1 : -1;
    @synchronized (self.queue) {
        self.queue.activityThreshold += offset;
        if (self.queue.activityThreshold > 10000000) {
            // Wrap-around, squelch to zero for sanity.  This should never happen.
            self.queue.activityThreshold = 0;
        }
    }
}


static BOOL getHideActivityIndicator(NSOperation * op) {
    if ([op isKindOfClass:[MKNetworkOperation class]]) {
        MKNetworkOperation * netop = (MKNetworkOperation *)op;
        return netop.hideActivityIndicator;
    }
    else {
        return NO;
    }
}


-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    NSOperation* op = (NSOperation *)object;
    // op is ordinarily equal to self.operation here.
    // self.operation might be nil if the operation is cancelled and we're seeing the isFinished = YES event now.
    // We'll see the isCancelled flag change, set self.operation = nil below, and then we'll see the isFinished
    // flag change.
    self.isCancelled = op.isCancelled;
    self.isExecuting = op.isExecuting;
    self.isFinished = op.isFinished;

    if ([keyPath isEqualToString:@"isExecuting"] && self.isExecuting) {
        self.queueLengthWhenScheduled = self.queue.operationCount;
    }
    if (op.isFinished || op.isCancelled) {
        self.operation = nil; // Call removeObserver and setActivityThresholdAdjusted implicitly.
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
