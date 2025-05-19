import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/post.dart';
import '../models/comment.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static const String dbName = 'k_photo.db';

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDatabase();
    return _database!;
  }

  Future<Database> initDatabase() async {
    try {
      final path = join(await getDatabasesPath(), dbName);
      print('Database path: $path');
      
      print('Opening database');
      return await openDatabase(
        path,
        version: 2,
        onCreate: (db, version) async {
          print('onCreate called');
          // Create posts table
          await db.execute('''
            CREATE TABLE posts (
              id TEXT PRIMARY KEY,
              autor TEXT,
              conteudo TEXT,
              midia TEXT,
              curtidas INTEGER DEFAULT 0,
              republicacoes INTEGER DEFAULT 0,
              dataPublicacao TEXT
            )
          ''');
          print('Posts table created');

          // Create comments table 
          await db.execute('''
            CREATE TABLE comments (
              id TEXT PRIMARY KEY,
              post_id TEXT,
              user_id TEXT,
              user_name TEXT,
              content TEXT,
              created_at TEXT,
              FOREIGN KEY (post_id) REFERENCES posts (id)
            )
          ''');
          print('Comments table created');

          // Create additional supporting tables
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
        },
        // Add onUpgrade to handle schema changes without data loss
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            // Perform any necessary schema migrations here
            // For example, adding new columns or tables
            print('Upgrading database from $oldVersion to $newVersion');
          }
        },
      );
    } catch (e) {
      print('Error initializing database: $e');
      rethrow;
    }
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

  // Comentários (new)
  Future<int> addComment(Comment comment) async {
    try {
      final db = await database;
      print('Attempting to add comment: ${comment.toMap()}');
      
      // Verify comments table exists
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='comments';"
      );
      
      if (tables.isEmpty) {
        // Recreate the comments table if it doesn't exist
        await db.execute('''
          CREATE TABLE comments (
            id TEXT PRIMARY KEY,
            post_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            user_name TEXT NOT NULL,
            content TEXT NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (post_id) REFERENCES posts (id)
          )
        ''');
        print('Comments table recreated dynamically');
      }

      // Ensure created_at is always set
      final commentMap = comment.toMap();
      commentMap['created_at'] = DateTime.now().toIso8601String();

      return await db.insert('comments', commentMap);
    } catch (e) {
      print('Error adding comment: $e');
      // Log the full error details
      print('Comment data: ${comment.toMap()}');
      rethrow;
    }
  }

  Future<List<Comment>> getCommentsByPostId(String postId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'comments',
      where: 'post_id = ?',
      whereArgs: [postId],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) {
      return Comment.fromMap(maps[i]);
    });
  }

  Future<int> getCommentCountByPostId(String postId) async {
    final db = await database;
    return Sqflite.firstIntValue(await db.query(
      'comments',
      columns: ['COUNT(*)'],
      where: 'post_id = ?',
      whereArgs: [postId],
    )) ?? 0;
  }

  Future<int> deleteComment(String commentId) async {
    final db = await database;
    return await db.delete(
      'comments', 
      where: 'id = ?', 
      whereArgs: [commentId]
    );
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
