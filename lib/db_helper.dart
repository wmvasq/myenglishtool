import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'conversations.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE conversations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            text TEXT
          )
        ''');
      },
    );
  }

  /// Insert a conversation: expects a Map with {title, text(List)}
  Future<int> insertConversation(Map<String, dynamic> conversation) async {
    final dbClient = await db;

    final title = conversation['title'];
    final textJson = jsonEncode(conversation['text']); // only the list
    

    return await dbClient.insert('conversations', {
      'title': title,
      'text': textJson,
    });
  }

  /// Get all conversations (only id + title)
  Future<List<Map<String, dynamic>>> getAllConversations() async {
    final dbClient = await db;
    return await dbClient.query(
      'conversations',
      columns: ['id', 'title','text'],
    );
  }

  /// Get one conversation by ID
  Future<Map<String, dynamic>?> getConversationById(int id) async {
    final dbClient = await db;
    final result = await dbClient.query(
      'conversations',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isEmpty) return null;

    final row = result.first;

    return {
      'id': row['id'],
      'title': row['title'],
      'text': jsonDecode(row['text'] as String), // ← this is List<dynamic>
    };
  }

  /// Update conversation: title + text(list)
  Future<void> updateConversation(int id, Map<String, dynamic> conversation) async {
    final dbClient = await db;

    final title = conversation['title'];
    final textJson = jsonEncode(conversation['text']);

    await dbClient.update(
      'conversations',
      {
        'title': title,
        'text': textJson,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete conversation
  Future<void> deleteConversation(int id) async {
    final dbClient = await db;
    await dbClient.delete(
      'conversations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
