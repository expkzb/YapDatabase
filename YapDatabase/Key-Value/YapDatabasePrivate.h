#import <Foundation/Foundation.h>

#import "YapAbstractDatabasePrivate.h"

#import "YapDatabase.h"
#import "YapDatabaseConnection.h"
#import "YapDatabaseTransaction.h"

#import "sqlite3.h"


@interface YapDatabaseConnection () {
@private
	sqlite3_stmt *getCountStatement;
	sqlite3_stmt *getCountForKeyStatement;
	sqlite3_stmt *getDataForKeyStatement;
	sqlite3_stmt *getMetadataForKeyStatement;
	sqlite3_stmt *getAllForKeyStatement;
	sqlite3_stmt *setMetadataForKeyStatement;
	sqlite3_stmt *setAllForKeyStatement;
	sqlite3_stmt *removeForKeyStatement;
	sqlite3_stmt *removeAllStatement;
	sqlite3_stmt *enumerateKeysStatement;
	sqlite3_stmt *enumerateMetadataStatement;
	sqlite3_stmt *enumerateAllStatement;
	
/* Inherited from YapAbstractDatabaseConnection (see YapAbstractDatabasePrivate.h):
	
@protected
	dispatch_queue_t connectionQueue;
	void *IsOnConnectionQueueKey;
	
	YapAbstractDatabase *database;
	
	NSTimeInterval cacheLastWriteTimestamp;
	
@public
	sqlite3 *db;
	
	id objectCache;   // Either NSMutableDictionary (if unlimited) or YapCache (if limited)
	id metadataCache; // Either NSMutableDictionary (if unlimited) or YapCache (if limited)
	
	NSUInteger objectCacheLimit;          // Read-only by transaction. Use as consideration of whether to add to cache.
	NSUInteger metadataCacheLimit;        // Read-only by transaction. Use as consideration of whether to add to cache.
	
	BOOL hasMarkedSqlLevelSharedReadLock; // Read-only by transaction. Use as consideration of whether to invoke method.
	
	NSMutableSet *changedKeys;
	BOOL allKeysRemoved;	
	
*/
}

- (sqlite3_stmt *)getCountStatement;
- (sqlite3_stmt *)getCountForKeyStatement;
- (sqlite3_stmt *)getDataForKeyStatement;
- (sqlite3_stmt *)getMetadataForKeyStatement;
- (sqlite3_stmt *)getAllForKeyStatement;
- (sqlite3_stmt *)setMetadataForKeyStatement;
- (sqlite3_stmt *)setAllForKeyStatement;
- (sqlite3_stmt *)removeForKeyStatement;
- (sqlite3_stmt *)removeAllStatement;
- (sqlite3_stmt *)enumerateKeysStatement;
- (sqlite3_stmt *)enumerateMetadataStatement;
- (sqlite3_stmt *)enumerateAllStatement;

@end