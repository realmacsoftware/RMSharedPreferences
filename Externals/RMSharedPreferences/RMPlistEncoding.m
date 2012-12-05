//
// Copyright (C) 2012 Realmac Software Ltd
//
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject
// to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR
// ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
// CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "RMPlistEncoding.h"

@implementation RMPlistEncoding

+ (BOOL)canEncodeObject:(id)object
{
	if ([object isKindOfClass:[NSString class]]) {
		return YES;
	}
	
	if ([object isKindOfClass:[NSData class]]) {
		return YES;
	}
	
	if ([object isKindOfClass:[NSNumber class]]) {
		return YES;
	}
	
	if ([object isKindOfClass:[NSDate class]]) {
		return YES;
	}
	
	if ([object isKindOfClass:[NSArray class]]) {
		__block BOOL canEncodeArray = YES;
		
		[(NSArray *)object enumerateObjectsUsingBlock:^ (id containedObject, NSUInteger idx, BOOL *stop) {
			if (![self canEncodeObject:containedObject]) {
				*stop = YES;
				canEncodeArray = NO;
			}
		}];
		
		return canEncodeArray;
	}
	
	if ([object isKindOfClass:[NSDictionary class]]) {
		__block BOOL canEncodeDictionary = YES;
		
		[(NSDictionary *)object enumerateKeysAndObjectsUsingBlock:^ (id containedKey, id containedObject, BOOL *stop) {
			if (![containedKey isKindOfClass:[NSString class]] || ![self canEncodeObject:containedObject]) {
				*stop = YES;
				canEncodeDictionary = NO;
			}
		}];
		
		return canEncodeDictionary;
	}
	
	return NO;
}

@end
