#import <Foundation/Foundation.h>
#import "YapAbstractDatabaseTransaction.h"


@interface YapCollectionsDatabaseReadTransaction : YapAbstractDatabaseTransaction

#pragma mark Count

/**
 * Returns the total number of collections.
 * Each collection may have 1 or more key/object pairs.
**/
- (NSUInteger)numberOfCollections;

/**
 * Returns the total number of keys in the given collection.
 * Returns zero if the collection doesn't exist (or all key/object pairs from the collection have been removed).
**/
- (NSUInteger)numberOfKeysInCollection:(NSString *)collection;

/**
 * Returns the total number of key/object pairs in the entire database (including all collections).
**/
- (NSUInteger)numberOfKeysInAllCollections;

#pragma mark List

/**
 * Returns a list of all collection names.
**/
- (NSArray *)allCollections;

/**
 * Returns a list of all keys in the given collection.
**/
- (NSArray *)allKeysInCollection:(NSString *)collection;

#pragma mark Primitive

/**
 * Primitive access.
 *
 * These are available for in-case you store irregular data
 * that shouldn't go through configured serializer/deserializer.
 *
 * @see objectForKey:collection:
**/
- (NSData *)primitiveDataForKey:(NSString *)key inCollection:(NSString *)collection;

#pragma mark Object

/**
 * Object access.
 * Objects are automatically deserialized using database's configured deserializer.
**/
- (id)objectForKey:(NSString *)key inCollection:(NSString *)collection;

/**
 * Returns whether or not the given key/collection exists in the database.
 * This information is kept in memory, and thus doesn't hit the disk.
**/
- (BOOL)hasObjectForKey:(NSString *)key inCollection:(NSString *)collection;

/**
 * Provides access to both object and metadata in a single call.
 *
 * @return YES if the key exists in the database. NO otherwise, in which case both object and metadata will be nil.
**/
- (BOOL)getObject:(id *)objectPtr metadata:(id *)metadataPtr forKey:(NSString *)key inCollection:(NSString *)collection;

#pragma mark Metadata

/**
 * Provides access to the metadata.
 * This fetches directly from the metadata dictionary stored in memory, and thus never hits the disk.
**/
- (id)metadataForKey:(NSString *)key inCollection:(NSString *)collection;

#pragma mark Enumerate

/**
 * Fast enumeration over all keys in the given collection.
 *
 * This uses a "SELECT key FROM database WHERE collection = ?" operation,
 * and then steps over the results invoking the given block handler.
**/
- (void)enumerateKeysInCollection:(NSString *)collection
                       usingBlock:(void (^)(NSString *key, BOOL *stop))block;

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
                      usingBlock:(void (^)(NSUInteger keyIndex, id metadata, BOOL *stop))block;

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
                     usingBlock:(void (^)(NSUInteger keyIndex, id object, BOOL *stop))block;

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
              usingBlock:(void (^)(NSUInteger keyIndex, id object, id metadata, BOOL *stop))block;

/**
 * Fast enumeration over all keys and associated metadata in the given collection.
 * 
 * This uses a "SELECT key, metadata FROM database WHERE collection = ?" operation and steps over the results.
 * 
 * If you only need to enumerate over certain items (e.g. keys with a particular prefix),
 * consider using the alternative version below which provides a filter,
 * allowing you to skip the deserialization step for those items you're not interested in.
 * 
 * Keep in mind that you cannot modify the collection mid-enumeration (just like any other kind of enumeration).
**/
- (void)enumerateKeysAndMetadataInCollection:(NSString *)collection
                                  usingBlock:(void (^)(NSString *key, id metadata, BOOL *stop))block;

/**
 * Fast enumeration over all keys and associated metadata in the given collection.
 *
 * From the filter block, simply return YES if you'd like the block handler to be invoked for the given key.
 * If the filter block returns NO, then the block handler is skipped for the given key,
 * which avoids the cost associated with deserializing the object.
 * 
 * Keep in mind that you cannot modify the collection mid-enumeration (just like any other kind of enumeration).
**/
- (void)enumerateKeysAndMetadataInCollection:(NSString *)collection
                                 usingFilter:(BOOL (^)(NSString *key))filter
                                       block:(void (^)(NSString *key, id metadata, BOOL *stop))block;


/**
 * Fast enumeration over all key/metadata pairs in all collections.
 * 
 * This uses a "SELECT metadata FROM database ORDER BY collection ASC" operation, and steps over the results.
 * 
 * If you only need to enumerate over certain objects (e.g. keys with a particular prefix),
 * consider using the alternative version below which provides a filter,
 * allowing you to skip the deserialization step for those objects you're not interested in.
 * 
 * Keep in mind that you cannot modify the database mid-enumeration (just like any other kind of enumeration).
**/
- (void)enumerateKeysAndMetadataInAllCollectionsUsingBlock:
                            (void (^)(NSString *collection, NSString *key, id metadata, BOOL *stop))block;

/**
 * Fast enumeration over all key/metadata pairs in all collections.
 *
 * This uses a "SELECT metadata FROM database ORDER BY collection ASC" operation and steps over the results.
 * 
 * From the filter block, simply return YES if you'd like the block handler to be invoked for the given key.
 * If the filter block returns NO, then the block handler is skipped for the given key,
 * which avoids the cost associated with deserializing the object.
 *
 * Keep in mind that you cannot modify the database mid-enumeration (just like any other kind of enumeration).
 **/
- (void)enumerateKeysAndMetadataInAllCollectionsUsingFilter:
                            (BOOL (^)(NSString *collection, NSString *key))filter
					  block:(void (^)(NSString *collection, NSString *key, id metadata, BOOL *stop))block;

/**
 * Fast enumeration over all objects in the database.
 *
 * This uses a "SELECT * from database" operation, and then steps over the results,
 * deserializing each object, and then invoking the given block handler.
 *
 * If you only need to enumerate over certain objects (e.g. keys with a particular prefix),
 * consider using the alternative version below which provides a filter,
 * allowing you to skip the serialization step for those objects you're not interested in.
**/
- (void)enumerateKeysAndObjectsInCollection:(NSString *)collection
                                 usingBlock:(void (^)(NSString *key, id object, id metadata, BOOL *stop))block;

/**
 * Fast enumeration over objects in the database for which you're interested in.
 * The filter block allows you to decide which objects you're interested in.
 *
 * From the filter block, simply return YES if you'd like the block handler to be invoked for the given key.
 * If the filter block returns NO, then the block handler is skipped for the given key,
 * which avoids the cost associated with deserializing the object.
**/
- (void)enumerateKeysAndObjectsInCollection:(NSString *)collection
                                 usingBlock:(void (^)(NSString *key, id object, id metadata, BOOL *stop))block
                                 withFilter:(BOOL (^)(NSString *key, id metadata))filter;

/**
 * Enumerates all key/object pairs in all collections.
 * 
 * The enumeration is sorted by collection. That is, it will enumerate fully over a single collection
 * before moving onto another collection.
 * 
 * If you only need to enumerate over certain objects (e.g. subset of collections, or keys with a particular prefix),
 * consider using the alternative version below which provides a filter,
 * allowing you to skip the serialization step for those objects you're not interested in.
**/
- (void)enumerateKeysAndObjectsInAllCollectionsUsingBlock:
                            (void (^)(NSString *collection, NSString *key, id object, id metadata, BOOL *stop))block;

/**
 * Enumerates all key/object pairs in all collections.
 * The filter block allows you to decide which objects you're interested in.
 *
 * The enumeration is sorted by collection. That is, it will enumerate fully over a single collection
 * before moving onto another collection.
 * 
 * From the filter block, simply return YES if you'd like the block handler to be invoked for the given
 * collection/key pair. If the filter block returns NO, then the block handler is skipped for the given pair,
 * which avoids the cost associated with deserializing the object.
**/
- (void)enumerateKeysAndObjectsInAllCollectionsUsingBlock:
                            (void (^)(NSString *collection, NSString *key, id object, id metadata, BOOL *stop))block
                 withFilter:(BOOL (^)(NSString *collection, NSString *key, id metadata))filter;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface YapCollectionsDatabaseReadWriteTransaction : YapCollectionsDatabaseReadTransaction

#pragma mark Primitive

/**
 * Primitive access.
 *
 * These are available in-case you store irregular data
 * that shouldn't go through configured serializer/deserializer.
 *
 * @see objectForKey:collection:
**/
- (void)setPrimitiveData:(NSData *)data forKey:(NSString *)key inCollection:(NSString *)collection;
- (void)setPrimitiveData:(NSData *)data
                  forKey:(NSString *)key
            inCollection:(NSString *)collection
            withMetadata:(id)metadata;

#pragma mark Object

/**
 * Sets the object for the given key/collection.
 * Objects are automatically serialized using the database's configured serializer.
 * 
 * You may optionally pass metadata about the object.
 * The metadata is kept in memory, within a mutable dictionary, and can be accessed very quickly.
 * The metadata is also written to the database for persistent storage, and thus persists between sessions.
 * Metadata is serialized/deserialized to/from disk just like the object.
**/
- (void)setObject:(id)object forKey:(NSString *)key inCollection:(NSString *)collection;
- (void)setObject:(id)object forKey:(NSString *)key inCollection:(NSString *)collection withMetadata:(id)metadata;

#pragma mark Metadata

/**
 * Updates the metadata, and only the metadata, for the given key/collection.
 * The object for the key doesn't change.
 *
 * Note: If there is no stored object for the given key/collection, this method does nothing.
 * If you pass nil for the metadata, any given metadata associated with the key/colleciton is removed.
**/
- (void)setMetadata:(id)metadata forKey:(NSString *)key inCollection:(NSString *)collection;

#pragma mark Remove

/**
 * Deletes the database row with the given key/collection.
 * This method is automatically called if you invoke
 * setObject:forKey:collection: or setPrimitiveData:forKey:collection: and pass nil object/data.
**/
- (void)removeObjectForKey:(NSString *)key inCollection:(NSString *)collection;

/**
 * Deletes the database rows with the given keys in the given collection.
**/
- (void)removeObjectsForKeys:(NSArray *)keys inCollection:(NSString *)collection;

/**
 * Deletes every key/object pair from the given collection.
 * No trace of the collection will remain afterwards.
**/
- (void)removeAllObjectsInCollection:(NSString *)collection;

/**
 * Removes every key/object pair in the entire database (from all collections).
**/
- (void)removeAllObjectsInAllCollections;

@end
