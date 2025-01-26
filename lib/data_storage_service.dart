import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'dart:math';
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

  // Instance stream controller for binder updates
  final StreamController<bool> binderUpdateController = 
      StreamController<bool>.broadcast();

  // Method to trigger binder update
  void notifyBinderUpdate() {
    print('DataStorageService: Notifying binder update');
    binderUpdateController.add(true);
  }

  // Ensure the controller is closed when no longer needed
  void dispose() {
    binderUpdateController.close();
  }

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
        // Create all necessary tables
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
            updated_at TEXT,
            is_open INTEGER DEFAULT 0
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

        // Create ONLY the first default binder
        await db.insert('binders', {
          'id': '0',
          'slots': '[]',
          'cover_asset': 'assets/capas/capabinder1.png',
          'spine_asset': 'assets/capas/lombadabinder1.png',
          'binder_name': '0',  // Explicitly set binder_name to its ID
          'created_at': DateTime.now().toIso8601String(),
          'is_open': 0,
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
        // If needed, add migration logic here
        // For now, we'll just ensure only one default binder exists
        await db.delete('binders');
        await db.insert('binders', {
          'id': '0',
          'slots': '[]',
          'cover_asset': 'assets/capas/capabinder1.png',
          'spine_asset': 'assets/capas/lombadabinder1.png',
          'binder_name': '0',  // Explicitly set binder_name to its ID
          'created_at': DateTime.now().toIso8601String(),
          'is_open': 0,
        });
      },
    );
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
    
    // Gera um ID base usando timestamp e um número aleatório
    String generateBaseId() {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = Random().nextInt(1000); // Adiciona aleatoriedade
      return '$timestamp$random';
    }

    // Verifica se o ID já existe no banco de dados
    Future<bool> isIdUnique(String id) async {
      final results = await db.query(
        'inventory',
        where: 'instance_id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return results.isEmpty;
    }

    // Gera um ID único
    String uniqueId;
    do {
      uniqueId = generateBaseId();
    } while (!await isIdUnique(uniqueId));

    return uniqueId;
  }

  Future<String> addToInventory(String imagePath, String location,
      {String? binderId, int? slotIndex}) async {
    final db = await database;
    
    // Gerar um instance_id único
    final instanceId = await generateUniqueId(imagePath);

    final id = await db.insert(
      'inventory',
      {
        'instance_id': instanceId,
        'image_path': imagePath,
        'location': location,
        'binder_id': binderId,
        'slot_index': slotIndex,
        'created_at': DateTime.now().toIso8601String(),
      },
    );
    
    return instanceId;
  }

  Future<bool> addToSharedPile(String imagePath) async {
    final db = await database;
    try {
      final currentCount = Sqflite.firstIntValue(await db.rawQuery(
          "SELECT COUNT(*) FROM inventory WHERE location = 'shared_pile'"));

      const int MAX_SHARED_PILE_CARDS = 10; // Defina o limite máximo

      if (currentCount! < MAX_SHARED_PILE_CARDS) {
        await addToInventory(imagePath, 'shared_pile');
        print('Card adicionado ao monte: $imagePath');
        return true;
      } else {
        await addToInventory(imagePath, 'backpack');
        print('Card adicionado à mochila: $imagePath');
        return false;
      }
    } catch (e) {
      print('Erro ao adicionar card: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getSharedPile() async {
    final db = await database;
    final results = await db.query(
      'inventory',
      where: "location = 'shared_pile'",
      columns: ['instance_id', 'image_path'],
    );

    if (results.isEmpty) {
      print('Nenhum card encontrado no monte compartilhado');
    }

    return results;
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

  Future<String> generateUniqueBinderId() async {
    final db = await database;
    final result = await db.query(
      'binders', 
      columns: ['id'], 
      orderBy: 'CAST(id AS INTEGER) DESC', 
      limit: 1
    );

    int lastId = result.isNotEmpty 
      ? int.parse(result.first['id'].toString()) 
      : -1;
    
    return (lastId + 1).toString();
  }

  Future<void> addBinder(String binderId, String slots) async {
    final db = await database;
    
    // Determine cover and spine assets based on the binder ID
    final styleIndex = int.parse(binderId) % 4 + 1;
    final coverAsset = 'assets/capas/capabinder$styleIndex.png';
    final spineAsset = 'assets/capas/lombadabinder$styleIndex.png';

    try {
      // First, check if the binder already exists
      final existingBinder = await db.query(
        'binders', 
        where: 'id = ?', 
        whereArgs: [binderId]
      );

      if (existingBinder.isNotEmpty) {
        // Update existing binder if cover or spine assets are missing
        await db.update(
          'binders', 
          {
            'slots': slots ?? '[]',
            'cover_asset': coverAsset,
            'spine_asset': spineAsset,
            'binder_name': binderId,  // Explicitly set binder_name
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [binderId]
        );
      } else {
        // Insert new binder
        await db.insert('binders', {
          'id': binderId,
          'slots': slots ?? '[]',
          'cover_asset': coverAsset,
          'spine_asset': spineAsset,
          'binder_name': binderId,  // Explicitly set binder_name
          'created_at': DateTime.now().toIso8601String(),
          'is_open': 0,  // Ensure binder starts closed
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      print('Binder processed. ID: $binderId, Cover: $coverAsset, Spine: $spineAsset');
      notifyBinderUpdate();
    } catch (e) {
      print('Error processing binder: $e');
      rethrow;
    }
  }

  Future<String> addNewBinder() async {
    final db = await database;
    
    // Generate a unique binder ID
    final result = await db.query(
      'binders', 
      columns: ['id'], 
      orderBy: 'CAST(id AS INTEGER) DESC', 
      limit: 1
    );

    int lastId = result.isNotEmpty 
      ? int.parse(result.first['id'].toString()) 
      : -1;
    
    final newBinderId = (lastId + 1).toString();

    // Determine cover and spine assets based on the binder ID
    final styleIndex = int.parse(newBinderId) % 4 + 1;
    final coverAsset = 'assets/capas/capabinder$styleIndex.png';
    final spineAsset = 'assets/capas/lombadabinder$styleIndex.png';

    try {
      // Check if a binder with this ID already exists
      final existingBinder = await db.query(
        'binders', 
        where: 'id = ?', 
        whereArgs: [newBinderId]
      );

      if (existingBinder.isNotEmpty) {
        print('Warning: Binder with ID $newBinderId already exists. Overwriting.');
      }

      // Insert new binder
      final insertResult = await db.insert('binders', {
        'id': newBinderId,
        'slots': '[]',
        'cover_asset': coverAsset,
        'spine_asset': spineAsset,
        'binder_name': newBinderId,  // Explicitly set binder_name
        'created_at': DateTime.now().toIso8601String(),
        'is_open': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      print('New Binder Added: ');
      print('ID: $newBinderId');
      print('Cover Asset: $coverAsset');
      print('Spine Asset: $spineAsset');
      print('Insert Result: $insertResult');

      // Verify the binder was added
      final verifyResult = await db.query(
        'binders', 
        where: 'id = ?', 
        whereArgs: [newBinderId]
      );
      print('Verify Result: $verifyResult');

      // Additional verification of all binders
      final allBinders = await db.query('binders');
      print('All Binders after addition:');
      for (var binder in allBinders) {
        print('Binder ID: ${binder['id']}, Cover Asset: ${binder['cover_asset']}');
      }

      notifyBinderUpdate();
      return newBinderId;
    } catch (e) {
      print('Error adding new binder: $e');
      rethrow;
    }
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

  Future<bool> canAddMoreBinders() async {
    final db = await database;
    final binderCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM binders')
    ) ?? 0;

    return binderCount < 15;
  }

  Future<void> updateBinderState(String binderId, bool isOpen) async {
    final db = await database;
    try {
      await db.update(
        'binders', 
        {'is_open': isOpen ? 1 : 0}, 
        where: 'id = ?', 
        whereArgs: [binderId]
      );
      
      // Notificar sobre a atualização do binder
      notifyBinderUpdate();
    } catch (e) {
      print('Erro ao atualizar estado do binder: $e');
      rethrow;
    }
  }

  Future<int> getUserCoins() async {
    final db = await database;
    final result = await db.query('user_balance', limit: 1);
    
    if (result.isEmpty) {
      // Se não existir configuração de usuário, cria com 0 coins
      await db.insert('user_balance', {
        'k_coins': 0
      });
      return 0;
    }
    
    return result.first['k_coins'] as int? ?? 0;
  }

  Future<void> deductUserCoins(int amount) async {
    final db = await database;
    final currentCoins = await getUserCoins();
    
    if (currentCoins < amount) {
      throw Exception('Saldo insuficiente');
    }
    
    await db.update(
      'user_balance', 
      {'k_coins': currentCoins - amount},
      where: '1=1'  // Update all rows
    );
  }

  Future<int> getKCoins() async {
    final balance = await getBalance();
    return balance['k_coins'] ?? 300;
  }

  Future<List<Map<String, dynamic>>> getAllBinders() async {
    final db = await database;
    
    // Retrieve all binders, ordered by ID
    final binders = await db.query(
      'binders', 
      orderBy: 'CAST(id AS INTEGER) ASC'
    );

    print('getAllBinders - Total binders retrieved: ${binders.length}');
    for (var binder in binders) {
      print('Detailed Binder Information:');
      print('ID: ${binder['id']}');
      print('Binder Name: ${binder['binder_name']}');
      print('Cover Asset: ${binder['cover_asset']}');
      print('Spine Asset: ${binder['spine_asset']}');
      print('Slots: ${binder['slots']}');
      print('Created At: ${binder['created_at']}');
      print('Updated At: ${binder['updated_at']}');
      print('Is Open: ${binder['is_open']}');
      print('Keychain Asset: ${binder['keychain_asset']}');
      print('---');
    }

    return binders;
  }

  Future<void> initializeSharedPile() async {
    final db = await database;
    try {
      final existingCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM inventory WHERE location = "shared_pile"'));

      if (existingCount! > 0) {
        print('Cards já existem no monte compartilhado, pulando inicialização');
        return;
      }

      print('Monte compartilhado inicializado vazio');
    } catch (e) {
      print('Erro ao inicializar monte compartilhado: $e');
    }
  }
}
