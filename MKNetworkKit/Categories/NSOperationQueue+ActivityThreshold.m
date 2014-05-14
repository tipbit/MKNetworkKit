//
//  NSOperationQueue+ActivityThreshold.m
//  MKNetworkKit-iOS
//
//  Created by Ewan Mellor on 5/13/14.
//  Copyright (c) 2014 Steinlogic. All rights reserved.
//

#import <objc/runtime.h>

#import "NSOperationQueue+ActivityThreshold.h"


@implementation NSOperationQueue (ActivityThreshold)

-(NSUInteger)activityThreshold {
  NSNumber * n = (NSNumber *)objc_getAssociatedObject(self, @selector(activityThreshold));
  return [n unsignedIntegerValue];
}

-(void)setActivityThreshold:(NSUInteger)new_activityThreshold {
  objc_setAssociatedObject(self, @selector(activityThreshold), @(new_activityThreshold), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
