import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StoreCard {
  final String imagePath;
  final int price;

  StoreCard({required this.imagePath, required this.price});
}

class DataStorageService {
  static Database? _database;
  static const String dbName = 'photocards.db';
  static const int dbVersion = 10;
  static const int MAX_SHARED_PILE_CARDS = 10;
  static bool _isExecuting = false;
  static Future<void>? _currentOperation;

  Future<T> _executeOperation<T>(Future<T> Function() operation) async {
    while (_isExecuting) {
      await Future.delayed(Duration(milliseconds: 100));
    }

    _isExecuting = true;
    try {
      final result = await operation();
      return result;
    } finally {
      _isExecuting = false;
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    await initDatabase();
    return _database!;
  }

  Future<void> initDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    String path = join(await getDatabasesPath(), dbName);
    bool dbExists = await databaseExists(path);

    _database = await openDatabase(
      path,
      version: dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE shared_pile(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            instance_id TEXT UNIQUE NOT NULL,
            image_path TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE photocards(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            instance_id TEXT UNIQUE NOT NULL,
            image_path TEXT NOT NULL,
            binder_id TEXT,
            slot_index INTEGER,
            page_number INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE store_cards(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            image_path TEXT NOT NULL,
            price INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE binders(
            id TEXT PRIMARY KEY,
            slots TEXT,
            cover_asset TEXT,
            spine_asset TEXT,
            keychain_asset TEXT,
            binder_name TEXT,
            created_at TEXT,
            updated_at TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE backpack(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            instance_id TEXT UNIQUE NOT NULL,
            image_path TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE inventory(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            instance_id TEXT UNIQUE NOT NULL,
            image_path TEXT NOT NULL,
            location TEXT NOT NULL,
            binder_id TEXT,
            slot_index INTEGER,
            page_number INTEGER DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');

        await db.insert('binders', {
          'id': '0',
          'cover_asset': 'assets/capas/capabinder1.png',
          'spine_asset': 'assets/capas/lombadabinder1.png',
          'created_at': DateTime.now().toIso8601String(),
        });

        await db.insert('binders', {
          'id': '1',
          'cover_asset': 'assets/capas/capabinder2.png',
          'spine_asset': 'assets/capas/lombadabinder2.png',
          'created_at': DateTime.now().toIso8601String(),
        });

        await db.insert('binders', {
          'id': '2',
          'cover_asset': 'assets/capas/capabinder3.png',
          'spine_asset': 'assets/capas/lombadabinder3.png',
          'created_at': DateTime.now().toIso8601String(),
        });

        await db.insert('binders', {
          'id': '3',
          'cover_asset': 'assets/capas/capabinder4.png',
          'spine_asset': 'assets/capas/lombadabinder4.png',
          'created_at': DateTime.now().toIso8601String(),
        });

        // Cria a tabela user_balance
        await db.execute('''
          CREATE TABLE user_balance(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            k_coins INTEGER NOT NULL DEFAULT 300,
            star_coins INTEGER NOT NULL DEFAULT 0,
            last_reward_time INTEGER NOT NULL DEFAULT 0
          )
        ''');

        // Insere o registro inicial apenas na criação
        await db.insert('user_balance', {
          'id': 1,
          'k_coins': 300,
          'star_coins': 0,
          'last_reward_time': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        });

        await db.execute('''
          CREATE TABLE IF NOT EXISTS purchased_frames(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            frame_path TEXT NOT NULL UNIQUE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 7) {
          await db.execute('ALTER TABLE binders ADD COLUMN cover_asset TEXT');
          await db.execute('ALTER TABLE binders ADD COLUMN spine_asset TEXT');
          await db.execute('ALTER TABLE binders ADD COLUMN updated_at TEXT');

          await db.update(
              'binders',
              {
                'cover_asset': 'assets/capas/capabinder1.png',
                'spine_asset': 'assets/capas/lombadabinder1.png',
              },
              where: 'id = ?',
              whereArgs: ['0']);

          await db.update(
              'binders',
              {
                'cover_asset': 'assets/capas/capabinder2.png',
                'spine_asset': 'assets/capas/lombadabinder2.png',
              },
              where: 'id = ?',
              whereArgs: ['1']);

          await db.update(
              'binders',
              {
                'cover_asset': 'assets/capas/capabinder3.png',
                'spine_asset': 'assets/capas/lombadabinder3.png',
              },
              where: 'id = ?',
              whereArgs: ['2']);

          await db.update(
              'binders',
              {
                'cover_asset': 'assets/capas/capabinder4.png',
                'spine_asset': 'assets/capas/lombadabinder4.png',
              },
              where: 'id = ?',
              whereArgs: ['3']);
        }

        if (oldVersion < 8) {
          await db
              .execute('ALTER TABLE binders ADD COLUMN keychain_asset TEXT');
          print('Coluna keychain_asset adicionada à tabela binders');
        }

        if (oldVersion < 9) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS user_balance(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              k_coins INTEGER NOT NULL DEFAULT 300,
              star_coins INTEGER NOT NULL DEFAULT 0,
              last_reward_time INTEGER NOT NULL DEFAULT 0
            )
          ''');

          final count = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM user_balance'));
          if (count == 0) {
            await db.insert('user_balance', {
              'id': 1,
              'k_coins': 300,
              'star_coins': 0,
              'last_reward_time': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            });
          }
        }

        if (oldVersion < 10) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS purchased_frames(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              frame_path TEXT NOT NULL UNIQUE
            )
          ''');
        }
      },
    );

    // Verifica se a tabela user_balance existe
    final tables = await _database!.query('sqlite_master',
        where: 'type = ? AND name = ?', whereArgs: ['table', 'user_balance']);

    if (tables.isEmpty) {
      // Se a tabela não existe, cria ela
      await _database!.execute('''
        CREATE TABLE user_balance(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          k_coins INTEGER NOT NULL DEFAULT 300,
          star_coins INTEGER NOT NULL DEFAULT 0,
          last_reward_time INTEGER NOT NULL DEFAULT 0
        )
      ''');

      // Insere o registro inicial
      await _database!.insert('user_balance', {
        'id': 1,
        'k_coins': 300,
        'star_coins': 0,
        'last_reward_time': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });
    }

    // Inicializa o monte compartilhado apenas se o banco foi recém-criado
    if (!dbExists) {
      await initializeSharedPile();
      print('Banco de dados criado e monte inicializado pela primeira vez');
    }
  }

  Future<void> resetDatabase() async {
    final db = await database;
    await db.delete('photocards');
    await db.delete('shared_pile');
    await db.delete('store_cards');
    await initializeSharedPile();
  }

  Future<void> savePhotocardPosition(
      String binderId, int pageNumber, int slotIndex, String? imagePath,
      {String? instanceId}) async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        await txn.delete(
          'inventory',
          where:
              "location = 'binder' AND binder_id = ? AND slot_index = ? AND page_number = ?",
          whereArgs: [binderId, slotIndex, pageNumber],
        );

        if (imagePath != null) {
          if (instanceId == null) {
            instanceId = await addToInventory(
              imagePath,
              'binder',
              binderId: binderId,
              slotIndex: slotIndex,
            );
          }

          await txn.update(
            'inventory',
            {
              'location': 'binder',
              'binder_id': binderId,
              'slot_index': slotIndex,
              'page_number': pageNumber,
              'created_at': DateTime.now().toIso8601String(),
            },
            where: 'instance_id = ?',
            whereArgs: [instanceId],
          );

          print(
              'Photocard salvo no binder: $imagePath (slot: $slotIndex, página: $pageNumber, instanceId: $instanceId)');
        }
      });
    } catch (e) {
      print('Erro ao salvar posição do photocard: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> loadBinderPhotocards(
      String binderId) async {
    final db = await database;
    try {
      final results = await db.query(
        'inventory',
        where: "location = 'binder' AND binder_id = ?",
        whereArgs: [binderId],
        orderBy: 'page_number ASC, slot_index ASC',
      );

      print('Carregando binder $binderId: ${results.length} cards encontrados');
      for (var card in results) {
        print(
            'Página ${card['page_number']}, Slot ${card['slot_index']}: ${card['image_path']} (${card['instance_id']})');
      }

      return results;
    } catch (e) {
      print('Erro ao carregar slots do binder: $e');
      return [];
    }
  }

  Future<bool> isPhotocardInUse(String instanceId) async {
    final db = await database;
    try {
      final result = await db.query(
        'photocards',
        where: 'instance_id = ?',
        whereArgs: [instanceId],
      );
      return result.isNotEmpty;
    } catch (e) {
      print('Erro ao verificar uso do photocard: $e');
      return false;
    }
  }

  Future<void> removeFromSharedPile(String imagePath) async {
    final db = await database;
    await db.delete(
      'shared_pile',
      where: 'image_path = ?',
      whereArgs: [imagePath],
    );
  }

  Future<String> generateUniqueId(String imagePath) async {
    final db = await database;

    // Verifica se já existe um ID para este photocard
    final existingCard = await db.query(
      'inventory',
      where: 'image_path = ?',
      whereArgs: [imagePath],
      orderBy: 'created_at ASC',
      limit: 1,
    );

    // Sempre gera um novo ID único para cada instância do photocard
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  Future<bool> addToSharedPile(String imagePath) async {
    final db = await database;
    try {
      final currentCount = Sqflite.firstIntValue(await db.rawQuery(
          "SELECT COUNT(*) FROM inventory WHERE location = 'shared_pile'"));

      // Gera um ID único para esta instância do photocard
      final instanceId = await generateUniqueId(imagePath);

      if (currentCount! < MAX_SHARED_PILE_CARDS) {
        await db.insert(
          'inventory',
          {
            'instance_id': instanceId,
            'image_path': imagePath,
            'location': 'shared_pile',
            'created_at': DateTime.now().toIso8601String(),
          },
        );
        print('Card adicionado ao monte: $imagePath (instanceId: $instanceId)');
        return true;
      } else {
        await db.insert(
          'inventory',
          {
            'instance_id': instanceId,
            'image_path': imagePath,
            'location': 'backpack',
            'created_at': DateTime.now().toIso8601String(),
          },
        );
        print(
            'Card adicionado à mochila: $imagePath (instanceId: $instanceId)');
        return false;
      }
    } catch (e) {
      print('Erro ao adicionar card: $e');
      return false;
    }
  }

  Future<List<Map<String, String>>> getSharedPile() async {
    final db = await database;
    try {
      final results = await db.query(
        'inventory',
        where: "location = 'shared_pile'",
        columns: ['instance_id', 'image_path'],
      );
      print('Monte compartilhado carregado: ${results.length} cards');

      return results
          .map((row) => {
                'imagePath': row['image_path'] as String,
                'instanceId': row['instance_id'] as String,
              })
          .toList();
    } catch (e) {
      print('Erro ao carregar monte compartilhado: $e');
      return [];
    }
  }

  Future<void> initializeSharedPile() async {
    final db = await database;
    try {
      final existingCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM inventory'));

      if (existingCount! > 0) {
        print('Cards já existem no inventário, pulando inicialização');
        return;
      }

      print('Inventário inicializado vazio');
    } catch (e) {
      print('Erro ao inicializar monte compartilhado: $e');
    }
  }

  Future<void> printDatabaseContent() async {
    final db = await database;
    print('\n=== Conteúdo do Banco de Dados ===');

    final photocards = await db.query('photocards');
    print('Photocards na tabela:');
    for (var card in photocards) {
      print(card);
    }

    final sharedPile = await db.query('shared_pile');
    print('\nMonte compartilhado:');
    for (var card in sharedPile) {
      print(card);
    }

    print('===================================\n');
  }

  Future<void> restoreFullState() async {
    try {
      final db = await database;

      final inventoryCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM inventory'));

      print('Contagem atual de items no inventário: $inventoryCount');

      if (inventoryCount == 0) {
        print('Inventário vazio, inicializando dados pela primeira vez...');
        await initializeSharedPile();
      } else {
        print('Dados existentes encontrados, mantendo estado atual');
      }

      await printAllLocations();
    } catch (e) {
      print('Erro ao restaurar estado: $e');
    }
  }

  Future<String> addPhotocard(String imagePath) async {
    final db = await database;
    final id = await db.insert(
      'photocards',
      {'image_path': imagePath},
    );
    return id.toString();
  }

  Future<String> getPhotocardPath(String id) async {
    final db = await database;
    final results = await db.query(
      'photocards',
      where: 'id = ?',
      whereArgs: [id],
      columns: ['image_path'],
    );

    if (results.isEmpty) {
      throw Exception('Photocard não encontrado');
    }

    return results.first['image_path'] as String;
  }

  Future<List<Map<String, dynamic>>> getStoreCards() async {
    final db = await database;
    return await db.query('store_cards');
  }

  Future<void> addStoreCard(String imagePath, int price) async {
    final db = await database;
    await db.insert(
      'store_cards',
      {
        'image_path': imagePath,
        'price': price,
      },
    );
  }

  Future<void> initializeStore() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM store_cards'),
    );

    if (count == 0) {
      final storeCards = [
        StoreCard(
          imagePath: 'assets/photocards/photocard1.png',
          price: 100,
        ),
        StoreCard(
          imagePath: 'assets/photocards/photocard2.png',
          price: 150,
        ),
      ];

      for (var card in storeCards) {
        await addStoreCard(card.imagePath, card.price);
      }
    }
  }

  Future<void> addBinder(String id, String slots) async {
    final db = await database;
    await db.insert(
      'binders',
      {
        'id': id,
        'slots': slots,
        'created_at': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> getAllBinders() async {
    final db = await database;
    return await db.query('binders');
  }

  Future<void> updateBinderSlots(
      String binderId, List<Map<String, dynamic>> slots) async {
    final db = await database;
    await db.update(
      'binders',
      {'slots': jsonEncode(slots)},
      where: 'id = ?',
      whereArgs: [binderId],
    );
  }

  Future<void> saveBinderState(String binderId, List<String?> slots) async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        await txn.delete(
          'photocards',
          where: 'binder_id = ?',
          whereArgs: [binderId],
        );

        for (int i = 0; i < slots.length; i++) {
          if (slots[i] != null) {
            await txn.insert(
              'photocards',
              {
                'image_path': slots[i],
                'binder_id': binderId,
                'slot_index': i,
                'page_number': 0,
              },
            );
          }
        }
      });
      print('Estado do binder $binderId salvo com sucesso');
    } catch (e) {
      print('Erro ao salvar estado do binder: $e');
      rethrow;
    }
  }

  Future<void> saveSharedPileState(List<String> cards) async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        await txn.delete('shared_pile');

        for (var card in cards) {
          await txn.insert(
            'shared_pile',
            {'image_path': card},
          );
        }
      });
      print('Monte compartilhado salvo com sucesso: ${cards.length} cards');
    } catch (e) {
      print('Erro ao salvar monte compartilhado: $e');
    }
  }

  Future<void> movePhotocardToPile(String imagePath,
      {String? instanceId}) async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        // Gera um novo ID único se não foi fornecido
        final newInstanceId =
            instanceId ?? DateTime.now().millisecondsSinceEpoch.toString();

        // Verifica se há espaço no monte
        final sharedPileCount = Sqflite.firstIntValue(await txn.rawQuery(
            "SELECT COUNT(*) FROM inventory WHERE location = 'shared_pile'"));

        if (sharedPileCount! >= MAX_SHARED_PILE_CARDS) {
          // Se o monte estiver cheio, move um card do monte para a mochila
          await txn.rawUpdate('''
            UPDATE inventory 
            SET location = 'backpack',
                created_at = ?,
                binder_id = NULL,
                slot_index = NULL
            WHERE location = 'shared_pile'
            ORDER BY created_at ASC
            LIMIT 1
          ''', [DateTime.now().toIso8601String()]);
        }

        // Adiciona o novo card ao monte com ID único
        await txn.insert(
          'inventory',
          {
            'instance_id': newInstanceId,
            'image_path': imagePath,
            'location': 'shared_pile',
            'created_at': DateTime.now().toIso8601String(),
          },
        );

        print(
            'Photocard movido para o monte: $imagePath (instanceId: $newInstanceId)');
      });
    } catch (e) {
      print('Erro ao mover photocard para o monte: $e');
    }
  }

  Future<List<Map<String, String>>> getAvailablePhotocards() async {
    final db = await database;
    try {
      final results = await db.query(
        'inventory',
        where: "location = 'backpack' OR location = 'shared_pile'",
        columns: ['instance_id', 'image_path'],
      );

      // Agrupa os cards por image_path e pega o primeiro instance_id de cada grupo
      Map<String, String> uniqueCards = {};
      for (var row in results) {
        String imagePath = row['image_path'] as String;
        String instanceId = row['instance_id'] as String;

        // Mantém apenas a primeira instância de cada imagem
        if (!uniqueCards.containsKey(imagePath)) {
          uniqueCards[imagePath] = instanceId;
        }
      }

      // Converte o mapa em lista de maps
      List<Map<String, String>> groupedCards = uniqueCards.entries
          .map((entry) => {
                'imagePath': entry.key,
                'instanceId': entry.value,
              })
          .toList();

      print('Cards disponíveis (agrupados): ${groupedCards.length}');
      for (var card in groupedCards) {
        print('Card disponível: ${card['imagePath']} (${card['instanceId']})');
      }

      return groupedCards;
    } catch (e) {
      print('Erro ao carregar cards disponíveis: $e');
      return [];
    }
  }

  Future<List<String>> getSharedPileCards() async {
    final db = await database;
    try {
      final results = await db.query('shared_pile');
      final cards = results.map((row) => row['image_path'] as String).toList();
      print('Cards no monte: ${cards.length}');
      return cards;
    } catch (e) {
      print('Erro ao carregar monte: $e');
      return [];
    }
  }

  Future<Map<String, List<String>>> getBackpackPhotocardsCount() async {
    final db = await database;
    try {
      final results = await db.query(
        'inventory',
        where: "location = 'backpack' OR location = 'shared_pile'",
        columns: ['image_path', 'instance_id', 'location'],
      );

      // Mapa que guarda o caminho da imagem e a lista de IDs únicos
      Map<String, List<String>> cardCount = {};

      for (var row in results) {
        String imagePath = row['image_path'] as String;
        String instanceId = row['instance_id'] as String;
        String location = row['location'] as String;

        if (!cardCount.containsKey(imagePath)) {
          cardCount[imagePath] = [];
        }

        // Adiciona o ID à lista de IDs daquela imagem
        cardCount[imagePath]!.add(instanceId);
      }

      print('Contagem de cards disponíveis:');
      cardCount.forEach((path, ids) {
        print('$path: ${ids.length} cards (IDs: ${ids.join(", ")})');
      });

      return cardCount;
    } catch (e) {
      print('Erro ao contar photocards disponíveis: $e');
      return {};
    }
  }

  Future<String> addToInventory(String imagePath, String location,
      {String? binderId, int? slotIndex}) async {
    final db = await database;

    // Verifica se já existe um ID para este photocard
    final existingCard = await db.query(
      'inventory',
      where: 'image_path = ?',
      whereArgs: [imagePath],
      limit: 1,
    );

    // Usa o ID existente ou cria um novo
    final String instanceId;
    if (existingCard.isNotEmpty) {
      instanceId = existingCard.first['instance_id'] as String;
    } else {
      instanceId = DateTime.now().millisecondsSinceEpoch.toString();
    }

    try {
      await db.insert(
        'inventory',
        {
          'instance_id': instanceId,
          'image_path': imagePath,
          'location': location,
          'binder_id': binderId,
          'slot_index': slotIndex,
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      return instanceId;
    } catch (e) {
      print('Erro ao adicionar ao inventário: $e');
      rethrow;
    }
  }

  Future<void> updateCardLocation(String? instanceId, String newLocation,
      {String? binderId, int? slotIndex, int? pageNumber}) async {
    if (instanceId == null || _isExecuting) return;
    _isExecuting = true;

    final db = await database;
    try {
      final timestamp = DateTime.now().toIso8601String();
      await db.update(
        'inventory',
        {
          'location': newLocation,
          'binder_id': binderId,
          'slot_index': slotIndex,
          'page_number': pageNumber,
          'created_at': timestamp,
        },
        where: 'instance_id = ?',
        whereArgs: [instanceId],
      );
    } catch (e) {
      print('Erro ao atualizar localização do card: $e');
    } finally {
      _isExecuting = false;
    }
  }

  Future<void> printInventoryContent() async {
    final db = await database;
    print('\n=== Conteúdo do Inventário ===');

    final inventory = await db.query('inventory');
    print('Total de items no inventário: ${inventory.length}');

    for (var item in inventory) {
      print(
          'ID: ${item['instance_id']}, Path: ${item['image_path']}, Location: ${item['location']}');
    }

    print('===========================\n');
  }

  Future<void> printAllLocations() async {
    final db = await database;
    print('\n=== Estado Atual do Inventário ===');

    final sharedPile = await db.query(
      'inventory',
      where: "location = 'shared_pile'",
    );
    print('Monte compartilhado: ${sharedPile.length} cards');

    final binderCards = await db.query(
      'inventory',
      where: "location = 'binder'",
    );
    print('Cards nos binders: ${binderCards.length}');
    for (var card in binderCards) {
      print(
          'Binder: ${card['binder_id']}, Slot: ${card['slot_index']}, Card: ${card['image_path']}');
    }

    final backpackCards = await db.query(
      'inventory',
      where: "location = 'backpack'",
    );
    print('Cards na mochila: ${backpackCards.length}');

    print('===================================\n');
  }

  Future<void> moveCardBetweenBackpackAndPile(
      String instanceId, String fromLocation) async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        if (fromLocation == 'backpack') {
          // Verifica se há espaço no monte
          final sharedPileCount = Sqflite.firstIntValue(await txn.rawQuery(
              "SELECT COUNT(*) FROM inventory WHERE location = 'shared_pile'"));

          if (sharedPileCount! >= MAX_SHARED_PILE_CARDS) {
            print('Monte cheio, não é possível mover card da mochila');
            return;
          }

          // Pega o caminho da imagem do card que está sendo movido
          final cardResult = await txn.query(
            'inventory',
            columns: ['image_path'],
            where: 'instance_id = ?',
            whereArgs: [instanceId],
          );

          if (cardResult.isNotEmpty) {
            final imagePath = cardResult.first['image_path'] as String;

            // Pega todos os IDs deste card na mochila
            final backpackIds = await txn.query(
              'inventory',
              columns: ['instance_id'],
              where: "location = 'backpack' AND image_path = ?",
              whereArgs: [imagePath],
              orderBy: 'created_at ASC',
            );

            // Encontra o próximo ID não usado
            String? idToMove;
            for (var row in backpackIds) {
              final currentId = row['instance_id'] as String;
              final isUsed = await txn.query(
                'inventory',
                where: "location = 'shared_pile' AND instance_id = ?",
                whereArgs: [currentId],
              );
              if (isUsed.isEmpty) {
                idToMove = currentId;
                break;
              }
            }

            // Move o card com o ID encontrado
            if (idToMove != null) {
              await txn.update(
                'inventory',
                {
                  'location': 'shared_pile',
                  'created_at': DateTime.now().toIso8601String(),
                  'binder_id': null,
                  'slot_index': null,
                },
                where: 'instance_id = ?',
                whereArgs: [idToMove],
              );
              print('Card movido da mochila para o monte (ID: $idToMove)');
            }
          }
        } else {
          // Move do monte para a mochila (mantém o mesmo)
          await txn.update(
            'inventory',
            {
              'location': 'backpack',
              'created_at': DateTime.now().toIso8601String(),
              'binder_id': null,
              'slot_index': null,
            },
            where: 'instance_id = ?',
            whereArgs: [instanceId],
          );
          print('Card movido do monte para a mochila');
        }
      });
    } catch (e) {
      print('Erro ao mover card entre mochila e monte: $e');
    }
  }

  Future<void> updateBinderCovers(
      String binderId, String cover, String spine) async {
    final db = await database;
    try {
      await db.update(
        'binders',
        {
          'cover_asset': cover,
          'spine_asset': spine,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [binderId],
      );
      print('Capas do binder $binderId atualizadas com sucesso');
    } catch (e) {
      print('Erro ao atualizar capas do binder: $e');
    }
  }

  Future<Map<String, String?>> getBinderCovers(String binderId) async {
    final db = await database;
    try {
      final results = await db.query(
        'binders',
        columns: ['cover_asset', 'spine_asset', 'keychain_asset'],
        where: 'id = ?',
        whereArgs: [binderId],
      );

      if (results.isNotEmpty) {
        return {
          'cover': results.first['cover_asset'] as String,
          'spine': results.first['spine_asset'] as String,
          'keychain': results.first['keychain_asset'] as String?,
        };
      }
      // Retorna um mapa vazio em vez de null
      return {
        'cover': 'assets/capas/capabinder1.png', // Capa padrão
        'spine': 'assets/capas/lombadabinder1.png', // Lombada padrão
        'keychain': null,
      };
    } catch (e) {
      print('Erro ao carregar capas do binder: $e');
      // Retorna um mapa vazio em vez de null
      return {
        'cover': 'assets/capas/capabinder1.png', // Capa padrão
        'spine': 'assets/capas/lombadabinder1.png', // Lombada padrão
        'keychain': null,
      };
    }
  }

  Future<void> saveBinderKeychain(String binderId, String keychainPath) async {
    final db = await database;
    try {
      await db.update(
        'binders',
        {
          'keychain_asset': keychainPath,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [binderId],
      );
      print('Keychain do binder $binderId atualizado com sucesso');
    } catch (e) {
      print('Erro ao atualizar keychain do binder: $e');
    }
  }

  Future<void> updateKCoins(int amount) async {
    final db = await database;
    await db.update(
      'user_balance',
      {'k_coins': amount},
      where: 'id = 1',
    );
  }

  Future<void> updateStarCoins(int amount) async {
    final db = await database;
    await db.update(
      'user_balance',
      {'star_coins': amount},
      where: 'id = 1',
    );
  }

  Future<Map<String, int>> getBalance() async {
    final db = await database;
    final result = await db.query('user_balance', where: 'id = 1');
    if (result.isNotEmpty) {
      return {
        'k_coins': result.first['k_coins'] as int,
        'star_coins': result.first['star_coins'] as int,
      };
    }
    return {'k_coins': 300, 'star_coins': 0};
  }

  Future<void> updateLastRewardTime(int timestamp) async {
    final db = await database;
    await db.update(
      'user_balance',
      {'last_reward_time': timestamp},
      where: 'id = 1',
    );
  }

  Future<int> getLastRewardTime() async {
    final db = await database;
    final result = await db.query('user_balance', where: 'id = 1');
    if (result.isNotEmpty) {
      return result.first['last_reward_time'] as int;
    }
    return 0;
  }

  Future<void> addPurchasedFrame(String framePath) async {
    final db = await database;
    try {
      await db.insert('purchased_frames', {'frame_path': framePath},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    } catch (e) {
      print('Erro ao adicionar moldura comprada: $e');
    }
  }

  Future<List<String>> getPurchasedFrames() async {
    final db = await database;
    final results = await db.query('purchased_frames');
    return results.map((row) => row['frame_path'] as String).toList();
  }

  Future<bool> isFramePurchased(String framePath) async {
    final db = await database;
    final result = await db.query(
      'purchased_frames',
      where: 'frame_path = ?',
      whereArgs: [framePath],
    );
    return result.isNotEmpty;
  }

  // Novo método para mover um card específico para o monte
  Future<void> moveSpecificCardToPile(String instanceId) async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        // Verifica se há espaço no monte
        final sharedPileCount = Sqflite.firstIntValue(await txn.rawQuery(
            "SELECT COUNT(*) FROM inventory WHERE location = 'shared_pile'"));

        if (sharedPileCount! >= MAX_SHARED_PILE_CARDS) {
          // Se o monte estiver cheio, move direto para a mochila
          await txn.update(
            'inventory',
            {
              'location': 'backpack',
              'created_at': DateTime.now().toIso8601String(),
              'binder_id': null,
              'slot_index': null,
            },
            where: 'instance_id = ?',
            whereArgs: [instanceId],
          );
          print(
              'Monte cheio: Card movido para a mochila (instanceId: $instanceId)');
        } else {
          // Se houver espaço, move para o monte
          await txn.update(
            'inventory',
            {
              'location': 'shared_pile',
              'created_at': DateTime.now().toIso8601String(),
              'binder_id': null,
              'slot_index': null,
            },
            where: 'instance_id = ?',
            whereArgs: [instanceId],
          );
          print('Card movido para o monte (instanceId: $instanceId)');
        }
      });
    } catch (e) {
      print('Erro ao mover card: $e');
    }
  }

  Future<bool> canChangeUsername() async {
    final db = await database;
    final result = await db.query('username');

    if (result.isEmpty) return true;

    final lastChange = DateTime.parse(result.first['last_change'] as String);
    final now = DateTime.now();
    final difference = now.difference(lastChange).inDays;

    return difference >= 20;
  }

  Future<DateTime?> getNextUsernameChangeDate() async {
    final db = await database;
    final result = await db.query('username');

    if (result.isEmpty) return null;

    final lastChange = DateTime.parse(result.first['last_change'] as String);
    return lastChange.add(Duration(days: 20));
  }

  Future<bool> isUsernameAvailable(String username) async {
    final db = await database;
    final result = await db.query(
      'username',
      where: 'name = ?',
      whereArgs: [username],
    );
    return result.isEmpty;
  }

  Future<bool> setUsername(String username) async {
    final db = await database;
    try {
      await db.insert(
        'username',
        {
          'name': username,
          'last_change': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      print('Erro ao definir username: $e');
      return false;
    }
  }

  Future<String?> getUsername() async {
    final db = await database;
    final result = await db.query('username');
    if (result.isNotEmpty) {
      return result.first['name'] as String;
    }
    return null;
  }

  Future<bool> canMoveToSharedPile() async {
    final db = await database;
    final sharedPileCount = Sqflite.firstIntValue(await db.rawQuery(
        "SELECT COUNT(*) FROM inventory WHERE location = 'shared_pile'"));
    return sharedPileCount! < MAX_SHARED_PILE_CARDS;
  }
}
