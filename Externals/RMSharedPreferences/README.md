```
- (void)registerDefaults:(NSDictionary *)registrationDictionary;
```

The contents of the registered defaults are not written to disk; you need to call this method each time your application starts.
The contents of the registered defaults are also local only which mean defaults registered in one process will not be seen by another process in the application group.


The following methods from NSUserDefaults are not supported. Getters will return nil, 0 or NO based on the return type and setters will throw an exception.

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