//
//  NSDictionary+CaseInsensitive.m
//
//  Copyright (C) 2012 Chris Brauchli
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "NSDictionary+CaseInsensitive.h"

static Boolean caseInsensitiveEqual (const void *a, const void *b)
{
    return [(__bridge id)a compare:(__bridge id)b options:
            NSCaseInsensitiveSearch | NSLiteralSearch] == NSOrderedSame;
}

static CFHashCode caseInsensitiveHash (const void *value)
{
    return [[(__bridge id)value lowercaseString] hash];
}

@implementation NSDictionary (NSDictionaryCaseInsensitiveAdditions)

- (id)initWithDictionaryCaseInsensitive:(NSDictionary *)src
{
    CFDictionaryKeyCallBacks keyCallbacks = kCFTypeDictionaryKeyCallBacks;
    keyCallbacks.equal = caseInsensitiveEqual;
    keyCallbacks.hash = caseInsensitiveHash;
    
    CFMutableDictionaryRef dest = CFDictionaryCreateMutable (kCFAllocatorDefault,
                                                             [src count], // capacity
                                                             &keyCallbacks,
                                                             &kCFTypeDictionaryValueCallBacks
                                                             );
    
    NSEnumerator *enumerator = [src keyEnumerator];
    id key = nil;
    while (key = [enumerator nextObject]) {
        id value = [src objectForKey:key];
        [(__bridge NSMutableDictionary *)dest setObject:value forKey:key];
    }
    
    return (__bridge_transfer NSDictionary *)dest;
}

+ (id)dictionaryWithDictionaryCaseInsensitive:(NSDictionary *)dictionary
{
    return [[self alloc] initWithDictionaryCaseInsensitive:dictionary];
}

@end
