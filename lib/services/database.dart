import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/post.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('k_photo.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE posts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        autor TEXT,
        conteudo TEXT,
        midia TEXT,
        curtidas INTEGER DEFAULT 0,
        republicacoes INTEGER DEFAULT 0,
        dataPublicacao TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE comentarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        postId INTEGER,
        autor TEXT,
        texto TEXT,
        dataCriacao TEXT,
        FOREIGN KEY (postId) REFERENCES posts (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE liked_posts (
        post_id INTEGER PRIMARY KEY,
        is_liked INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE reposted_posts (
        post_id INTEGER PRIMARY KEY,
        is_reposted INTEGER DEFAULT 0
      )
    ''');
  }

  // Posts
  Future<int> addPost(Post post) async {
    final db = await database;
    return await db.insert('posts', post.toMap());
  }

  Future<List<Post>> getPosts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'posts', 
      orderBy: 'dataPublicacao DESC'
    );
    return List.generate(maps.length, (i) => Post.fromMap(maps[i]));
  }

  Future<int> curtirPost(int id) async {
    final db = await database;
    return await db.rawUpdate(
      'UPDATE posts SET curtidas = curtidas + 1 WHERE id = ?', 
      [id]
    );
  }

  Future<int> republicarPost(int id) async {
    final db = await database;
    return await db.rawUpdate(
      'UPDATE posts SET republicacoes = republicacoes + 1 WHERE id = ?', 
      [id]
    );
  }

  Future<int> descurtirPost(int id) async {
    final db = await database;
    return await db.rawUpdate(
      'UPDATE posts SET curtidas = CASE WHEN curtidas > 0 THEN curtidas - 1 ELSE 0 END WHERE id = ?', 
      [id]
    );
  }

  Future<int> desrepostarPost(int id) async {
    final db = await database;
    return await db.rawUpdate(
      'UPDATE posts SET republicacoes = CASE WHEN republicacoes > 0 THEN republicacoes - 1 ELSE 0 END WHERE id = ?', 
      [id]
    );
  }

  Future<int> updatePost(Post post) async {
    final db = await database;
    return await db.update(
      'posts', 
      post.toMap(),
      where: 'id = ?', 
      whereArgs: [post.id]
    );
  }

  Future<int> deletePost(int id) async {
    final db = await database;
    return await db.delete(
      'posts', 
      where: 'id = ?', 
      whereArgs: [id]
    );
  }

  // Comentários
  Future<int> addComentario(Comentario comentario) async {
    final db = await database;
    return await db.insert('comentarios', comentario.toMap());
  }

  Future<List<Comentario>> getComentarios(int postId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'comentarios', 
      where: 'postId = ?', 
      whereArgs: [postId],
      orderBy: 'dataCriacao ASC'
    );
    return List.generate(maps.length, (i) => Comentario.fromMap(maps[i]));
  }

  // Liked Posts
  Future<void> _ensureLikedPostsTableExists(Database db) async {
    final tableExists = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='liked_posts'"
    );
  
    if (tableExists.isEmpty) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS liked_posts (
          post_id INTEGER PRIMARY KEY,
          is_liked INTEGER DEFAULT 0
        )
      ''');
    }
  }

  Future<void> saveLikedPostState(int postId, bool isLiked) async {
    final db = await database;
  
    // Ensure the table exists
    await _ensureLikedPostsTableExists(db);

    try {
      // Check if the post already exists in liked_posts table
      final existingRecord = await db.query(
        'liked_posts', 
        where: 'post_id = ?', 
        whereArgs: [postId]
      );

      if (existingRecord.isEmpty) {
        // Insert new record if not exists
        await db.insert('liked_posts', {
          'post_id': postId,
          'is_liked': isLiked ? 1 : 0
        });
      } else {
        // Update existing record
        await db.update(
          'liked_posts', 
          {'is_liked': isLiked ? 1 : 0},
          where: 'post_id = ?',
          whereArgs: [postId]
        );
      }
    } catch (e) {
      print('Error saving liked post state: $e');
    }
  }

  Future<Set<int>> getLikedPosts() async {
    final db = await database;
  
    // Ensure the table exists
    await _ensureLikedPostsTableExists(db);

    try {
      final likedPostsRecords = await db.query(
        'liked_posts', 
        where: 'is_liked = 1'
      );

      return likedPostsRecords
        .map((record) => record['post_id'] as int)
        .toSet();
    } catch (e) {
      print('Error getting liked posts: $e');
      return {};
    }
  }

  // Reposted Posts
  Future<void> _ensureRepostedPostsTableExists(Database db) async {
    final tableExists = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='reposted_posts'"
    );
  
    if (tableExists.isEmpty) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS reposted_posts (
          post_id INTEGER PRIMARY KEY,
          is_reposted INTEGER DEFAULT 0
        )
      ''');
    }
  }

  Future<void> saveRepostedPostState(int postId, bool isReposted) async {
    final db = await database;
  
    // Ensure the table exists
    await _ensureRepostedPostsTableExists(db);

    try {
      // Check if the post already exists in reposted_posts table
      final existingRecord = await db.query(
        'reposted_posts', 
        where: 'post_id = ?', 
        whereArgs: [postId]
      );

      if (existingRecord.isEmpty) {
        // Insert new record if not exists
        await db.insert('reposted_posts', {
          'post_id': postId,
          'is_reposted': isReposted ? 1 : 0
        });
      } else {
        // Update existing record
        await db.update(
          'reposted_posts', 
          {'is_reposted': isReposted ? 1 : 0},
          where: 'post_id = ?',
          whereArgs: [postId]
        );
      }
    } catch (e) {
      print('Error saving reposted post state: $e');
    }
  }

  Future<Set<int>> getRepostedPosts() async {
    final db = await database;
  
    // Ensure the table exists
    await _ensureRepostedPostsTableExists(db);

    try {
      final repostedPostsRecords = await db.query(
        'reposted_posts', 
        where: 'is_reposted = 1'
      );

      return repostedPostsRecords
        .map((record) => record['post_id'] as int)
        .toSet();
    } catch (e) {
      print('Error getting reposted posts: $e');
      return {};
    }
  }

  // Fechar banco de dados
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
