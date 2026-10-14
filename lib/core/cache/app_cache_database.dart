import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_cache_database.g.dart';

/// SQLite database used for reusable GET-response caching.
///
/// Only cache metadata and serialized successful responses are stored here.
/// Authentication tokens are never stored in this database.
class CacheEntries extends Table {
  TextColumn get cacheKey => text()();
  TextColumn get accountKey => text().nullable()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => <Column>{cacheKey};
}

@DriftDatabase(tables: <Type>[CacheEntries])
class AppCacheDatabase extends _$AppCacheDatabase {
  AppCacheDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) async {
          await migrator.createAll();
        },
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            try {
              await customStatement(
                'ALTER TABLE cache_entries DROP COLUMN ttl_seconds;',
              );
            } on Object {
              // Older SQLite builds may not support DROP COLUMN. These installs
              // keep the unused extra column and v2 code simply ignores it.
            }
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'app_api_cache.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
