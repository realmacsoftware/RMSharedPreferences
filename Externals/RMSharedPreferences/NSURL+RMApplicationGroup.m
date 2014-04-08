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

#import "NSURL+RMApplicationGroup.h"

#import <Security/SecCode.h>
#import <pwd.h>

@implementation NSURL (RMApplicationGroup)

+ (NSString *)defaultGroupContainerIdentifier
{
    NSString* applicationGroupIdentifier = nil;

    SecCodeRef selfCode = NULL;
    SecCodeCopySelf(kSecCSDefaultFlags, &selfCode);

    if (selfCode)
    {
        CFDictionaryRef cfDic = NULL;
        SecCodeCopySigningInformation(selfCode, kSecCSRequirementInformation, &cfDic);
        NSDictionary* signingDic = CFBridgingRelease(cfDic);

        NSDictionary* entitlementsDic = [signingDic objectForKey:@"entitlements-dict"];
        NSArray* appGroupsArray = [entitlementsDic objectForKey:@"com.apple.security.application-groups"];

        if ([appGroupsArray isKindOfClass:[NSArray class]] && appGroupsArray.count > 0)
            applicationGroupIdentifier = [appGroupsArray objectAtIndex:0];

        CFRelease(selfCode);
    }
	
	return applicationGroupIdentifier;
}

+ (NSURL *)containerURLForSecurityApplicationGroupIdentifier:(NSString *)identifier
{
	identifier = identifier ? : [self defaultGroupContainerIdentifier];
	
	if (identifier == nil) {
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"A default identifier could not be found in the entitlements." userInfo:nil];
		return nil;
	}
	
	static NSString * const NSURLEMBContainerExtensionsLibraryFolderName = @"Library";
	static NSString * const NSURLEMBContainerExtensionsGroupContainerFolderName = @"Group Containers";
	
	static NSURL *groupsContainerDirectory = nil;
	
	static dispatch_once_t onceToken = 0;
	dispatch_once(&onceToken, ^ {
		struct passwd *pw = getpwuid(getuid());
		const char *homedir = pw->pw_dir;
		NSURL *homeDirectory = [NSURL fileURLWithPath:@(homedir)];
		groupsContainerDirectory = [[homeDirectory URLByAppendingPathComponent:NSURLEMBContainerExtensionsLibraryFolderName] URLByAppendingPathComponent:NSURLEMBContainerExtensionsGroupContainerFolderName];
	});
	
	NSURL *indentifierGroupsContainerDirectory = [groupsContainerDirectory URLByAppendingPathComponent:identifier];
	
	BOOL createdDirectory = [[NSFileManager defaultManager] createDirectoryAtURL:indentifierGroupsContainerDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
	if (!createdDirectory) {
		return nil;
	}
	
	return indentifierGroupsContainerDirectory;
}

@end
