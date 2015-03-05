//
//  NSOperation+ActivityIndicator.m
//  MKNetworkKit-iOS
//
//  Created by Ewan Mellor on 3/5/15.
//  Copyright (c) 2015 Steinlogic. All rights reserved.
//

#import <objc/runtime.h>

#import "NSOperation+ActivityIndicator.h"


@implementation NSOperation (ActivityIndicator)


-(BOOL)hideActivityIndicator {
  NSNumber * n = (NSNumber *)objc_getAssociatedObject(self, @selector(hideActivityIndicator));
  return n.boolValue;
}

-(void)setHideActivityIndicator:(BOOL)new_hideActivityIndicator {
  objc_setAssociatedObject(self, @selector(hideActivityIndicator), @(new_hideActivityIndicator), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


@end
