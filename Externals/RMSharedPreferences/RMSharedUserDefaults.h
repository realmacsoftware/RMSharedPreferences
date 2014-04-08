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

#import <Foundation/Foundation.h>

@interface RMSharedUserDefaults : NSUserDefaults

+ (RMSharedUserDefaults *)standardUserDefaults;

/*!
	\brief
	Designated initializer.
	
	\params
	applicationGroupIdentifier: the identifier for the application group the user defaults should target.
	You can pass nil to retrieve the default group container identifier. Throws an exception if no default identifier can be retrieved.
 */
- (id)initWithApplicationGroupIdentifier:(NSString *)applicationGroupIdentifier;

- (id) initWithSharedFileURL:(NSURL *)fileURL;

@end

extern NSString * const RMSharedUserDefaultsDidChangeDefaultNameKey;
extern NSString * const RMSharedUserDefaultsDidChangeDefaulValueKey;
