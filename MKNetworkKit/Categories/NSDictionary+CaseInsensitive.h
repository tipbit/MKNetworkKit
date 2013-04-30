//
//  NSDictionary+CaseInsensitive.h
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

#import <Foundation/Foundation.h>

/// Utility for building case-insensitive NSDictionary objects.
@interface NSDictionary (NSDictionaryCaseInsensitiveAdditions)

/// Initializes an NSDictionary with a case-insensitive comparison function
/// for NSString keys, while non-NSString keys are treated normally.
///
/// The case for NSString keys is preserved, though duplicate keys (when
/// compared in a case-insensitive fashion) have one of their values dropped
/// arbitrarily.
///
/// An example of use with HTTP headers in an NSHTTPURLResponse object:
///
/// NSDictionary *headers =
///     [NSDictionary dictionaryWithDictionaryCaseInsensitive:
///      [response allHeaderFields]];
/// NSString *contentType = [headers objectForKey:@"Content-Type"];
- (id)initWithDictionaryCaseInsensitive:(NSDictionary *)dictionary;

/// Returns a newly created and autoreleased NSDictionary object as above.
+ (id)dictionaryWithDictionaryCaseInsensitive:(NSDictionary *)dictionary;

@end
