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

#import "RMHelperAppDelegate.h"

#import "RMSharedPreferences/RMSharedPreferences.h"

#import "SharedPreferences-Constants.h"

@implementation RMHelperAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(preferencesDidUpdate:) name:NSUserDefaultsDidChangeNotification object:[RMSharedUserDefaults standardUserDefaults]];
	
	[self _updateTextField:[[RMSharedUserDefaults standardUserDefaults] stringForKey:RMSharedPreferencesSomeTextDefaultKey]];
	
	[[self textField] setTarget:self];
	[[self textField] setAction:@selector(saveText:)];
}

- (void)preferencesDidUpdate:(NSNotification *)notification
{
	NSString *defaultName = [[notification userInfo] objectForKey:RMSharedUserDefaultsDidChangeDefaultNameKey];
	
	if ([defaultName isEqualToString:RMSharedPreferencesSomeTextDefaultKey]) {
		NSString *text = [[notification userInfo]objectForKey:RMSharedUserDefaultsDidChangeDefaulValueKey];
		[self _updateTextField:text];
	}
}

- (IBAction)saveText:(id)sender
{
	[[RMSharedUserDefaults standardUserDefaults] setObject:[[self textField] stringValue] forKey:RMSharedPreferencesSomeTextDefaultKey];
}

- (void)_updateTextField:(NSString *)text
{
	if (text == nil) {
		return;
	}
	[[self textField] setStringValue:text];
}

@end
