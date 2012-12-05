# RMSharedPreferences

RMSharedUserDefaults is an NSUserDefaults subclass that supports shared user defaults because multiple sandboxed applications in the same application group.

RMSharedUserDefaults makes use of file coordination to offer coordinated access to a preferences file and change notifications across multiple processes.

It is available as a framework `RMSharedPreferences.framework` to make it easy to plug in to any project.

See this [post](http://realmacsoftware.com/blog/shared-preferences-between-sandboxed-applications) on the Realmac Software blog for more details.

## Sample application

A sample application showing `RMSharedUserDefaults` in action is provided.  
It is compounded of a Main and a Helper target, both being applications. Main is precisely the main application and Helper is a helper application, bundled with the main one under `Contents/Library/LoginItems`.  
Both applications are sandboxed and use the same group identifier for `com.apple.security.application-groups` entitlement (which mean they share a common folder outside of their sandbox under `~/Library/Group Containers/XYZABC1234.com.realmacsoftware.sharedpreferences)`.

Each application has a very simple UI with a single `NSTextField` that is bound, in one way or another to a value in `RMSharedUserDefaults` for a given default key.  
The main application also has a couple of buttons to launch and kill the helper application by using the `SMLoginItemSetEnabled` function from the ServiceManagement framework. This is not actually required and the helper application could well be launched on its own. It just makes things easier!

In order to fully demonstrate the ease of use of `RMSharedUserDefaults`, both applications observe the user default changes in a slightly different way:

- The main application creates an `NSUserDefaultsController` instance with `[RMSharedUserDefaults standardUserDefaults]` and binds the text field value to the appropriate default key in Interface Builder.
- The helper application observes for `NSUserDefaultsDidChangeNotification` notifications on `[RMSharedUserDefaults standardUserDefaults]` and appropriately updates the text field’s value by inspecting the userInfo dictionary and interfering the changed value.

When clicking the Save button (or simply hitting Return in the text field) will set the user default’s value and trigger a sync. As you can see, the value in the text field is kept in sync between both applications.

## Notes

It is important noting that even though persisted user defaults are shared between applications, registered defaults are not written to disk and are therefore local to each application.   
Similarly to `NSUserDefaults` they are also not persisted across launches.

```
- (void)registerDefaults:(NSDictionary *)registrationDictionary;
```

Also, the following methods from `NSUserDefaults` are not supported in `RMSharedUserDefaults`.

```
- (void)addSuiteNamed:(NSString *)suiteName;
- (void)removeSuiteNamed:(NSString *)suiteName;

- (NSArray *)volatileDomainNames;
- (NSDictionary *)volatileDomainForName:(NSString *)domainName;
- (void)setVolatileDomain:(NSDictionary *)domain forName:(NSString *)domainName;
- (void)removeVolatileDomainForName:(NSString *)domainName;

- (NSArray *)persistentDomainNames;
- (NSDictionary *)persistentDomainForName:(NSString *)domainName;
- (void)setPersistentDomain:(NSDictionary *)domain forName:(NSString *)domainName;
- (void)removePersistentDomainForName:(NSString *)domainName;

- (BOOL)objectIsForcedForKey:(NSString *)key;
- (BOOL)objectIsForcedForKey:(NSString *)key inDomain:(NSString *)domain;
```

Getters will return `nil`, `0` or `NO` based on the return type and setters will throw an exception.

## Requirements

- OS X 10.8.0 or above
- LLVM Compiler 4.0 and above

Both the framework and the sample application use ARC.

## Contact

Please contact [Damien](mailto:damien@realmacsoftware.com) regarding this project.

## License

See the LICENSE file for more info.