import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// Manages the local SQLite database for offline caching and sync queue.
///
/// All model data is stored as JSON blobs for simplicity. The sync queue
/// tracks mutations made while offline so they can be replayed when
/// connectivity is restored.
class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  static const String _dbName = 'chefless_cache.db';
  static const int _dbVersion = 1;

  /// Returns the open database, initializing it on first access.
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/$_dbName';

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE recipes (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        authorId TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE schedule_entries (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        kitchenId TEXT,
        date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE shopping_lists (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE notifications (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        endpoint TEXT NOT NULL,
        method TEXT NOT NULL,
        body TEXT,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  // ── Generic CRUD ──────────────────────────────────────────────────────────

  /// Inserts or replaces a row in [table] with the given [id] and JSON [data].
  Future<void> upsert(
    String table,
    String id,
    Map<String, dynamic> data, {
    Map<String, String>? extraColumns,
  }) async {
    final db = await database;
    final row = <String, Object?>{
      'id': id,
      'data': jsonEncode(data),
      ...?extraColumns,
    };

    await db.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Returns the decoded JSON for a single row by [id], or `null`.
  Future<Map<String, dynamic>?> getById(String table, String id) async {
    final db = await database;
    final rows = await db.query(table, where: 'id = ?', whereArgs: [id]);

    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['data'] as String) as Map<String, dynamic>;
  }

  /// Returns all rows from [table] as decoded JSON maps.
  Future<List<Map<String, dynamic>>> getAll(String table) async {
    final db = await database;
    final rows = await db.query(table);

    return rows
        .map((r) =>
            jsonDecode(r['data'] as String) as Map<String, dynamic>)
        .toList();
  }

  /// Returns rows from [table] matching a [where] clause.
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await database;
    final rows = await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
    );

    return rows
        .map((r) =>
            jsonDecode(r['data'] as String) as Map<String, dynamic>)
        .toList();
  }

  /// Deletes a single row by [id].
  Future<void> deleteById(String table, String id) async {
    final db = await database;
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  /// Removes all rows from [table].
  Future<void> clear(String table) async {
    final db = await database;
    await db.delete(table);
  }

  // ── Sync Queue ────────────────────────────────────────────────────────────

  /// Adds an operation to the sync queue for later replay.
  Future<void> addToQueue({
    required String action,
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
  }) async {
    final db = await database;
    await db.insert('sync_queue', {
      'action': action,
      'endpoint': endpoint,
      'method': method,
      'body': body != null ? jsonEncode(body) : null,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Returns all pending sync queue entries, ordered by creation time.
  Future<List<SyncQueueEntry>> getQueue() async {
    final db = await database;
    final rows = await db.query('sync_queue', orderBy: 'id ASC');

    return rows.map(SyncQueueEntry.fromRow).toList();
  }

  /// Removes a successfully synced entry from the queue.
  Future<void> removeFromQueue(int id) async {
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  /// Clears the entire sync queue.
  Future<void> clearQueue() async {
    final db = await database;
    await db.delete('sync_queue');
  }

  /// Closes the database connection.
  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}

/// Represents a single pending sync operation.
class SyncQueueEntry {
  const SyncQueueEntry({
    required this.id,
    required this.action,
    required this.endpoint,
    required this.method,
    this.body,
    required this.createdAt,
  });

  final int id;
  final String action;
  final String endpoint;
  final String method;
  final Map<String, dynamic>? body;
  final String createdAt;

  static SyncQueueEntry fromRow(Map<String, Object?> row) {
    final bodyStr = row['body'] as String?;

    return SyncQueueEntry(
      id: row['id'] as int,
      action: row['action'] as String,
      endpoint: row['endpoint'] as String,
      method: row['method'] as String,
      body: bodyStr != null
          ? jsonDecode(bodyStr) as Map<String, dynamic>
          : null,
      createdAt: row['createdAt'] as String,
    );
  }
}
