#import "YapCollectionsDatabaseTransaction.h"
#import "YapCollectionsDatabasePrivate.h"
#import "YapDatabaseString.h"
#import "YapDatabaseLogging.h"
#import "YapCacheCollectionKey.h"
#import "YapNull.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

/**
 * Define log level for this file: OFF, ERROR, WARN, INFO, VERBOSE
 * See YapDatabaseLogging.h for more information.
**/
#if DEBUG
  static const int ydbFileLogLevel = YDB_LOG_LEVEL_INFO;
#else
  static const int ydbFileLogLevel = YDB_LOG_LEVEL_WARN;
#endif


@implementation YapCollectionsDatabaseReadTransaction

#pragma mark Count

- (NSUInteger)numberOfCollections
{
	__unsafe_unretained YapCollectionsDatabaseConnection *connection =
	    (YapCollectionsDatabaseConnection *)abstractConnection;
	
	sqlite3_stmt *statement = [connection getCollectionCountStatement];
	if (statement == NULL) return 0;
	
	// SELECT COUNT(DISTINCT collection) AS NumberOfRows FROM "database";
	
	NSUInteger result = 0;
	
	int status = sqlite3_step(statement);
	if (status == SQLITE_ROW)
	{
		if (!connection->hasMarkedSqlLevelSharedReadLock)
			[connection markSqlLevelSharedReadLockAcquired];
		
		result = (NSUInteger)sqlite3_column_int64(statement, 0);
	}
	else if (status == SQLITE_ERROR)
	{
		YDBLogError(@"Error executing 'getCollectionCountStatement': %d %s",
		            status, sqlite3_errmsg(connection->db));
	}
	
	sqlite3_reset(statement);
	
	return result;
}

- (NSUInteger)numberOfKeysInCollection:(NSString *)collection
{
	if (collection == nil) collection = @"";
	
	__unsafe_unretained YapCollectionsDatabaseConnection *connection =
	    (YapCollectionsDatabaseConnection *)abstractConnection;
	
	sqlite3_stmt *statement = [connection getKeyCountForCollectionStatement];
	if (statement == NULL) return 0;
	
	// SELECT COUNT(*) AS NumberOfRows FROM "database" WHERE "collection" = ?;
	
	YapDatabaseString _collection; MakeYapDatabaseString(&_collection, collection);
	sqlite3_bind_text(statement, 1, _collection.str, _collection.length, SQLITE_STATIC);
	
	NSUInteger result = 0;
	
	int status = sqlite3_step(statement);
	if (status == SQLITE_ROW)
	{
		if (!connection->hasMarkedSqlLevelSharedReadLock)
			[connection markSqlLevelSharedReadLockAcquired];
		
		result = (NSUInteger)sqlite3_column_int64(statement, 0);
	}
	else if (status == SQLITE_ERROR)
	{
		YDBLogError(@"Error executing 'getKeyCountForCollectionStatement': %d %s",
		            status, sqlite3_errmsg(connection->db));
	}
	
	sqlite3_clear_bindings(statement);
	sqlite3_reset(statement);
	FreeYapDatabaseString(&_collection);
	
	return result;
}

- (NSUInteger)numberOfKeysInAllCollections
{
	__unsafe_unretained YapCollectionsDatabaseConnection *connection =
	    (YapCollectionsDatabaseConnection *)abstractConnection;
	
	sqlite3_stmt *statement = [connection getKeyCountForAllStatement];
	if (statement == NULL) return 0;
	
	// SELECT COUNT(*) AS NumberOfRows FROM "database";
	
	NSUInteger result = 0;
	
	int status = sqlite3_step(statement);
	if (status == SQLITE_ROW)
	{
		if (!connection->hasMarkedSqlLevelSharedReadLock)
			[connection markSqlLevelSharedReadLockAcquired];
		
		result = (NSUInteger)sqlite3_column_int64(statement, 0);
	}
	else if (status == SQLITE_ERROR)
	{
		YDBLogError(@"Error executing 'getKeyCountForAllStatement': %d %s",
		            status, sqlite3_errmsg(connection->db));
	}
	
	sqlite3_reset(statement);
	
	return result;
}

#pragma mark List

- (NSArray *)allCollections
{
	__unsafe_unretained YapCollectionsDatabaseConnection *connection =
	    (YapCollectionsDatabaseConnection *)abstractConnection;
	
	sqlite3_stmt *statement = [connection enumerateCollectionsStatement];
	if (statement == NULL) return nil;
	
	// SELECT DISTINCT "collection" FROM "database";";
	
	NSMutableArray *result = [NSMutableArray array];
	
	while (sqlite3_step(statement) == SQLITE_ROW)
	{
		if (!connection->hasMarkedSqlLevelSharedReadLock)
			[connection markSqlLevelSharedReadLockAcquired];
		
		const unsigned char *_collection = sqlite3_column_text(statement, 0);
		int _collectionSize = sqlite3_column_bytes(statement, 0);
		
		NSString *collection =
		    [[NSString alloc] initWithBytes:_collection length:_collectionSize encoding:NSUTF8StringEncoding];
		
		[result addObject:collection];
	}
	
	sqlite3_reset(statement);
	
	return result;
}

- (NSArray *)allKeysInCollection:(NSString *)collection
{
	if (collection == nil) collection = @"";
	
	__unsafe_unretained YapCollectionsDatabaseConnection *connection =
	    (YapCollectionsDatabaseConnection *)abstractConnection;
	
	sqlite3_stmt *statement = [connection enumerateKeysInCollectionStatement];
	if (statement == NULL) return nil;
	
	// SELECT "key" FROM "database" WHERE collection = ?;
	
	YapDatabaseString _collection; MakeYapDatabaseString(&_collection, collection);
	sqlite3_bind_text(statement, 1, _collection.str, _collection.length, SQLITE_STATIC);
	
	NSMutableArray *result = [NSMutableArray array];
	
	while (sqlite3_step(statement) == SQLITE_ROW)
	{
		if (!connection->hasMarkedSqlLevelSharedReadLock)
			[connection markSqlLevelSharedReadLockAcquired];
		
		const unsigned char *_key = sqlite3_column_text(statement, 0);
		int _keySize = sqlite3_column_bytes(statement, 0);
		
		NSString *key =
		    [[NSString alloc] initWithBytes:_key length:_keySize encoding:NSUTF8StringEncoding];
		
		[result addObject:key];
	}
	
	sqlite3_clear_bindings(statement);
	sqlite3_reset(statement);
	FreeYapDatabaseString(&_collection);
	
	return result;
}

#pragma mark Primitive

- (NSData *)primitiveDataForKey:(NSString *)key inCollection:(NSString *)collection
{
	if (key == nil) return nil;
	if (collection == nil) collection = @"";
	
	__unsafe_unretained YapCollectionsDatabaseConnection *connection =
	    (YapCollectionsDatabaseConnection *)abstractConnection;
	
	sqlite3_stmt *statement = [connection getDataForKeyStatement];
	if (statement == NULL) return nil;
	
	NSData *result = nil;
	
	// SELECT "data" FROM "database" WHERE "collection" = ? AND "key" = ?;
	
	YapDatabaseString _collection; MakeYapDatabaseString(&_collection, collection);
	sqlite3_bind_text(statement, 1, _collection.str, _collection.length, SQLITE_STATIC);
	
	YapDatabaseString _key; MakeYapDatabaseString(&_key, key);
	sqlite3_bind_text(statement, 2, _key.str, _key.length,  SQLITE_STATIC);
	
	int status = sqlite3_step(statement);
	if (status == SQLITE_ROW)
	{
		if (!connection->hasMarkedSqlLevelSharedReadLock)
			[connection markSqlLevelSharedReadLockAcquired];
		
		const void *blob = sqlite3_column_blob(statement, 0);
		int blobSize = sqlite3_column_bytes(statement, 0);
		
		result = [[NSData alloc] initWithBytes:blob length:blobSize];
	}
	else if (status == SQLITE_ERROR)
	{
		YDBLogError(@"Error executing 'getDataForKeyStatement': %d %s, key(%@)",
		                                                    status, sqlite3_errmsg(connection->db), key);
	}
	
	sqlite3_clear_bindings(statement);
	sqlite3_reset(statement);
	FreeYapDatabaseString(&_collection);
	FreeYapDatabaseString(&_key);

	return result;
}

#pragma mark Object

- (id)objectForKey:(NSString *)key inCollection:(NSString *)collection
{
	if (key == nil) return nil;
	if (collection == nil) collection = @"";
	
	__unsafe_unretained YapCollectionsDatabaseConnection *connection =
	    (YapCollectionsDatabaseConnection *)abstractConnection;
	
	YapCacheCollectionKey *cacheKey = [[YapCacheCollectionKey alloc] initWithCollection:collection key:key];
	
	id object = [connection->objectCache objectForKey:cacheKey];
	if (object)
		return object;
	
	sqlite3_stmt *statement = [connection getDataForKeyStatement];
	if (statement == NULL) return nil;
	
	// SELECT "data" FROM "database" WHERE "collection" = ? AND "key" = ?;
	
	YapDatabaseString _collection; MakeYapDatabaseString(&_collection, collection);
	sqlite3_bind_text(statement, 1, _collection.str, _collection.length, SQLITE_STATIC);
	
	YapDatabaseString _key; MakeYapDatabaseString(&_key, key);
	sqlite3_bind_text(statement, 2, _key.str, _key.length, SQLITE_STATIC);
	
	NSData *objectData = nil;
	
	int status = sqlite3_step(statement);
	if (status == SQLITE_ROW)
	{
		if (!connection->hasMarkedSqlLevelSharedReadLock)
			[connection markSqlLevelSharedReadLockAcquired];
		
		const void *blob = sqlite3_column_blob(statement, 0);
		int blobSize = sqlite3_column_bytes(statement, 0);
		
		// Performance tuning:
		//
		// Use initWithBytesNoCopy to avoid an extra allocation and memcpy.
		// But be sure not to call sqlite3_reset until we're done with the data.
		
		objectData = [[NSData alloc] initWithBytesNoCopy:(void *)blob length:blobSize freeWhenDone:NO];
	}
	else if (status == SQLITE_ERROR)
	{
		YDBLogError(@"Error executing 'getDataForKeyStatement': %d %s, key(%@)",
		                                                    status, sqlite3_errmsg(connection->db), key);
	}
	
	object = objectData ? connection.database.objectDeserializer(objectData) : nil;
	
	sqlite3_clear_bindings(statement);
	sqlite3_reset(statement);
	FreeYapDatabaseString(&_collection);
	FreeYapDatabaseString(&_key);
	
	if (object)
		[connection->objectCache setObject:object forKey:cacheKey];
	
	return object;
}

- (BOOL)hasObjectForKey:(NSString *)key inCollection:(NSString *)collection
{
	if (key == nil) return NO;
	if (collection == nil) collection = @"";
	
	__unsafe_unretained YapCollectionsDatabaseConnection *connection =
	    (YapCollectionsDatabaseConnection *)abstractConnection;
	
	// Shortcut:
	// We may not need to query the database if we have the key in any of our caches.
	
	YapCacheCollectionKey *cacheKey = [[YapCacheCollectionKey alloc] initWithCollection:collection key:key];
	
	if ([connection->metadataCache objectForKey:cacheKey]) return YES;
	if ([connection->objectCache objectForKey:cacheKey]) return YES;
	
	// The normal SQL way
	
	sqlite3_stmt *statement = [connection getCountForKeyStatement];
	if (statement == NULL) return NO;
	
	// SELECT COUNT(*) AS NumberOfRows FROM "database" WHERE "collection" = ? AND "key" = ?;
	
	YapDatabaseString _collection; MakeYapDatabaseString(&_collection, collection);
	sqlite3_bind_text(statement, 1, _collection.str, _collection.length, SQLITE_STATIC);
	
	YapDatabaseString _key; MakeYapDatabaseString(&_key, key);
	sqlite3_bind_text(statement, 2, _key.str, _key.length, SQLITE_STATIC);
	
	BOOL result = NO;
	
	int status = sqlite3_step(statement);
	if (status == SQLITE_ROW)
	{
		if (!connection->hasMarkedSqlLevelSharedReadLock)
			[connection markSqlLevelSharedReadLockAcquired];
		
		result = (sqlite3_column_int64(statement, 0) > 0);
	}
	else if (status == SQLITE_ERROR)
	{
		YDBLogError(@"Error executing 'getCountForKeyStatement': %d %s, key(%@)",
		                                                     status, sqlite3_errmsg(connection->db), key);
	}
	
	sqlite3_clear_bindings(statement);
	sqlite3_reset(statement);
	FreeYapDatabaseString(&_collection);
	FreeYapDatabaseString(&_key);
	
	return result;
}

- (BOOL)getObject:(id *)objectPtr metadata:(id *)metadataPtr forKey:(NSString *)key inCollection:(NSString *)collection
{
	if (key == nil)
	{
		if (objectPtr) *objectPtr = nil;
		if (metadataPtr) *metadataPtr = nil;
		
		return NO;
	}
	if (collection == nil) collection = @"";
	
	__unsafe_unretained YapCollectionsDatabaseConnection *connection =
	    (YapCollectionsDatabaseConnection *)abstractConnection;
	
	YapCacheCollectionKey *cacheKey = [[YapCacheCollectionKey alloc] initWithCollection:collection key:key];
	
	id object = [connection->objectCache objectForKey:cacheKey];
	id metadata = [connection->metadataCache objectForKey:cacheKey];
		
	if (object && metadata)
	{
		// Both object and metadata were in cache.
		// Just need to check for empty metadata placeholder from cache.
		if (metadata == [YapNull null])
			metadata = nil;
	}
	else if (!object && metadata)
	{
		// Metadata was in cache.
		// Missing object. Fetch individually.
		object = [self objectForKey:key inCollection:collection];
		
		// And check for empty metadata placeholder from cache.
		if (metadata == [YapNull null])
			metadata = nil;
	}
	else if (object && !metadata)
	{
		// Object was in cache.
		// Missing metadata. Fetch individually.
		metadata = [self metadataForKey:key inCollection:collection];
	}
	else // (!object && !metadata)
	{
		// Both object and metadata are missing.
		// Fetch via query.
		
		sqlite3_stmt *statement = [connection getAllForKeyStatement];
		if (statement)
		{
			// SELECT "data", "metadata" FROM "database" WHERE "collection" = ? AND "key" = ? ;
			
			YapDatabaseString _collection; MakeYapDatabaseString(&_collection, collection);
			sqlite3_bind_text(statement, 1, _collection.str, _collection.length, SQLITE_STATIC);
			
			YapDatabaseString _key; MakeYapDatabaseString(&_key, key);
			sqlite3_bind_text(statement, 2, _key.str, _key.length, SQLITE_STATIC);
			
			NSData *objectData = nil;
			NSData *metadataData = nil;
			
			int status = sqlite3_step(statement);
			if (status == SQLITE_ROW)
			{
				if (!connection->hasMarkedSqlLevelSharedReadLock)
					[connection markSqlLevelSharedReadLockAcquired];
				
				const void *oBlob = sqlite3_column_blob(statement, 0);
				int oBlobSize = sqlite3_column_bytes(statement, 0);
				
				if (oBlobSize > 0)
					objectData = [[NSData alloc] initWithBytesNoCopy:(void *)oBlob
					                                          length:oBlobSize
					                                    freeWhenDone:NO];
				
				const void *mBlob = sqlite3_column_blob(statement, 1);
				int mBlobSize = sqlite3_column_bytes(statement, 1);
				
				if (mBlobSize > 0)
					metadataData = [[NSData alloc] initWithBytesNoCopy:(void *)mBlob
					                                            length:mBlobSize
					                                      freeWhenDone:NO];
			}
			else if (status == SQLITE_ERROR)
			{
				YDBLogError(@"Error executing 'getAllForKeyStatement': %d %s",
				                                                   status, sqlite3_errmsg(connection->db));
			}
			
			if (objectData)
				object = connection.database.objectDeserializer(objectData);
			
			if (object)
				[connection->objectCache setObject:object forKey:cacheKey];
			
			if (metadataData)
				metadata = connection.database.metadataDeserializer(metadataData);
			
			if (metadata)
				[connection->metadataCache setObject:metadata forKey:cacheKey];
			else if (object)
				[connection->metadataCache setObject:[YapNull null] forKey:cacheKey];
			
			sqlite3_clear_bindings(statement);
			sqlite3_reset(statement);
			FreeYapDatabaseString(&_collection);
			FreeYapDatabaseString(&_key);
		}
	}
		
	
	if (objectPtr) *objectPtr = object;
	if (metadataPtr) *metadataPtr = metadata;
	
	return (object != nil || metadata != nil);
}

#pragma mark Metadata

- (id)metadataForKey:(NSString *)key inCollection:(NSString *)collection
{
	if (key == nil) return nil;
	if (collection == nil) collection = @"";
	
	__unsafe_unretained YapCollectionsDatabaseConnection *connection =
	    (YapCollectionsDatabaseConnection *)abstractConnection;
	
	YapCacheCollectionKey *cacheKey = [[YapCacheCollectionKey alloc] initWithCollection:collection key:key];
	
	id metadata = [connection->metadataCache objectForKey:cacheKey];
	if (metadata)
	{
		if (metadata == [YapNull null])
			return nil;
		else
			return metadata;
	}
	
	sqlite3_stmt *statement = [connection getMetadataForKeyStatement];
	if (statement == NULL) return nil;
	
	// SELECT "metadata" FROM "database" WHERE "collection" = ? AND "key" = ? ;
	
	YapDatabaseString _collection; MakeYapDatabaseString(&_collection, collection);
	sqlite3_bind_text(statement, 1, _collection.str, _collection.length, SQLITE_STATIC);
	
	YapDatabaseString _key; MakeYapDatabaseString(&_key, key);
	sqlite3_bind_text(statement, 2, _key.str, _key.length, SQLITE_STATIC);
	
	BOOL found = NO;
	NSData *metadataData = nil;
	
	int status = sqlite3_step(statement);
	if (status == SQLITE_ROW)
	{
		if (!connection->hasMarkedSqlLevelSharedReadLock)
			[connection markSqlLevelSharedReadLockAcquired];
		
		found = YES;
		
		const void *blob = sqlite3_column_blob(statement, 0);
		int blobSize = sqlite3_column_bytes(statement, 0);
		
		// Performance tuning:
		//
		// Use initWithBytesNoCopy to avoid an extra allocation and memcpy.
		// But be sure not to call sqlite3_reset until we're done with the data.
		
		if (blobSize > 0)
			metadataData = [[NSData alloc] initWithBytesNoCopy:(void *)blob length:blobSize freeWhenDone:NO];
	}
	else if (status == SQLITE_ERROR)
	{
		YDBLogError(@"Error executing 'getMetadataForKeyStatement': %d %s",
		                                                        status, sqlite3_errmsg(connection->db));
	}
	
	if (found)
	{
		if (metadataData)
			metadata = connection.database.metadataDeserializer(metadataData);
		
		if (metadata)
			[connection->metadataCache setObject:metadata forKey:cacheKey];
		else
			[connection->metadataCache setObject:[YapNull null] forKey:cacheKey];
	}
	
	sqlite3_clear_bindings(statement);
	sqlite3_reset(statement);
	FreeYapDatabaseString(&_collection);
	FreeYapDatabaseString(&_key);
	
	return metadata;
}

#pragma mark Enumerate

/**
 * Fast enumeration over all keys in the given collection.
 *
 * This uses a "SELECT key FROM database WHERE collection = ?" operation,
 * and then steps over the results invoking the given block handler.
**/
- (void)enumerateKeysInCollection:(NSString *)collection
                       usingBlock:(void (^)(NSString *key, BOOL *stop))block
{
	if (block == NULL) return;
	if (collection == nil) collection = @"";
	
	__unsafe_unretained YapCollectionsDatabaseConnection *connection =
	    (YapCollectionsDatabaseConnection *)abstractConnection;
	
	sqlite3_stmt *statement = [connection enumerateKeysInCollectionStatement];
	if (statement == NULL) return;
	
	// SELECT "key" FROM "database" WHERE collection = ?;
	
	YapDatabaseString _collection; MakeYapDatabaseString(&_collection, collection);
	sqlite3_bind_text(statement, 1, _collection.str, _collection.length, SQLITE_STATIC);
	
	BOOL stop = NO;
	
	while (sqlite3_step(statement) == SQLITE_ROW)
	{
		if (!connection->hasMarkedSqlLevelSharedReadLock)
			[connection markSqlLevelSharedReadLockAcquired];
		
		const unsigned char *_key = sqlite3_column_text(statement, 0);
		int _keySize = sqlite3_column_bytes(statement, 0);
		
		NSString *key = [[NSString alloc] initWithBytes:_key length:_keySize encoding:NSUTF8StringEncoding];
		
		block(key, &stop);
		
		if (stop) break;
	}
	
	sqlite3_clear_bindings(statement);
	sqlite3_reset(statement);
	FreeYapDatabaseString(&_collection);
}

/**
 * Enumerates over the given list of keys (unordered).
 *
 * This method is faster than fetching individual items as it optimizes cache access.
 * That is, it will first enumerate over items in the cache, and then fetch items from the database,
 * thus optimizing the available cache.
 *
 * If any keys are missing from the database, the 'metadata' parameter will be nil.
 *
 * IMPORTANT:
 *     Due to cache optimizations, the items may not be enumerated in the same order as the 'keys' parameter.
 *     That is, items in the cache will be enumerated over first, before fetching items from the database.
**/
- (void)enumerateMetadataForKeys:(NSArray *)keys
                    inCollection:(NSString *)collection
                      usingBlock:(void (^)(NSUInteger keyIndex, id metadata, BOOL *stop))block
{
	if ([keys count] == 0) return;
	if (block == NULL) return;
	if (collection == nil) collection = @"";
	
	__unsafe_unretained YapCollectionsDatabaseConnection *connection =
	    (YapCollectionsDatabaseConnection *)abstractConnection;
	
	NSMutableArray *missingIndexes = [NSMutableArray arrayWithCapacity:[keys count]];
	BOOL stop = NO;
	
	// Check the cache first (to optimize cache)
	
	NSUInteger keyIndex = 0;
	
	for (NSString *key in keys)
	{
		YapCacheCollectionKey *cacheKey = [[YapCacheCollectionKey alloc] initWithCollection:collection key:key];
		
		id metadata = [connection->metadataCache objectForKey:cacheKey];
		if (metadata)
		{
			if (metadata == [YapNull null])
				block(keyIndex, nil, &stop);
			else
				block(keyIndex, metadata, &stop);
			
			if (stop) break;
		}
		else
		{
			[missingIndexes addObject:@(keyIndex)];
		}
		
		keyIndex++;
	}
	
	if (stop || [missingIndexes count] == 0) return;
	
	// Go to database for any missing keys (if needed)
	
	// Sqlite has an upper bound on the number of host parameters that may be used in a single query.
	// We need to watch out for this in case a large array of keys is passed.
	
	NSUInteger maxHostParams = (NSUInteger) sqlite3_limit(connection->db, SQLITE_LIMIT_VARIABLE_NUMBER, -1);
	
	YapDatabaseString _collection; MakeYapDatabaseString(&_collection, collection);
	
	do
	{
		NSUInteger numHostParams = MIN([missingIndexes count], maxHostParams);
		
		// SELECT "key", "metadata" FROM "database" WHERE "collection" = ? AND key IN (?, ?, ...);
		
		NSUInteger capacity = 80 + (numHostParams * 3);
		NSMutableString *query = [NSMutableString stringWithCapacity:capacity];
		
		[query appendString:@"SELECT \"key\", \"metadata\" FROM \"database\""];
		[query appendString:@" WHERE \"collection\" = ? AND \"key\" IN ("];
		
		NSUInteger i;
		for (i = 0; i < numHostParams; i++)
		{
			if (i == 0)
				[query appendFormat:@"?"];
			else
				[query appendFormat:@", ?"];
		}
		
		[query appendString:@");"];
		
		sqlite3_stmt *statement;
		
		int status = sqlite3_prepare_v2(connection->db, [query UTF8String], -1, &statement, NULL);
		if (status != SQLITE_OK)
		{
			YDBLogError(@"Error creating 'metadataForKeys' statement: %d %s",
						status, sqlite3_errmsg(connection->db));
			break; // Break from do/while. Still need to free _collection.
		}
		
		NSMutableDictionary *keyIndexDict = [NSMutableDictionary dictionaryWithCapacity:numHostParams];
		
		sqlite3_bind_text(statement, 1, _collection.str, _collection.length, SQLITE_STATIC);
		
		for (i = 0; i < numHostParams; i++)
		{
			NSNumber *keyIndexNumber = [missingIndexes objectAtIndex:i];
			NSString *key = [keys objectAtIndex:[keyIndexNumber unsignedIntegerValue]];
			
			[keyIndexDict setObject:keyIndexNumber forKey:key];
			
			sqlite3_bind_text(statement, (int)(i + 2), [key UTF8String], -1, SQLITE_TRANSIENT);
		}
		
		while (sqlite3_step(statement) == SQLITE_ROW && !stop)
		{
			if (!connection->hasMarkedSqlLevelSharedReadLock)
				[connection markSqlLevelSharedReadLockAcquired];
			
			const unsigned char *text = sqlite3_column_text(statement, 0);
			int textSize = sqlite3_column_bytes(statement, 0);
			
			const void *blob = sqlite3_column_blob(statement, 1);
			int blobSize = sqlite3_column_bytes(statement, 1);
			
			NSString *key = [[NSString alloc] initWithBytes:text length:textSize encoding:NSUTF8StringEncoding];
			NSUInteger keyIndex = [[keyIndexDict objectForKey:key] unsignedIntegerValue];
			
			NSData *data = [[NSData alloc] initWithBytesNoCopy:(void *)blob length:blobSize freeWhenDone:NO];
			
			id metadata = data ? connection.database.metadataDeserializer(data) : nil;
			
			if (metadata)
			{
				YapCacheCollectionKey *cacheKey = [[YapCacheCollectionKey alloc] initWithCollection:collection key:key];
				
				[connection->metadataCache setObject:metadata forKey:cacheKey];
			}
			
			block(keyIndex, metadata, &stop);
			
			[keyIndexDict removeObjectForKey:key];
		}
		
		sqlite3_finalize(statement);
		statement = NULL;
		
		if (stop) break; // Break from do/while. Still need to free _collection.
		
		// If there are any remaining items in the keyIndexDict,
		// then those items didn't exist in the database.
		
		for (NSNumber *keyIndexNumber in [keyIndexDict objectEnumerator])
		{
			block([keyIndexNumber unsignedIntegerValue], nil, &stop);
			
			if (stop) break;
		}
		
		[missingIndexes removeObjectsInRange:NSMakeRange(0, numHostParams)];
		
	} while (!stop && [missingIndexes count] > 0);
	
	FreeYapDatabaseString(&_collection);
}

/**
 * Enumerates over the given list of keys (unordered).
 *
 * This method is faster than fetching individual items as it optimizes cache access.
 * That is, it will first enumerate over items in the cache, and then fetch items from the database,
 * thus optimizing the available cache.
 *
 * If any keys are missing from the database, the 'object' parameter will be nil.
 *
 * IMPORTANT:
 *     Due to cache optimizations, the items may not be enumerated in the same order as the 'keys' parameter.
 *     That is, items in the cache will be enumerated over first, before fetching items from the database.
**/
- (void)enumerateObjectsForKeys:(NSArray *)keys
                   inCollection:(NSString *)collection
                     usingBlock:(void (^)(NSUInteger keyIndex, id object, BOOL *stop))block
{
	if ([keys count] == 0) return;
	if (block == NULL) return;
	if (collection == nil) collection = @"";
	
	__unsafe_unretained YapCollectionsDatabaseConnection *connection =
	    (YapCollectionsDatabaseConnection *)abstractConnection;
	
	NSMutableArray *missingIndexes = [NSMutableArray arrayWithCapacity:[keys count]];
	BOOL stop = NO;
	
	// Check the cache first (to optimize cache)
	
	NSUInteger keyIndex = 0;
	
	for (NSString *key in keys)
	{
		YapCacheCollectionKey *cacheKey = [[YapCacheCollectionKey alloc] initWithCollection:collection key:key];
		
		id object = [connection->objectCache objectForKey:cacheKey];
		if (object)
		{
			block(keyIndex, object, &stop);
			
			if (stop) break;
		}
		else
		{
			[missingIndexes addObject:@(keyIndex)];
		}
		
		keyIndex++;
	}
	
	if (stop || [missingIndexes count] == 0) return;
	
	// Go to database for any missing keys (if needed)
	
	// Sqlite has an upper bound on the number of host parameters that may be used in a single query.
	// We need to watch out for this in case a large array of keys is passed.
	
	NSUInteger maxHostParams = (NSUInteger) sqlite3_limit(connection->db, SQLITE_LIMIT_VARIABLE_NUMBER, -1);
	
	YapDatabaseString _collection; MakeYapDatabaseString(&_collection, collection);
	
	do
	{
		NSUInteger numHostParams = MIN([missingIndexes count], maxHostParams);
		
		// SELECT "key", "data" FROM "database" WHERE "collection" = ? AND key IN (?, ?, ...);
		
		NSUInteger capacity = 80 + (numHostParams * 3);
		NSMutableString *query = [NSMutableString stringWithCapacity:capacity];
		
		[query appendString:@"SELECT \"key\", \"data\" FROM \"database\""];
		[query appendString:@" WHERE \"collection\" = ? AND \"key\" IN ("];
		
		NSUInteger i;
		for (i = 0; i < numHostParams; i++)
		{
			if (i == 0)
				[query appendFormat:@"?"];
			else
				[query appendFormat:@", ?"];
		}
		
		[query appendString:@");"];
		
		sqlite3_stmt *statement;
		
		int status = sqlite3_prepare_v2(connection->db, [query UTF8String], -1, &statement, NULL);
		if (status != SQLITE_OK)
		{
			YDBLogError(@"Error creating 'objectsForKeys' statement: %d %s",
						status, sqlite3_errmsg(connection->db));
			break; // Break from do/while. Still need to free _collection.
		}
		
		NSMutableDictionary *keyIndexDict = [NSMutableDictionary dictionaryWithCapacity:numHostParams];
		
		sqlite3_bind_text(statement, 1, _collection.str, _collection.length, SQLITE_STATIC);
		
		for (i = 0; i < numHostParams; i++)
		{
			NSNumber *keyIndexNumber = [missingIndexes objectAtIndex:i];
			NSString *key = [keys objectAtIndex:[keyIndexNumber unsignedIntegerValue]];
			
			[keyIndexDict setObject:keyIndexNumber forKey:key];
			
			sqlite3_bind_text(statement, (int)(i + 2), [key UTF8String], -1, SQLITE_TRANSIENT);
		}
		
		while (sqlite3_step(statement) == SQLITE_ROW && !stop)
		{
			if (!connection->hasMarkedSqlLevelSharedReadLock)
				[connection markSqlLevelSharedReadLockAcquired];
			
			const unsigned char *text = sqlite3_column_text(statement, 0);
			int textSize = sqlite3_column_bytes(statement, 0);
			
			const void *blob = sqlite3_column_blob(statement, 1);
			int blobSize = sqlite3_column_bytes(statement, 1);
			
			NSString *key = [[NSString alloc] initWithBytes:text length:textSize encoding:NSUTF8StringEncoding];
			NSUInteger keyIndex = [[keyIndexDict objectForKey:key] unsignedIntegerValue];
			
			NSData *objectData = [[NSData alloc] initWithBytesNoCopy:(void *)blob length:blobSize freeWhenDone:NO];
			
			id object = objectData ? connection.database.objectDeserializer(objectData) : nil;
			
			if (object)
			{
				YapCacheCollectionKey *cacheKey = [[YapCacheCollectionKey alloc] initWithCollection:collection key:key];
				
				[connection->objectCache setObject:object forKey:cacheKey];
			}
			
			block(keyIndex, object, &stop);
			
			[keyIndexDict removeObjectForKey:key];
		}
		
		sqlite3_finalize(statement);
		statement = NULL;
		
		if (stop) break; // Break from do/while. Still need to free _collection.
		
		// If there are any remaining items in the keyIndexDict,
		// then those items didn't exist in the database.
		
		for (NSNumber *keyIndexNumber in [keyIndexDict objectEnumerator])
		{
			block([keyIndexNumber unsignedIntegerValue], nil, &stop);
			
			if (stop) break;
		}
		
		[missingIndexes removeObjectsInRange:NSMakeRange(0, numHostParams)];
		
	} while (!stop && [missingIndexes count] > 0);
	
	FreeYapDatabaseString(&_collection);
}

/**
 * Enumerates over the given list of keys (unordered).
 *
 * This method is faster than fetching individual items as it optimizes cache access.
 * That is, it will first enumerate over items in the cache, and then fetch items from the database,
 * thus optimizing the available cache.
 *
 * If any keys are missing from the database, the 'object' parameter will be nil.
 *
 * IMPORTANT:
 *     Due to cache optimizations, the items may not be enumerated in the same order as the 'keys' parameter.
 *     That is, items in the cache will be enumerated over first, before fetching items from the database.
**/
- (void)enumerateForKeys:(NSArray *)keys
            inCollection:(NSString *)collection
              usingBlock:(void (^)(NSUInteger keyIndex, id object, id metadata, BOOL *stop))block
{
	if ([keys count] == 0) return;
	if (block == NULL) return;
	if (collection == nil) collection = @"";
	
	__unsafe_unretained YapCollectionsDatabaseConnection *connection =
	    (YapCollectionsDatabaseConnection *)abstractConnection;
	
	NSMutableArray *missingIndexes = [NSMutableArray arrayWithCapacity:[keys count]];
	NSMutableArray *keysInObjectCacheOnly = [NSMutableArray arrayWithCapacity:[keys count]];
	NSMutableArray *keysInMetadataCacheOnly = [NSMutableArray arrayWithCapacity:[keys count]];
	
	__block BOOL stop = NO;
	
	// Cache optimization strategy:
	//
	// Some items are in both caches.
	// Some items are only in object cache.
	// Some items are only in metadata cache.
	// Some items are in neither cache.
	//
	// For items only in object cache, we can use enumerateMetadataForKeys:inCollection:usingBlock:.
	// For items only in metadata cache, we can use enumerateObjectsForKeys:inCollection:usingBlock:.
	// For items in neither, we'll have to fetch and deserialize both fields.
	
	NSUInteger keyIndex = 0;
	
	for (NSString *key in keys)
	{
		YapCacheCollectionKey *cacheKey = [[YapCacheCollectionKey alloc] initWithCollection:collection key:key];
		
		id object = [connection->objectCache objectForKey:cacheKey];
		id metadata = [connection->metadataCache objectForKey:cacheKey];
		
		if (object)
		{
			if (metadata)
			{
				if (metadata == [YapNull null])
					block(keyIndex, object, nil, &stop);
				else
					block(keyIndex, object, metadata, &stop);
				
				if (stop) break;
			}
			else
			{
				[keysInObjectCacheOnly addObject:key];
			}
		}
		else if (metadata)
		{
			[keysInMetadataCacheOnly addObject:key];
		}
		else
		{
			[missingIndexes addObject:@(keyIndex)];
		}
		
		keyIndex++;
	}
	
	if (stop) return;
	
	if ([keysInObjectCacheOnly count] > 0)
	{
		// Enumerate over the keys that are in the objectCache, but missing from the metadataCache.
		// That way we only fetch the metadata, minimizing the amount of data read from disk.
		
		[self enumerateMetadataForKeys:keysInObjectCacheOnly
		                  inCollection:collection
		                    usingBlock:^(NSUInteger keyIndex, id metadata, BOOL *subStop){
			
			NSString *key = [keysInObjectCacheOnly objectAtIndex:keyIndex];
			YapCacheCollectionKey *cacheKey = [[YapCacheCollectionKey alloc] initWithCollection:collection key:key];
			
			id object = [connection->objectCache objectForKey:cacheKey];
			
			block(keyIndex, object, metadata, &stop);
			
			if (stop) *subStop = YES;
		}];
	}
	
	if (stop) return;
	
	if ([keysInMetadataCacheOnly count] > 0)
	{
		// Enumerate over the keys that are in the metadataCache, but missing from the objectCache.
		// That way we only fetch the object, minimizing the amount of data read from disk.
		
		[self enumerateObjectsForKeys:keysInMetadataCacheOnly
		                 inCollection:collection
		                   usingBlock:^(NSUInteger keyIndex, id object, BOOL *subStop){
			
			NSString *key = [keysInMetadataCacheOnly objectAtIndex:keyIndex];
			YapCacheCollectionKey *cacheKey = [[YapCacheCollectionKey alloc] initWithCollection:collection key:key];
			
			id metadata = [connection->metadataCache objectForKey:cacheKey];
			
			if (metadata == [YapNull null])
				block(keyIndex, object, nil, &stop);
			else
				block(keyIndex, object, metadata, &stop);
			
			if (stop) *subStop = YES;
		}];
	}
	
	if (stop || [missingIndexes count] == 0) return;
	
	// Go to database for any missing keys (if needed)
	
	// Sqlite has an upper bound on the number of host parameters that may be used in a single query.
	// We need to watch out for this in case a large array of keys is passed.
	
	NSUInteger maxHostParams = (NSUInteger) sqlite3_limit(connection->db, SQLITE_LIMIT_VARIABLE_NUMBER, -1);
	
	YapDatabaseString _collection; MakeYapDatabaseString(&_collection, collection);
	
	do
	{
		NSUInteger numHostParams = MIN([missingIndexes count], maxHostParams);
		
		// SELECT "key", "data", "metadata" FROM "database" WHERE "collection" = ? AND key IN (?, ?, ...);
		
		NSUInteger capacity = 80 + (numHostParams * 3);
		NSMutableString *query = [NSMutableString stringWithCapacity:capacity];
		
		[query appendString:@"SELECT \"key\", \"data\", \"metadata\" FROM \"database\""];
		[query appendString:@" WHERE \"collection\" = ? AND \"key\" IN ("];
		
		NSUInteger i;
		for (i = 0; i < numHostParams; i++)
		{
			if (i == 0)
				[query appendFormat:@"?"];
			else
				[query appendFormat:@", ?"];
		}
		
		[query appendString:@");"];
		
		sqlite3_stmt *statement;
		
		int status = sqlite3_prepare_v2(connection->db, [query UTF8String], -1, &statement, NULL);
		if (status != SQLITE_OK)
		{
			YDBLogError(@"Error creating 'objectsAndMetadataForKeys' statement: %d %s",
						status, sqlite3_errmsg(connection->db));
			break; // Break from do/while. Still need to free _collection.
		}
		
		NSMutableDictionary *keyIndexDict = [NSMutableDictionary dictionaryWithCapacity:numHostParams];
		
		sqlite3_bind_text(statement, 1, _collection.str, _collection.length, SQLITE_STATIC);
		
		for (i = 0; i < numHostParams; i++)
		{
			NSNumber *keyIndexNumber = [missingIndexes objectAtIndex:i];
			NSString *key = [keys objectAtIndex:[keyIndexNumber unsignedIntegerValue]];
			
			[keyIndexDict setObject:keyIndexNumber forKey:key];
			
			sqlite3_bind_text(statement, (int)(i + 2), [key UTF8String], -1, SQLITE_TRANSIENT);
		}
		
		while (sqlite3_step(statement) == SQLITE_ROW && !stop)
		{
			if (!connection->hasMarkedSqlLevelSharedReadLock)
				[connection markSqlLevelSharedReadLockAcquired];
			
			const unsigned char *text = sqlite3_column_text(statement, 0);
			int textSize = sqlite3_column_bytes(statement, 0);
			
			const void *oBlob = sqlite3_column_blob(statement, 1);
			int oBlobSize = sqlite3_column_bytes(statement, 1);
			
			const void *mBlob = sqlite3_column_blob(statement, 2);
			int mBlobSize = sqlite3_column_bytes(statement, 2);
			
			NSString *key = [[NSString alloc] initWithBytes:text length:textSize encoding:NSUTF8StringEncoding];
			NSUInteger keyIndex = [[keyIndexDict objectForKey:key] unsignedIntegerValue];
			
			NSData *oData = nil;
			NSData *mData = nil;
			
			if (oBlobSize > 0)
				oData = [[NSData alloc] initWithBytesNoCopy:(void *)oBlob length:oBlobSize freeWhenDone:NO];
			
			if (mBlobSize > 0)
				mData = [[NSData alloc] initWithBytesNoCopy:(void *)mBlob length:mBlobSize freeWhenDone:NO];
			
			id object = oData ? connection.database.objectDeserializer(oData) : nil;
			id metadata = mData ? connection.database.metadataDeserializer(mData) : nil;
			
			if (object)
			{
				YapCacheCollectionKey *cacheKey = [[YapCacheCollectionKey alloc] initWithCollection:collection key:key];
				
				[connection->objectCache setObject:object forKey:cacheKey];
				
				if (metadata)
					[connection->metadataCache setObject:metadata forKey:cacheKey];
				else
					[connection->metadataCache setObject:[YapNull null] forKey:cacheKey];
			}
			
			block(keyIndex, object, metadata, &stop);
			
			[keyIndexDict removeObjectForKey:key];
		}
		
		sqlite3_finalize(statement);
		statement = NULL;
		
		if (stop) break; // Break from do/while. Still need to free _collection.
		
		// If there are any remaining items in the keyIndexDict,
		// then those items didn't exist in the database.
		
		for (NSNumber *keyIndexNumber in [keyIndexDict objectEnumerator])
		{
			block([keyIndexNumber unsignedIntegerValue], nil, nil, &stop);
			
			if (stop) break;
		}
		
		[missingIndexes removeObjectsInRange:NSMakeRange(0, numHostParams)];
		
	} while (!stop && [missingIndexes count] > 0);
	
	FreeYapDatabaseString(&_collection);
}

- (void)enumerateKeysAndMetadataInCollection:(NSString *)collection
                                  usingBlock:(void (^)(NSString *key, id metadata, BOOL *stop))block
{
	[self enumerateKeysAndMetadataInCollection:collection usingFilter:NULL block:block];
}

- (void)enumerateKeysAndMetadataInCollection:(NSString *)collection
                                 usingFilter:(BOOL (^)(NSString *key))filter
                                       block:(void (^)(NSString *key, id metadata, BOOL *stop))block
{
	if (block == NULL) return;
	if (collection == nil) collection = @"";
	
	__unsafe_unretained YapCollectionsDatabaseConnection *connection =
	    (YapCollectionsDatabaseConnection *)abstractConnection;
	
	sqlite3_stmt *statement = [connection enumerateMetadataInCollectionStatement];
	if (statement == NULL) return;
	
	// SELECT "key", "metadata" FROM "database" WHERE "collection" = ?;
	//
	// Performance tuning:
	// Use initWithBytesNoCopy to avoid an extra allocation and memcpy.
	//
	// Cache considerations:
	// Do we want to add the objects/metadata to the cache here?
	// If the cache is unlimited then we should.
	// But if the cache is limited then we shouldn't. The cache should be reserved for items that are
	// explicitly fetched via objectForKey:. Adding objects to the cache here crowds out the items
	// that are explicitly cached. Plus, if the database has even a small number of objects, then
	// we'll overflow our cache quickly during the enumeration and it won't do any good.
	
	YapDatabaseString _collection; MakeYapDatabaseString(&_collection, collection);
	sqlite3_bind_text(statement, 1, _collection.str, _collection.length, SQLITE_STATIC);
	
	BOOL stop = NO;
	
	while (sqlite3_step(statement) == SQLITE_ROW)
	{
		if (!connection->hasMarkedSqlLevelSharedReadLock)
			[connection markSqlLevelSharedReadLockAcquired];
		
		const unsigned char *text = sqlite3_column_text(statement, 0);
		int textSize = sqlite3_column_bytes(statement, 0);
		
		NSString *key = [[NSString alloc] initWithBytes:text length:textSize encoding:NSUTF8StringEncoding];
		
		BOOL invokeBlock = (filter == NULL) ? YES : filter(key);
		if (invokeBlock)
		{
			YapCacheCollectionKey *cacheKey = [[YapCacheCollectionKey alloc] initWithCollection:collection key:key];
		
			id metadata = [connection->metadataCache objectForKey:cacheKey];
			if (metadata)
			{
				if (metadata == [YapNull null])
					metadata = nil;
			}
			else
			{
				const void *mBlob = sqlite3_column_blob(statement, 1);
				int mBlobSize = sqlite3_column_bytes(statement, 1);
				
				if (mBlobSize > 0)
				{
					NSData *mData = [[NSData alloc] initWithBytesNoCopy:(void *)mBlob length:mBlobSize freeWhenDone:NO];
					metadata = connection.database.metadataDeserializer(mData);
				}
				
				if (connection->metadataCacheLimit == 0 /* unlimited */)
				{
					if (metadata)
						[connection->metadataCache setObject:metadata forKey:cacheKey];
					else
						[connection->metadataCache setObject:[YapNull null] forKey:cacheKey];
				}
			}
			
			block(key, metadata, &stop);
			
			if (stop) break;
		}
	}
	
	sqlite3_clear_bindings(statement);
	sqlite3_reset(statement);
	FreeYapDatabaseString(&_collection);
}

- (void)enumerateKeysAndMetadataInAllCollectionsUsingBlock:
                            (void (^)(NSString *collection, NSString *key, id metadata, BOOL *stop))block
{
	[self enumerateKeysAndMetadataInAllCollectionsUsingFilter:NULL block:block];
}

- (void)enumerateKeysAndMetadataInAllCollectionsUsingFilter:
                            (BOOL (^)(NSString *collection, NSString *key))filter
					  block:(void (^)(NSString *collection, NSString *key, id metadata, BOOL *stop))block
{
	if (block == NULL) return;
	
	__unsafe_unretained YapCollectionsDatabaseConnection *connection =
	    (YapCollectionsDatabaseConnection *)abstractConnection;
	
	sqlite3_stmt *statement = [connection enumerateMetadataInAllCollectionsStatement];
	if (statement == NULL) return;
	
	// SELECT "collection", "key", "metadata" FROM "database" ORDER BY "collection" ASC;
	//
	// Performance tuning:
	// Use initWithBytesNoCopy to avoid an extra allocation and memcpy.
	//
	// Cache considerations:
	// Do we want to add the objects/metadata to the cache here?
	// If the cache is unlimited then we should.
	// But if the cache is limited then we shouldn't. The cache should be reserved for items that are
	// explicitly fetched via objectForKey:. Adding objects to the cache here crowds out the items
	// that are explicitly cached. Plus, if the database has even a small number of objects, then
	// we'll overflow our cache quickly during the enumeration and it won't do any good.
	
	BOOL stop = NO;
	
	while (sqlite3_step(statement) == SQLITE_ROW)
	{
		if (!connection->hasMarkedSqlLevelSharedReadLock)
			[connection markSqlLevelSharedReadLockAcquired];
		
		const unsigned char *_collection = sqlite3_column_text(statement, 0);
		int _collectionSize = sqlite3_column_bytes(statement, 0);
		
		NSString *collection =
		    [[NSString alloc] initWithBytes:_collection length:_collectionSize encoding:NSUTF8StringEncoding];
		
		const unsigned char *_key = sqlite3_column_text(statement, 1);
		int _keySize = sqlite3_column_bytes(statement, 1);
		
		NSString *key =
		    [[NSString alloc] initWithBytes:_key length:_keySize encoding:NSUTF8StringEncoding];
		
		BOOL invokeBlock = (filter == NULL) ? YES : filter(collection, key);
		if (invokeBlock)
		{
			YapCacheCollectionKey *cacheKey = [[YapCacheCollectionKey alloc] initWithCollection:collection key:key];
			
			id metadata = [connection->metadataCache objectForKey:cacheKey];
			if (metadata)
			{
				if (metadata == [YapNull null])
					metadata = nil;
			}
			else
			{
				const void *mBlob = sqlite3_column_blob(statement, 2);
				int mBlobSize = sqlite3_column_bytes(statement, 2);
				
				if (mBlobSize > 0)
				{
					NSData *mData = [[NSData alloc] initWithBytesNoCopy:(void *)mBlob length:mBlobSize freeWhenDone:NO];
					metadata = connection.database.metadataDeserializer(mData);
				}
				
				if (connection->metadataCacheLimit == 0 /* unlimited */)
				{
					if (metadata)
						[connection->metadataCache setObject:metadata forKey:cacheKey];
					else
						[connection->metadataCache setObject:[YapNull null] forKey:cacheKey];
				}
			}
			
			block(collection, key, metadata, &stop);
			
			if (stop) break;
		}
	}
	
	sqlite3_reset(statement);
}

- (void)enumerateKeysAndObjectsInCollection:(NSString *)collection
                                 usingBlock:(void (^)(NSString *key, id object, id metadata, BOOL *stop))block
{
	[self enumerateKeysAndObjectsInCollection:collection usingBlock:block withFilter:NULL];
}

- (void)enumerateKeysAndObjectsInCollection:(NSString *)collection
                                 usingBlock:(void (^)(NSString *key, id object, id metadata, BOOL *stop))block
                                 withFilter:(BOOL (^)(NSString *key, id metadata))filter;
{
	if (block == NULL) return;
	if (collection == nil) collection = @"";
	
	__unsafe_unretained YapCollectionsDatabaseConnection *connection =
	    (YapCollectionsDatabaseConnection *)abstractConnection;
	
	sqlite3_stmt *statement = [connection enumerateAllInCollectionStatement];
	if (statement == NULL) return;
	
	YapCacheCollectionKey *cacheKey = [[YapCacheCollectionKey alloc] initWithCollection:collection key:nil];
	
	// SELECT "key", "data", "metadata" FROM "database" WHERE "collection" = ?;
	//
	// Performance tuning:
	// Use initWithBytesNoCopy to avoid an extra allocation and memcpy.
	//
	// Cache considerations:
	// Do we want to add the objects/metadata to the cache here?
	// If the cache is unlimited then we should.
	// But if the cache is limited then we shouldn't. The cache should be reserved for items that are
	// explicitly fetched via objectForKey:. Adding objects to the cache here crowds out the items
	// that are explicitly cached. Plus, if the database has even a small number of objects, then
	// we'll overflow our cache quickly during the enumeration and it won't do any good.
	
	YapDatabaseString _collection; MakeYapDatabaseString(&_collection, collection);
	sqlite3_bind_text(statement, 1, _collection.str, _collection.length, SQLITE_STATIC);
	
	while (sqlite3_step(statement) == SQLITE_ROW)
	{
		if (!connection->hasMarkedSqlLevelSharedReadLock)
			[connection markSqlLevelSharedReadLockAcquired];
		
		const unsigned char *_key = sqlite3_column_text(statement, 0);
		int _keySize = sqlite3_column_bytes(statement, 0);
		
		NSString *key = [[NSString alloc] initWithBytes:_key length:_keySize encoding:NSUTF8StringEncoding];
		cacheKey.key = key;
		
		id metadata = [connection->metadataCache objectForKey:cacheKey];
		if (metadata)
		{
			if (metadata == [YapNull null])
				metadata = nil;
		}
		else
		{
			const void *mBlob = sqlite3_column_blob(statement, 2);
			int mBlobSize = sqlite3_column_bytes(statement, 2);
			
			if (mBlobSize > 0)
			{
				NSData *mData = [[NSData alloc] initWithBytesNoCopy:(void *)mBlob length:mBlobSize freeWhenDone:NO];
				metadata = connection.database.metadataDeserializer(mData);
			}
			
			if (connection->metadataCacheLimit == 0 /* unlimited */)
			{
				if (metadata)
					[connection->metadataCache setObject:metadata forKey:cacheKey];
				else
					[connection->metadataCache setObject:[YapNull null] forKey:cacheKey];
			}
		}
		
		BOOL invokeBlock = (filter == NULL) ? YES : filter(key, metadata);
		if (invokeBlock)
		{
			id object = [connection->objectCache objectForKey:cacheKey];
			if (object == nil)
			{
				const void *oBlob = sqlite3_column_blob(statement, 1);
				int oBlobSize = sqlite3_column_bytes(statement, 1);
				
				NSData *oData = [[NSData alloc] initWithBytesNoCopy:(void *)oBlob length:oBlobSize freeWhenDone:NO];
				object = connection.database.objectDeserializer(oData);
				
				if (connection->objectCacheLimit == 0 /* unlimited */)
				{
					[connection->objectCache setObject:object forKey:cacheKey];
				}
			}
			
			BOOL stop = NO;
			
			block(key, object, metadata, &stop);
			
			if (stop) break;
		}
	}
	
	sqlite3_clear_bindings(statement);
	sqlite3_reset(statement);
	FreeYapDatabaseString(&_collection);
}

- (void)enumerateKeysAndObjectsInAllCollectionsUsingBlock:
                            (void (^)(NSString *collection, NSString *key, id object, id metadata, BOOL *stop))block
{
	[self enumerateKeysAndObjectsInAllCollectionsUsingBlock:block withFilter:NULL];
}

- (void)enumerateKeysAndObjectsInAllCollectionsUsingBlock:
                            (void (^)(NSString *collection, NSString *key, id object, id metadata, BOOL *stop))block
                 withFilter:(BOOL (^)(NSString *collection, NSString *key, id metadata))filter
{
	if (block == NULL) return;
	
	__unsafe_unretained YapCollectionsDatabaseConnection *connection =
	    (YapCollectionsDatabaseConnection *)abstractConnection;
	
	sqlite3_stmt *statement = [connection enumerateAllInAllCollectionsStatement];
	if (statement == NULL) return;
	
	YapCacheCollectionKey *cacheKey = [[YapCacheCollectionKey alloc] initWithCollection:nil key:nil];
	
	// SELECT "collection", "key", "data", "metadata" FROM "database" ORDER BY \"collection\" ASC;";
	//              0         1       2         3
	
	while (sqlite3_step(statement) == SQLITE_ROW)
	{
		if (!connection->hasMarkedSqlLevelSharedReadLock)
			[connection markSqlLevelSharedReadLockAcquired];
		
		const unsigned char *_collection = sqlite3_column_text(statement, 0);
		int _collectionSize = sqlite3_column_bytes(statement, 0);
		
		const unsigned char *_key = sqlite3_column_text(statement, 1);
		int _keySize = sqlite3_column_bytes(statement, 1);
		
		NSString *collection, *key;
		
		collection = [[NSString alloc] initWithBytes:_collection length:_collectionSize encoding:NSUTF8StringEncoding];
		key = [[NSString alloc] initWithBytes:_key length:_keySize encoding:NSUTF8StringEncoding];
		
		cacheKey.collection = collection;
		cacheKey.key = key;
		
		id metadata = [connection->metadataCache objectForKey:cacheKey];
		if (metadata)
		{
			if (metadata == [YapNull null])
				metadata = nil;
		}
		else
		{
			const void *mBlob = sqlite3_column_blob(statement, 3);
			int mBlobSize = sqlite3_column_bytes(statement, 3);
			
			if (mBlobSize > 0)
			{
				NSData *mData = [[NSData alloc] initWithBytesNoCopy:(void *)mBlob length:mBlobSize freeWhenDone:NO];
				metadata = connection.database.metadataDeserializer(mData);
			}
			
			if (connection->metadataCacheLimit == 0 /* unlimited */)
			{
				if (metadata)
					[connection->metadataCache setObject:metadata forKey:cacheKey];
				else
					[connection->metadataCache setObject:[YapNull null] forKey:cacheKey];
			}
		}
		
		BOOL invokeBlock = (filter == NULL) ? YES : filter(collection, key, metadata);
		if (invokeBlock)
		{
			id object = [connection->objectCache objectForKey:cacheKey];
			if (object == nil)
			{
				const void *oBlob = sqlite3_column_blob(statement, 2);
				int oBlobSize = sqlite3_column_bytes(statement, 2);
				
				NSData *oData = [[NSData alloc] initWithBytesNoCopy:(void *)oBlob length:oBlobSize freeWhenDone:NO];
				object = connection.database.objectDeserializer(oData);
				
				if (connection->objectCacheLimit == 0 /* unlimited */)
				{
					[connection->objectCache setObject:object forKey:cacheKey];
				}
			}
			
			BOOL stop = NO;
			
			block(collection, key, object, metadata, &stop);
			
			if (stop) break;
		}
	}
	
	sqlite3_clear_bindings(statement);
	sqlite3_reset(statement);
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation YapCollectionsDatabaseReadWriteTransaction

#pragma mark Primitive

- (void)setPrimitiveData:(NSData *)data forKey:(NSString *)key inCollection:(NSString *)collection
{
	[self setPrimitiveData:data forKey:key inCollection:collection withMetadata:nil];
}

- (void)setPrimitiveData:(NSData *)data
                  forKey:(NSString *)key
            inCollection:(NSString *)collection
            withMetadata:(id)metadata
{
	if (data == nil)
	{
		[self removeObjectForKey:key inCollection:collection];
		return;
	}
	
	if (key == nil) return;
	if (collection == nil) collection = @"";
	
	__unsafe_unretained YapCollectionsDatabaseConnection *connection =
	    (YapCollectionsDatabaseConnection *)abstractConnection;
	
	sqlite3_stmt *statement = [connection setAllForKeyStatement];
	if (statement == NULL) return;
	
	// INSERT OR REPLACE INTO "database" ("collection", "key", "data", "metadata") VALUES (?, ?, ?, ?);
	//
	// To use SQLITE_STATIC on our data blob, we use the objc_precise_lifetime attribute.
	// This ensures the data isn't released until it goes out of scope.
	
	YapDatabaseString _collection; MakeYapDatabaseString(&_collection, collection);
	sqlite3_bind_text(statement, 1, _collection.str, _collection.length, SQLITE_STATIC);
	
	YapDatabaseString _key; MakeYapDatabaseString(&_key, key);
	sqlite3_bind_text(statement, 2, _key.str, _key.length, SQLITE_STATIC);
	
	sqlite3_bind_blob(statement, 3, data.bytes, data.length, SQLITE_STATIC);
	
	__attribute__((objc_precise_lifetime)) NSData *rawMeta = connection.database.metadataSerializer(metadata);
	sqlite3_bind_blob(statement, 4, rawMeta.bytes, rawMeta.length, SQLITE_STATIC);
	
	int status = sqlite3_step(statement);
	if (status != SQLITE_DONE)
	{
		YDBLogError(@"Error executing 'setAllForKeyStatement': %d %s, key(%@)",
		                                                   status, sqlite3_errmsg(connection->db), key);
	}
	
	sqlite3_clear_bindings(statement);
	sqlite3_reset(statement);
	FreeYapDatabaseString(&_collection);
	FreeYapDatabaseString(&_key);
	
	YapCacheCollectionKey *cacheKey = [[YapCacheCollectionKey alloc] initWithCollection:collection key:key];
	
	[connection->objectCache removeObjectForKey:cacheKey];
	[connection->objectChanges setObject:[YapNull null] forKey:cacheKey];
	
	if (metadata) {
		[connection->metadataCache setObject:metadata forKey:cacheKey];
		[connection->metadataChanges setObject:metadata forKey:cacheKey];
	}
	else {
		[connection->metadataCache setObject:[YapNull null] forKey:cacheKey];
		[connection->metadataChanges setObject:[YapNull null] forKey:cacheKey];
	}
}

#pragma mark Object

- (void)setObject:(id)object forKey:(NSString *)key inCollection:(NSString *)collection
{
	[self setObject:object forKey:key inCollection:collection withMetadata:nil];
}

- (void)setObject:(id)object forKey:(NSString *)key inCollection:(NSString *)collection withMetadata:(id)metadata
{
	if (object == nil)
	{
		[self removeObjectForKey:key inCollection:collection];
		return;
	}
	
	if (key == nil) return;
	if (collection == nil) collection = @"";
	
	__unsafe_unretained YapCollectionsDatabaseConnection *connection =
	    (YapCollectionsDatabaseConnection *)abstractConnection;
	
	sqlite3_stmt *statement = [connection setAllForKeyStatement];
	if (statement == NULL) return;
	
	// INSERT OR REPLACE INTO "database" ("collection", "key", "data", "metadata") VALUES (?, ?, ?, ?);
	// 
	// To use SQLITE_STATIC on our data blob, we use the objc_precise_lifetime attribute.
	// This ensures the data isn't released until it goes out of scope.
	
	YapDatabaseString _collection; MakeYapDatabaseString(&_collection, collection);
	sqlite3_bind_text(statement, 1, _collection.str, _collection.length, SQLITE_STATIC);
	
	YapDatabaseString _key; MakeYapDatabaseString(&_key, key);
	sqlite3_bind_text(statement, 2, _key.str, _key.length, SQLITE_STATIC);
	
	__attribute__((objc_precise_lifetime)) NSData *rawData = connection.database.objectSerializer(object);
	sqlite3_bind_blob(statement, 3, rawData.bytes, rawData.length, SQLITE_STATIC);
	
	__attribute__((objc_precise_lifetime)) NSData *rawMeta = connection.database.metadataSerializer(metadata);
	sqlite3_bind_blob(statement, 4, rawMeta.bytes, rawMeta.length, SQLITE_STATIC);
	
	int status = sqlite3_step(statement);
	if (status != SQLITE_DONE)
	{
		YDBLogError(@"Error executing 'setAllForKeyStatement': %d %s, key(%@)",
		                                                   status, sqlite3_errmsg(connection->db), key);
	}
	
	sqlite3_clear_bindings(statement);
	sqlite3_reset(statement);
	FreeYapDatabaseString(&_collection);
	FreeYapDatabaseString(&_key);
	
	YapCacheCollectionKey *cacheKey = [[YapCacheCollectionKey alloc] initWithCollection:collection key:key];
	
	[connection->objectCache setObject:object forKey:cacheKey];
	[connection->objectChanges setObject:object forKey:cacheKey];
	
	if (metadata) {
		[connection->metadataCache setObject:metadata forKey:cacheKey];
		[connection->metadataChanges setObject:metadata forKey:cacheKey];
	}
	else {
		[connection->metadataCache setObject:[YapNull null] forKey:cacheKey];
		[connection->metadataChanges setObject:[YapNull null] forKey:cacheKey];
	}
}

#pragma mark Metadata

- (void)setMetadata:(id)metadata forKey:(NSString *)key inCollection:(NSString *)collection
{
	if (collection == nil) collection = @"";
	
	if (![self hasObjectForKey:key inCollection:collection]) return;
	
	__unsafe_unretained YapCollectionsDatabaseConnection *connection =
	    (YapCollectionsDatabaseConnection *)abstractConnection;
	
	sqlite3_stmt *statement = [connection setMetaForKeyStatement];
	if (statement == NULL) return;
	
	BOOL updated = YES;
	
	// UPDATE "database" SET "metadata" = ? WHERE "collection" = ? AND "key" = ?;
	//
	// To use SQLITE_STATIC on our data blob, we use the objc_precise_lifetime attribute.
	// This ensures the data isn't released until it goes out of scope.
	
	__attribute__((objc_precise_lifetime)) NSData *rawMeta = connection.database.metadataSerializer(metadata);
	sqlite3_bind_blob(statement, 1, rawMeta.bytes, rawMeta.length, SQLITE_STATIC);
	
	YapDatabaseString _collection; MakeYapDatabaseString(&_collection, collection);
	sqlite3_bind_text(statement, 2, _collection.str, _collection.length, SQLITE_STATIC);
	
	YapDatabaseString _key; MakeYapDatabaseString(&_key, key);
	sqlite3_bind_text(statement, 3, _key.str, _key.length, SQLITE_STATIC);
	
	int status = sqlite3_step(statement);
	if (status != SQLITE_DONE)
	{
		YDBLogError(@"Error executing 'setMetaForKeyStatement': %d %s, key(%@)",
		                                                    status, sqlite3_errmsg(connection->db), key);
		updated = NO;
	}
	
	sqlite3_clear_bindings(statement);
	sqlite3_reset(statement);
	FreeYapDatabaseString(&_collection);
	FreeYapDatabaseString(&_key);
	
	if (updated)
	{
		YapCacheCollectionKey *cacheKey = [[YapCacheCollectionKey alloc] initWithCollection:collection key:key];
		
		if (metadata) {
			[connection->metadataCache setObject:metadata forKey:cacheKey];
			[connection->metadataChanges setObject:metadata forKey:cacheKey];
		}
		else {
			[connection->metadataCache setObject:[YapNull null] forKey:cacheKey];
			[connection->metadataChanges setObject:[YapNull null] forKey:cacheKey];
		}
	}
}

#pragma mark Remove

- (void)removeObjectForKey:(NSString *)key inCollection:(NSString *)collection
{
	if (key == nil) return;
	if (collection == nil) collection  = @"";
	
	__unsafe_unretained YapCollectionsDatabaseConnection *connection =
	    (YapCollectionsDatabaseConnection *)abstractConnection;
	
	sqlite3_stmt *statement = [connection removeForKeyStatement];
	if (statement == NULL) return;
	
	// DELETE FROM 'database' WHERE 'collection' = ? AND 'key' = ?;
	
	YapDatabaseString _collection; MakeYapDatabaseString(&_collection, collection);
	sqlite3_bind_text(statement, 1, _collection.str, _collection.length, SQLITE_STATIC);
	
	YapDatabaseString _key; MakeYapDatabaseString(&_key, key);
	sqlite3_bind_text(statement, 2, _key.str, _key.length, SQLITE_STATIC);
	
	BOOL removed = YES;
	
	int status = sqlite3_step(statement);
	if (status != SQLITE_DONE)
	{
		YDBLogError(@"Error executing 'removeForKeyStatement': %d %s, key(%@)",
		                                                   status, sqlite3_errmsg(connection->db), key);
		removed = NO;
	}
	
	sqlite3_clear_bindings(statement);
	sqlite3_reset(statement);
	FreeYapDatabaseString(&_collection);
	FreeYapDatabaseString(&_key);
	
	if (removed)
	{
		YapCacheCollectionKey *cacheKey = [[YapCacheCollectionKey alloc] initWithCollection:collection key:key];
		
		[connection->objectCache removeObjectForKey:cacheKey];
		[connection->metadataCache removeObjectForKey:cacheKey];
		
		[connection->objectChanges removeObjectForKey:cacheKey];
		[connection->metadataChanges removeObjectForKey:cacheKey];
		[connection->removedKeys addObject:cacheKey];
	}
}

- (void)removeObjectsForKeys:(NSArray *)keys inCollection:(NSString *)collection
{
	if ([keys count] == 0) return;
	
	if ([keys count] == 1)
	{
		[self removeObjectForKey:[keys objectAtIndex:0] inCollection:collection];
		return;
	}
	
	if (collection == nil) collection = @"";
	
	__unsafe_unretained YapCollectionsDatabaseConnection *connection =
	    (YapCollectionsDatabaseConnection *)abstractConnection;
	
	// Sqlite has an upper bound on the number of host parameters that may be used in a single query.
	// We need to watch out for this in case a large array of keys is passed.
	
	NSUInteger maxHostParams = (NSUInteger) sqlite3_limit(connection->db, SQLITE_LIMIT_VARIABLE_NUMBER, -1);
	
	NSUInteger keysIndex = 0;
	NSUInteger keysCount = [keys count];
	
	YapDatabaseString _collection; MakeYapDatabaseString(&_collection, collection);
	
	do
	{
		NSUInteger keysLeft = keysCount - keysIndex;
		NSUInteger numHostParams = MIN(keysLeft, maxHostParams);
		
		// DELETE FROM "database" WHERE "collection" = ? AND "key" IN (?, ?, ...);
	
		NSUInteger capacity = 100 + (numHostParams * 3);
		NSMutableString *query = [NSMutableString stringWithCapacity:capacity];
		
		[query appendString:@"DELETE FROM \"database\" WHERE \"collection\" = ? AND \"key\" IN ("];
		
		NSUInteger i;
		for (i = 0; i < numHostParams; i++)
		{
			if (i == 0)
				[query appendFormat:@"?"];
			else
				[query appendFormat:@", ?"];
		}
		
		[query appendString:@");"];
		
		sqlite3_stmt *statement;
		
		int status = sqlite3_prepare_v2(connection->db, [query UTF8String], -1, &statement, NULL);
		if (status != SQLITE_OK)
		{
			YDBLogError(@"Error creating 'removeKeysInCollection' statement: %d %s",
			                                                             status, sqlite3_errmsg(connection->db));
			break; // Break from do/while. Still need to free _collection.
		}
		
		sqlite3_bind_text(statement, 1, _collection.str, _collection.length, SQLITE_STATIC);
		
		for (i = 0; i < numHostParams; i++)
		{
			NSString *key = [keys objectAtIndex:(keysIndex + i)];
			sqlite3_bind_text(statement, (int)(i + 2), [key UTF8String], -1, SQLITE_TRANSIENT);
		}
		
		status = sqlite3_step(statement);
		if (status != SQLITE_DONE)
		{
			YDBLogError(@"Error executing 'removeKeysInCollection' statement: %d %s",
			                                                              status, sqlite3_errmsg(connection->db));
		}
		
		sqlite3_reset(statement);
		sqlite3_finalize(statement);
		
		keysIndex += numHostParams;
		
	} while (keysIndex < keysCount);
	
	
	FreeYapDatabaseString(&_collection);
	
	// Clear items from cache
	
	for (NSString *key in keys)
	{
		YapCacheCollectionKey *cacheKey = [[YapCacheCollectionKey alloc] initWithCollection:collection key:key];
		
		[connection->objectCache removeObjectForKey:cacheKey];
		[connection->metadataCache removeObjectForKey:cacheKey];
		
		[connection->objectChanges removeObjectForKey:cacheKey];
		[connection->metadataChanges removeObjectForKey:cacheKey];
		[connection->removedKeys addObject:cacheKey];
	}
}

- (void)removeAllObjectsInCollection:(NSString *)collection
{
	if (collection == nil) collection  = @"";
	
	__unsafe_unretained YapCollectionsDatabaseConnection *connection =
	    (YapCollectionsDatabaseConnection *)abstractConnection;
	
	sqlite3_stmt *statement = [connection removeCollectionStatement];
	if (statement == NULL) return;
	
	// DELETE FROM "database" WHERE "collection" = ?;
	
	YapDatabaseString _collection; MakeYapDatabaseString(&_collection, collection);
	sqlite3_bind_text(statement, 1, _collection.str, _collection.length, SQLITE_STATIC);
	
	int status = sqlite3_step(statement);
	if (status != SQLITE_DONE)
	{
		YDBLogError(@"Error executing 'removeCollectionStatement': %d %s, collection(%@)",
		                                                       status, sqlite3_errmsg(connection->db), collection);
	}
	
	sqlite3_clear_bindings(statement);
	sqlite3_reset(statement);
	FreeYapDatabaseString(&_collection);
	
	NSMutableArray *keysToRemove = [NSMutableArray array];
	
	void(^block)(id, BOOL*) = ^void (id key, BOOL *stop) {
		
		__unsafe_unretained YapCacheCollectionKey *cacheKey = (YapCacheCollectionKey *)key;
		if ([cacheKey.collection isEqualToString:collection])
		{
			[keysToRemove addObject:cacheKey];
		}
	};
	
	[connection->objectCache enumerateKeysWithBlock:block];
	[connection->objectCache removeObjectsForKeys:keysToRemove];
	
	[keysToRemove removeAllObjects];
	
	[connection->metadataCache enumerateKeysWithBlock:block];
	[connection->metadataCache removeObjectsForKeys:keysToRemove];
	
	[connection->removedCollections addObject:collection];
}

- (void)removeAllObjectsInAllCollections
{
	__unsafe_unretained YapCollectionsDatabaseConnection *connection =
	    (YapCollectionsDatabaseConnection *)abstractConnection;
	
	sqlite3_stmt *statement = [connection removeAllStatement];
	if (statement == NULL) return;
	
	int status = sqlite3_step(statement);
	if (status != SQLITE_DONE)
	{
		YDBLogError(@"Error executing 'removeAllStatement': %d %s", status, sqlite3_errmsg(connection->db));
	}
	
	sqlite3_reset(statement);
	
	[connection->objectCache removeAllObjects];
	[connection->metadataCache removeAllObjects];
	
	[connection->objectChanges removeAllObjects];
	[connection->metadataChanges removeAllObjects];
	[connection->removedKeys removeAllObjects];
	[connection->removedCollections removeAllObjects];
	connection->allKeysRemoved = YES;
}

@end
