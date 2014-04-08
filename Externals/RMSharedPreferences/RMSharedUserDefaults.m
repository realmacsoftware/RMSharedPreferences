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

#import "RMSharedUserDefaults.h"

#import "RMCoalescingOperation.h"
#import "RMPlistEncoding.h"

#import "NSURL+RMApplicationGroup.h"
#import "NSObject+RMSubclassSupport.h"

NSString * const RMSharedUserDefaultsDidChangeDefaultNameKey = @"RMSharedUserDefaultsDidChangeDefaultNameKey";
NSString * const RMSharedUserDefaultsDidChangeDefaulValueKey = @"RMSharedUserDefaultsDidChangeDefaulValueKey";

@interface RMSharedUserDefaults () <NSFilePresenter>

@property (readonly, copy, nonatomic) NSURL *userDefaultsDictionaryLocation;

@property (strong, nonatomic) NSDictionary *userDefaultsDictionary;

@property (strong, nonatomic) NSMutableDictionary *updatedUserDefaultsDictionary;
@property (strong, nonatomic) NSMutableDictionary *registeredUserDefaultsDictionary;

@property (readonly, strong, nonatomic) NSRecursiveLock *accessorLock;
@property (readonly, strong, nonatomic) NSLock *synchronizeLock;

@property (readonly, strong, nonatomic) NSOperationQueue *fileCoordinationOperationQueue;
@property (readonly, strong, nonatomic) NSOperationQueue *synchronizationQueue;

@property (weak, nonatomic) RMCoalescingOperation *lastSynchronizationOperation;

@end

@implementation RMSharedUserDefaults

+ (RMSharedUserDefaults *)standardUserDefaults
{
	static RMSharedUserDefaults *_standardUserDefaults = nil;
	static dispatch_once_t onceToken = 0;
	dispatch_once(&onceToken, ^ {
		_standardUserDefaults = [[self alloc] initWithApplicationGroupIdentifier:nil];
	});
	return _standardUserDefaults;
}

+ (void)resetStandardUserDefaults
{
	RMSharedUserDefaults *userDefaults = [self standardUserDefaults];
	[userDefaults synchronize];
	[[userDefaults userDefaultsDictionary] enumerateKeysAndObjectsUsingBlock:^ (NSString *defaultName, id value, BOOL *stop) {
		[userDefaults removeObjectForKey:defaultName];
	}];
}

- (id)initWithApplicationGroupIdentifier:(NSString *)applicationGroupIdentifier
{
	NSURL *applicationGroupLocation = [NSURL containerURLForSecurityApplicationGroupIdentifier:applicationGroupIdentifier];
	if (applicationGroupLocation == nil) {
		@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"A default application group identifier cannot be found in the entitlements" userInfo:nil];
		return nil;
	}
	
	NSURL *applicationGroupPreferencesLocation = [applicationGroupLocation URLByAppendingPathComponent:@"Preferences"];
	[[NSFileManager defaultManager] createDirectoryAtURL:applicationGroupPreferencesLocation withIntermediateDirectories:YES attributes:nil error:NULL];
	
	NSString *userDefaultsDictionaryFileName = applicationGroupIdentifier ? : [NSURL defaultGroupContainerIdentifier];
	NSURL* defaultsLocation = [[applicationGroupPreferencesLocation URLByAppendingPathComponent:userDefaultsDictionaryFileName] URLByAppendingPathExtension:@"plist"];

	self = [self initWithSharedFileURL:defaultsLocation];
	if (self == nil) {
		return nil;
	}

	return self;
}

- (id) initWithSharedFileURL:(NSURL *)fileURL
{
	self = [super initWithUser:nil];
	if (self == nil) {
		return nil;
	}

	if ( ! fileURL) {
		@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Shared defaults file name not specified" userInfo:nil];
		return nil;
	}

	_userDefaultsDictionaryLocation = fileURL;

	_updatedUserDefaultsDictionary = [NSMutableDictionary dictionary];
	_registeredUserDefaultsDictionary = [NSMutableDictionary dictionary];

	_accessorLock = [[NSRecursiveLock alloc] init];
	_synchronizeLock = [[NSLock alloc] init];

	NSString *queuePrefixName = [fileURL.lastPathComponent stringByAppendingFormat:@".sharedpreferences"];

	_fileCoordinationOperationQueue = [[NSOperationQueue alloc] init];
	[_fileCoordinationOperationQueue setName:[queuePrefixName stringByAppendingFormat:@".filecoordination"]];

	_synchronizationQueue = [[NSOperationQueue alloc] init];
	[_synchronizationQueue setMaxConcurrentOperationCount:1];
	[_synchronizationQueue setName:[queuePrefixName stringByAppendingFormat:@".synchronization"]];

	[self _synchronize];

	[NSFileCoordinator addFilePresenter:self];

	return self;
}

- (id)initWithUser:(NSString *)username
{
	return [self initWithApplicationGroupIdentifier:nil];
}

- (void)dealloc
{
	[NSFileCoordinator removeFilePresenter:self];
}

#pragma mark - Accessors

- (id)objectForKey:(NSString *)defaultName
{
	__block id object = nil;
	
	[self _lock:[self accessorLock] criticalSection:^ {
		object = [[self updatedUserDefaultsDictionary] objectForKey:defaultName];
		if (object != nil) {
			return;
		}
		object = [[self userDefaultsDictionary] objectForKey:defaultName];
		if (object != nil) {
			return;
		}
		object = [[self registeredUserDefaultsDictionary] objectForKey:defaultName];
	}];
	
	return object;
}

- (void)setObject:(id)object forKey:(NSString *)defaultName
{
	if (object != nil && ![RMPlistEncoding canEncodeObject:object]) {
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Attempt to insert non-property value" userInfo:nil];
		return;
	}
	
	object = object ? : [NSNull null];
	
	[self _lock:[self accessorLock] criticalSection:^ {
		[self willChangeValueForKey:defaultName];
		[[self updatedUserDefaultsDictionary] setObject:object forKey:defaultName];
		[self didChangeValueForKey:defaultName];
	}];
	
	[self _notifyChangeForDefaultName:defaultName value:object];
	
	[self _setNeedsSynchronizing];
}

- (void)removeObjectForKey:(NSString *)defaultName
{
	[self setObject:nil forKey:defaultName];
}

#pragma mark - Public

- (NSDictionary *)dictionaryRepresentation
{
	__block NSDictionary *dictionaryRepresentation = nil;
	
	[self _lock:[self accessorLock] criticalSection:^ {
		dictionaryRepresentation = [NSDictionary dictionaryWithDictionary:[self userDefaultsDictionary]];
	}];
	
	return dictionaryRepresentation;
}

- (void)registerDefaults:(NSDictionary *)registrationDictionary
{
	[self _lock:[self accessorLock] criticalSection:^ {
		[[self registeredUserDefaultsDictionary] addEntriesFromDictionary:registrationDictionary];
	}];
}

- (BOOL)synchronize
{
	RMCoalescingOperation *synchronizationOperation = [RMCoalescingOperation coalescingOperationWithBlock:^ {
		[self _synchronize];
	}];
	
	__block RMCoalescingOperation *lastSynchronizationOperation = nil;
	
	[self _lock:[self synchronizeLock] criticalSection:^ {
		lastSynchronizationOperation = [self lastSynchronizationOperation];
		[self setLastSynchronizationOperation:synchronizationOperation];
	}];
	
	[lastSynchronizationOperation waitUntilFinished];
	[synchronizationOperation main];
	
	return YES;
}

#pragma mark - Synchronization

- (void)_setNeedsSynchronizing
{
	[self _lock:[self synchronizeLock] criticalSection:^ {
		RMCoalescingOperation *lastSynchronizationOperation = [self lastSynchronizationOperation];
		
		void (^synchronizationBlock)(void) = ^ {
			[self _synchronizeWithNotifyingQueue:[NSOperationQueue mainQueue]];
		};
		if (lastSynchronizationOperation != nil && [lastSynchronizationOperation replaceBlock:synchronizationBlock]) {
			return;
		}
		
		RMCoalescingOperation *synchronizationOperation = [RMCoalescingOperation coalescingOperationWithBlock:synchronizationBlock];
		
		if (lastSynchronizationOperation != nil) {
			[synchronizationOperation addDependency:lastSynchronizationOperation];
		}
		[self setLastSynchronizationOperation:synchronizationOperation];
		
		[[self synchronizationQueue] addOperation:synchronizationOperation];
		
		[[NSProcessInfo processInfo] disableSuddenTermination];
		
		NSOperation *enabledSuddenTermination = [NSBlockOperation blockOperationWithBlock:^ {
			[[NSProcessInfo processInfo] enableSuddenTermination];
		}];
		[enabledSuddenTermination addDependency:synchronizationOperation];
		[[[NSOperationQueue alloc] init] addOperation:enabledSuddenTermination];
	}];
}

- (void)_synchronize
{
	return [self _synchronizeWithNotifyingQueue:nil];
}

- (void)_synchronizeWithNotifyingQueue:(NSOperationQueue *)notifyingQueue
{
	/*
		Synchronize current updates with disk, get an up-to-date view of the world.
	 */
	__block NSDictionary *updatedUserDefaultsDictionary = nil;
	
	[self _lock:[self accessorLock] criticalSection:^ {
		updatedUserDefaultsDictionary = [NSDictionary dictionaryWithDictionary:[self updatedUserDefaultsDictionary]];
	}];
	
	NSDictionary *userDefaultsDictionary = [self __coordinatedSynchronizeToDisk:updatedUserDefaultsDictionary];
	
	/*
		Find updates to be applied between the actual defaults and the up-to-date one.
	 */
	__block NSDictionary *userDefaultsUpdates = nil;
	
	[self _lock:[self accessorLock] criticalSection:^ {
		userDefaultsUpdates = [self __userDefaultsUpdates:userDefaultsDictionary updatedUserDefaultsDictionary:updatedUserDefaultsDictionary];
	}];
	
	/*
		Apply the updates, notify and set up the new baseline.
	 */
	NSOperation *updatesApplyingOperation = [NSBlockOperation blockOperationWithBlock:^ {
		[self _lock:[self accessorLock] criticalSection:^ {
			[self __applyBaselineAndNotify:userDefaultsDictionary updates:userDefaultsUpdates];
		}];
	}];
	
	if (notifyingQueue != nil) {
		[notifyingQueue addOperation:updatesApplyingOperation];
	}
	else {
		[updatesApplyingOperation start];
	}
	
	[updatesApplyingOperation waitUntilFinished];
}

- (NSDictionary *)__coordinatedSynchronizeToDisk:(NSDictionary *)userDefaultsUpdatesDictionary
{
	NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:self];
	
	__block NSDictionary *userDefaultsDictionary = nil;
	
	[fileCoordinator coordinateWritingItemAtURL:[self userDefaultsDictionaryLocation] options:NSFileCoordinatorWritingForMerging error:NULL byAccessor:^ (NSURL *userDefaultsDictionaryLocation) {
		userDefaultsDictionary = [self __synchronizeToDisk:userDefaultsUpdatesDictionary atLocation:userDefaultsDictionaryLocation];
	}];
	
	return userDefaultsDictionary;
}

/*!
	\brief
	Takes a dictionary of locally updated user defaults. Returns an up-to-date dictionary of user defaults after merging on-disk and local data.
 */
- (NSDictionary *)__synchronizeToDisk:(NSDictionary *)userDefaultsUpdatesDictionary atLocation:(NSURL *)userDefaultsDictionaryLocation
{
	/*
		Get the current user defaults as saved on disk
	 */
	NSData *onDiskUserDefaultsData = [NSData dataWithContentsOfURL:userDefaultsDictionaryLocation options:(NSDataReadingOptions)0 error:NULL];
	
	id onDiskUserDefaults = (onDiskUserDefaultsData != nil) ? [NSPropertyListSerialization propertyListWithData:onDiskUserDefaultsData options:NSPropertyListImmutable format:NULL error:NULL] : nil;
	NSDictionary *onDiskUserDefaultsDictionary = ([onDiskUserDefaults isKindOfClass:[NSDictionary class]] ? onDiskUserDefaults : nil);
	
	NSDictionary *userDefaultsDictionary = [NSDictionary dictionaryWithDictionary:onDiskUserDefaultsDictionary];
	
	/*
		Update with the local values, if needed
	 */
	userDefaultsDictionary = [self _dictionary:userDefaultsDictionary byApplyingChanges:userDefaultsUpdatesDictionary];
	
	/*
		If there are no local updates and we already have a file on disk, simply return the up-to-date on-disk defaults
	 */
	if (([userDefaultsUpdatesDictionary count] == 0) && (onDiskUserDefaults != nil)) {
		return userDefaultsDictionary;
	}
	
	/*
		Safely replace the plist on disk
	 */
	NSData *userDefaultsDictionaryData = [NSPropertyListSerialization dataWithPropertyList:userDefaultsDictionary format:NSPropertyListXMLFormat_v1_0 options:(NSPropertyListWriteOptions)0 error:NULL];
	if (userDefaultsDictionaryData == nil) {
		return nil;
	}
	
	BOOL write = [userDefaultsDictionaryData writeToURL:userDefaultsDictionaryLocation options:NSDataWritingAtomic error:NULL];
	if (!write) {
		return nil;
	}
	
	return userDefaultsDictionary;
}

- (NSDictionary *)__userDefaultsUpdates:(NSDictionary *)userDefaultsDictionary updatedUserDefaultsDictionary:(NSDictionary *)updatedUserDefaultsDictionary
{
	NSMutableDictionary *userDefaultsChanges = [NSMutableDictionary dictionary];
	
	NSSet *userDefaultsUpdatesFromDisk = [self _keyDiffsBetweenDictionaries:userDefaultsDictionary :[self userDefaultsDictionary]];
	
	[userDefaultsUpdatesFromDisk enumerateObjectsUsingBlock:^ (NSString *defaultName, BOOL *stop) {
		id value = [userDefaultsDictionary objectForKey:defaultName] ? : [NSNull null];
		[userDefaultsChanges setObject:value forKey:defaultName];
	}];
	
	[userDefaultsChanges addEntriesFromDictionary:updatedUserDefaultsDictionary];
	
	return userDefaultsChanges;
}

- (void)__applyBaselineAndNotify:(NSDictionary *)userDefaultsDictionary updates:(NSDictionary *)userDefaultsChanges
{
	NSMutableDictionary *mutableUserDefaultsDictionary = [NSMutableDictionary dictionaryWithDictionary:userDefaultsDictionary];
	[self setUserDefaultsDictionary:mutableUserDefaultsDictionary];
	
	NSMutableDictionary *mutableUpdatedUserDefaultsDictionary = [self updatedUserDefaultsDictionary];
	
	[userDefaultsChanges enumerateKeysAndObjectsUsingBlock:^ (NSString *defaultName, id value, BOOL *stop) {
		id currentValue = [mutableUpdatedUserDefaultsDictionary objectForKey:defaultName];
		
		/*
			The value of the updated key has been mutated since we acquired it.
			It will be picked up at the next synchronisation loop.
		 */
		if (currentValue != nil && ![currentValue isEqual:value]) {
			return;
		}
		
		/*
			The default has been updated locally meaning notifications have already been posted.
		 */
		if (currentValue != nil) {
			[mutableUpdatedUserDefaultsDictionary removeObjectForKey:defaultName];
			return;
		}
		
		/*
			Update and notify
		 */
		[self willChangeValueForKey:defaultName];
		[mutableUserDefaultsDictionary setObject:value forKey:defaultName];
		[self didChangeValueForKey:defaultName];
		
		[self _notifyChangeForDefaultName:defaultName value:value];
	}];
}

#pragma mark - Notify

- (void)_notifyChangeForDefaultName:(NSString *)defaultName value:(id)value
{
	NSDictionary *userInfo = @{
		RMSharedUserDefaultsDidChangeDefaultNameKey : defaultName,
		RMSharedUserDefaultsDidChangeDefaulValueKey : value,
	};
	[[NSNotificationCenter defaultCenter] postNotificationName:NSUserDefaultsDidChangeNotification object:self userInfo:userInfo];
}

#pragma mark - Helpers

- (NSSet *)_keyDiffsBetweenDictionaries:(NSDictionary *)dictionary1 :(NSDictionary *)dictionary2
{
	NSMutableSet *updatedKeys = [NSMutableSet set];
	
	[dictionary1 enumerateKeysAndObjectsUsingBlock:^ (id key, id object, BOOL *stop) {
		if (![[dictionary2 objectForKey:key] isEqual:object]) {
			[updatedKeys addObject:key];
		}
	}];
	
	[dictionary2 enumerateKeysAndObjectsUsingBlock:^ (id key, id object, BOOL *stop) {
		if (![[dictionary1 objectForKey:key] isEqual:object]) {
			[updatedKeys addObject:key];
		}
	}];
	
	return updatedKeys;
}

- (NSDictionary *)_dictionary:(NSDictionary *)dictionary byApplyingChanges:(NSDictionary *)changes
{
	NSMutableDictionary *newDictionary = [NSMutableDictionary dictionaryWithDictionary:dictionary];
	
	[changes enumerateKeysAndObjectsUsingBlock:^ (id key, id object, BOOL *stop) {
		if ([object isEqual:[NSNull null]]) {
			[newDictionary removeObjectForKey:key];
			return;
		}
		[newDictionary setObject:object forKey:key];
	}];
	
	return newDictionary;
}

- (void)_lock:(id <NSLocking>)lock criticalSection:(void (^)(void))criticalSection
{
	[lock lock];
	criticalSection();
	[lock unlock];
}

#pragma mark - NSFilePresenter

- (NSURL *)presentedItemURL
{
	return [self userDefaultsDictionaryLocation];
}

- (NSOperationQueue *)presentedItemOperationQueue
{
	return [self fileCoordinationOperationQueue];
}

- (void)presentedItemDidChange
{
	[self _setNeedsSynchronizing];
}

@end

#pragma mark -

@implementation RMSharedUserDefaults (RMNotSupportedOverrides)

- (void)addSuiteNamed:(NSString *)suiteName
{
	[self subclassDoesNotSupportSelector:_cmd];
}

- (void)removeSuiteNamed:(NSString *)suiteName
{
	[self subclassDoesNotSupportSelector:_cmd];
}

- (NSArray *)volatileDomainNames
{
	return nil;
}

- (NSDictionary *)volatileDomainForName:(NSString *)domainName
{
	return nil;
}

- (void)setVolatileDomain:(NSDictionary *)domain forName:(NSString *)domainName
{
	[self subclassDoesNotSupportSelector:_cmd];
}

- (void)removeVolatileDomainForName:(NSString *)domainName
{
	[self subclassDoesNotSupportSelector:_cmd];
}

- (NSArray *)persistentDomainNames
{
	return nil;
}

- (NSDictionary *)persistentDomainForName:(NSString *)domainName
{
	return nil;
}

- (void)setPersistentDomain:(NSDictionary *)domain forName:(NSString *)domainName
{
	[self subclassDoesNotSupportSelector:_cmd];
}

- (void)removePersistentDomainForName:(NSString *)domainName
{
	[self subclassDoesNotSupportSelector:_cmd];
}

- (BOOL)objectIsForcedForKey:(NSString *)key
{
	return NO;
}

- (BOOL)objectIsForcedForKey:(NSString *)key inDomain:(NSString *)domain
{
	return NO;
}

@end
