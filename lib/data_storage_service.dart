import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StoreCard {
  final String imagePath;
  final int price;

  StoreCard({required this.imagePath, required this.price});
}

class DataStorageService {
  static final DataStorageService _instance = DataStorageService._internal();
  
  factory DataStorageService([SupabaseClient? supabaseClient]) {
    if (supabaseClient != null) {
      _instance._supabaseClient = supabaseClient;
    }
    return _instance;
  }

  DataStorageService._internal();

  SupabaseClient? _supabaseClient;

  // Constantes
  static const int MAX_SHARED_PILE_CARDS = 10;
  
  // Variável de execução
  bool _isExecuting = false;

  Database? _database;
  String? _currentUserId;

  // Método para definir o ID do usuário atual
  void setCurrentUser(String userId) {
    print('🔐 Definindo usuário atual:');
    print('🆔 User ID: $userId');
    
    // Validar o formato do userId
    if (userId.isEmpty) {
      print('❌ Erro: User ID está vazio');
      throw Exception('User ID não pode ser vazio');
    }

    // Verificar se o userId parece ser um UUID válido
    final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
    if (!uuidRegex.hasMatch(userId)) {
      print('⚠️ Aviso: User ID não parece ser um UUID válido');
    }

    _currentUserId = userId;
    print('✅ Usuário definido com sucesso');
  }

  // Método para obter o ID do usuário atual
  String? getCurrentUserId() {
    return _currentUserId;
  }

  // Verificação segura de usuário
  bool isUserDefined() {
    return _currentUserId != null && _currentUserId!.isNotEmpty;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDatabase();
    return _database!;
  }

  Future<Database> initDatabase() async {
    if (_database != null) {
      return _database!;
    }

    String path = join(await getDatabasesPath(), 'photocards.db');
    
    // Uncomment to force database recreation during development
    // await deleteDatabase(path);

    try {
      _database = await openDatabase(
        path,
        version: 15,  // Increment version to force migration
        onCreate: (db, version) async {
          print('🚀 Database onCreate called. Creating initial tables...');
          
          try {
            // Criar tabela user_balance
            await db.execute('''
              CREATE TABLE user_balance (
                user_id TEXT PRIMARY KEY,
                k_coins INTEGER DEFAULT 0,
                star_coins INTEGER DEFAULT 0,
                last_reward_time INTEGER DEFAULT 0
              )
            ''');
            print('✅ user_balance table created successfully');

            // Criar tabela binders
            await db.execute('''
              CREATE TABLE binders(
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
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
            print('✅ binders table created successfully');

            // Criar outras tabelas necessárias
            await db.execute('''
              CREATE TABLE inventory(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                instance_id TEXT UNIQUE NOT NULL,
                image_path TEXT NOT NULL,
                location TEXT NOT NULL,
                binder_id TEXT,
                slot_index INTEGER,
                page_number INTEGER DEFAULT 0,
                created_at TEXT NOT NULL
              )
            ''');
            print('✅ inventory table created successfully');

            await db.execute('''
              CREATE TABLE photocards(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                photocard_id TEXT NOT NULL,
                rarity TEXT,
                created_at TEXT
              )
            ''');
            print('✅ photocards table created successfully');

            print('🎉 All initial tables created successfully');
          } catch (e) {
            print('❌ Error creating tables in onCreate: $e');
            rethrow;
          }
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          print('🔄 Database onUpgrade called. Old version: $oldVersion, New version: $newVersion');
          
          try {
            // Ensure binders table exists
            await db.execute('''
              CREATE TABLE IF NOT EXISTS binders(
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
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
            print('✅ binders table created/updated in onUpgrade');
          } catch (e) {
            print('❌ Error creating binders table in onUpgrade: $e');
            rethrow;
          }
        },
      );

      // Verify table creation
      try {
        await _database!.query('binders', limit: 1);
        print('✅ Successfully verified binders table exists');
      } catch (e) {
        print('❌ Failed to verify binders table: $e');
        rethrow;
      }

      return _database!;
    } catch (e) {
      print('❌ Critical error in database initialization: $e');
      rethrow;
    }
  }

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
              "location = 'binder' AND binder_id = ? AND slot_index = ? AND page_number = ? AND user_id = ?",
          whereArgs: [binderId, slotIndex, pageNumber, _currentUserId],
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
              'user_id': _currentUserId
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
        where: "location = 'binder' AND binder_id = ? AND user_id = ?",
        whereArgs: [binderId, _currentUserId],
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
        where: 'instance_id = ? AND user_id = ?',
        whereArgs: [instanceId, _currentUserId],
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
      'inventory',
      where: 'image_path = ? AND location = ?',
      whereArgs: [imagePath, 'shared_pile'],
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
        where: 'instance_id = ? AND user_id = ?',
        whereArgs: [id, _currentUserId],
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
        'user_id': _currentUserId
      },
    );
    
    return instanceId;
  }

  Future<List<Map<String, dynamic>>> getSharedPile() async {
    final db = await database;
    return await db.query(
      'inventory', 
      where: 'user_id = ? AND location = ?', 
      whereArgs: [_currentUserId, 'shared_pile']
    );
  }

  Future<List<Map<String, dynamic>>> getBackpackCards() async {
    final db = await database;
    return await db.query(
      'inventory', 
      where: 'user_id = ? AND location = ?', 
      whereArgs: [_currentUserId, 'backpack']
    );
  }

  Future<void> restoreFullState() async {
    try {
      // Verificação segura de usuário
      if (_currentUserId == null || _currentUserId!.isEmpty) {
        print('Usuário não definido. Pulando restauração de estado.');
        return;
      }

      final db = await database;
      final sharedPileCount = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM inventory WHERE user_id = ? AND location = ?', 
          [_currentUserId, 'shared_pile']
        )
      ) ?? 0;

      final backpackCount = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM inventory WHERE user_id = ? AND location = ?', 
          [_currentUserId, 'backpack']
        )
      ) ?? 0;

      print('Contagem de items no monte compartilhado: $sharedPileCount');
      print('Contagem de items na mochila: $backpackCount');

      if (sharedPileCount == 0 && backpackCount == 0) {
        print('Inventário vazio, inicializando dados pela primeira vez...');
        await initializeSharedPile();
      } else {
        print('Dados existentes encontrados, mantendo estado atual');
      }

      // Adicionar verificação de nulidade antes de chamar printAllLocations
      try {
        await printAllLocations();
      } catch (e) {
        print('Erro ao imprimir localizações: $e');
      }
    } catch (e) {
      print('Erro ao restaurar estado: $e');
    }
  }

  Future<String> addPhotocard(String imagePath) async {
    final db = await database;
    final id = await db.insert(
      'photocards',
      {'image_path': imagePath, 'user_id': _currentUserId},
    );
    return id.toString();
  }

  Future<String> getPhotocardPath(String id) async {
    final db = await database;
    final results = await db.query(
      'photocards',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, _currentUserId],
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
      await db.rawQuery('SELECT COUNT(*) FROM store_cards')
    );

    if (count == 0) {
      final storeCards = [
        StoreCard(
          imagePath: _getPhotocardPath(1),
          price: 100,
        ),
        StoreCard(
          imagePath: _getPhotocardPath(2),
          price: 150,
        ),
      ];

      for (var card in storeCards) {
        await addStoreCard(card.imagePath, card.price);
      }
    }
  }

  String _getPhotocardPath(int cardNumber) {
    if (cardNumber >= 1 && cardNumber <= 102) {
      return 'assets/photocards/photocard$cardNumber.png';
    } else {
      throw ArgumentError('Invalid photocard number: $cardNumber');
    }
  }

  Future<String> generateUniqueBinderId() async {
    final db = await database;
    final result = await db.query(
      'binders', 
      columns: ['id'], 
      where: 'user_id = ?',
      whereArgs: [_currentUserId],
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
        where: 'id = ? AND user_id = ?', 
        whereArgs: [binderId, _currentUserId]
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
          where: 'id = ? AND user_id = ?',
          whereArgs: [binderId, _currentUserId]
        );
      } else {
        // Insert new binder
        await db.insert('binders', {
          'id': binderId,
          'user_id': _currentUserId,  // Adicionar ID do usuário
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
    
    if (_currentUserId == null) {
      throw Exception('Nenhum usuário definido');
    }
    
    print('🔍 Criando novo binder para usuário: $_currentUserId');
    
    // Gerar um ID único para o binder
    final result = await db.query(
      'binders', 
      columns: ['id'], 
      where: 'user_id = ?',
      whereArgs: [_currentUserId],
      orderBy: 'CAST(id AS INTEGER) DESC', 
      limit: 1
    );

    int lastId = result.isNotEmpty 
      ? int.parse(result.first['id'].toString()) 
      : -1;
    
    final newBinderId = (lastId + 1).toString();

    // Determinar assets baseados no ID do binder
    final styleIndex = int.parse(newBinderId) % 4 + 1;
    final coverAsset = 'assets/capas/capabinder$styleIndex.png';
    final spineAsset = 'assets/capas/lombadabinder$styleIndex.png';

    try {
      await db.insert('binders', {
        'id': newBinderId,
        'user_id': _currentUserId,  // Adicionar ID do usuário
        'slots': '[]',
        'cover_asset': coverAsset,
        'spine_asset': spineAsset,
        'binder_name': newBinderId,
        'created_at': DateTime.now().toIso8601String(),
        'is_open': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      print('✅ Novo Binder Adicionado: ');
      print('ID: $newBinderId');
      print('Usuário: $_currentUserId');
      print('Cover Asset: $coverAsset');

      // Verificar se o binder foi realmente adicionado
      final verifyBinder = await db.query(
        'binders', 
        where: 'id = ? AND user_id = ?', 
        whereArgs: [newBinderId, _currentUserId]
      );
      
      print('🔍 Verificação de binder:');
      print('Binders encontrados: ${verifyBinder.length}');
      if (verifyBinder.isNotEmpty) {
        print('Detalhes do binder: ${verifyBinder.first}');
      }

      notifyBinderUpdate();
      return newBinderId;
    } catch (e) {
      print('❌ Erro ao adicionar novo binder: $e');
      rethrow;
    }
  }

  Future<void> updateBinderSlots(
      String binderId, List<Map<String, dynamic>> slots) async {
    final db = await database;
    await db.update(
      'binders',
      {'slots': jsonEncode(slots)},
      where: 'id = ? AND user_id = ?',
      whereArgs: [binderId, _currentUserId],
    );
  }

  Future<void> saveBinderState(String binderId, List<String?> slots) async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        await txn.delete(
          'photocards',
          where: 'binder_id = ? AND user_id = ?',
          whereArgs: [binderId, _currentUserId],
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
                'user_id': _currentUserId
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
        await txn.delete('inventory', where: 'location = ?', whereArgs: ['shared_pile']);

        for (var card in cards) {
          await txn.insert(
            'inventory',
            {'user_id': _currentUserId, 'instance_id': card, 'image_path': card, 'location': 'shared_pile'},
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
            "SELECT COUNT(*) FROM inventory WHERE location = 'shared_pile' AND user_id = ?", [_currentUserId]));

        if (sharedPileCount! >= MAX_SHARED_PILE_CARDS) {
          // Se o monte estiver cheio, move um card do monte para a mochila
          await txn.rawUpdate('''
            UPDATE inventory 
            SET location = 'backpack',
                created_at = ?,
                binder_id = NULL,
                slot_index = NULL
            WHERE location = 'shared_pile' AND user_id = ?
            ORDER BY created_at ASC
            LIMIT 1
          ''', [DateTime.now().toIso8601String(), _currentUserId]);
        }

        // Adiciona o novo card ao monte com ID único
        await txn.insert(
          'inventory',
          {
            'instance_id': newInstanceId,
            'image_path': imagePath,
            'location': 'shared_pile',
            'created_at': DateTime.now().toIso8601String(),
            'user_id': _currentUserId
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
    
    if (_currentUserId == null) {
      return [];
    }

    final results = await db.query(
      'inventory', 
      where: 'user_id = ? AND location = ?', 
      whereArgs: [_currentUserId, 'backpack']
    );

    // Convert dynamic results to Map<String, String>
    return results.map((result) => {
      'id': result['id'].toString(),
      'image_path': result['image_path'] as String,
      'instance_id': result['instance_id'] as String,
    }).toList();
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
      where: 'user_id = ?', 
      whereArgs: [_currentUserId]
    );
  }

  Future<int> getKCoins() async {
    final balance = await getBalance();
    return balance['k_coins'] ?? 300;
  }

  Future<List<String>> getSharedPileCards() async {
    final db = await database;
    try {
      final results = await db.query('inventory', where: 'user_id = ? AND location = ?', whereArgs: [_currentUserId, 'shared_pile']);
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
      // Log current user ID
      print('🔍 Buscando photocards para usuário: $_currentUserId');

      final results = await db.query(
        'inventory',
        where: "location = 'backpack' AND user_id = ?",
        whereArgs: [_currentUserId],
        columns: ['image_path', 'instance_id', 'location'],
      );

      // Log raw query results
      print('📊 Resultados da consulta:');
      print('Total de registros encontrados: ${results.length}');
      for (var result in results) {
        print('🖼️ Registro:');
        result.forEach((key, value) {
          print('   $key: $value');
        });
      }

      // Mapa que guarda o caminho da imagem e a lista de IDs únicos
      Map<String, List<String>> cardCount = {};

      for (var row in results) {
        String imagePath = row['image_path'] as String;
        String instanceId = row['instance_id'] as String;

        if (!cardCount.containsKey(imagePath)) {
          cardCount[imagePath] = [];
        }

        // Adiciona o ID à lista de IDs daquela imagem
        cardCount[imagePath]!.add(instanceId);
      }

      // Log detailed card counts
      print('🔢 Contagem de cards na mochila:');
      cardCount.forEach((imagePath, instances) {
        print('📊 Imagem: $imagePath');
        print('   Contagem: ${instances.length}');
        print('   IDs de instância: ${instances.join(", ")}');
      });

      return cardCount;
    } catch (e) {
      print('❌ Erro ao contar photocards na mochila: $e');
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
        where: 'instance_id = ? AND user_id = ?',
        whereArgs: [instanceId, _currentUserId],
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
      where: 'user_id = ? AND location = ?', 
      whereArgs: [_currentUserId, 'shared_pile']
    );
    print('Monte compartilhado: ${sharedPile.length} cards');

    final binderCards = await db.query(
      'inventory',
      where: "location = 'binder' AND user_id = ?",
      whereArgs: [_currentUserId],
    );
    print('Cards nos binders: ${binderCards.length}');
    for (var card in binderCards) {
      print(
          'Binder: ${card['binder_id']}, Slot: ${card['slot_index']}, Card: ${card['image_path']}');
    }

    final backpackCards = await db.query(
      'inventory',
      where: "location = 'backpack' AND user_id = ?",
      whereArgs: [_currentUserId],
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
              "SELECT COUNT(*) FROM inventory WHERE location = 'shared_pile' AND user_id = ?", [_currentUserId]));

          if (sharedPileCount! >= MAX_SHARED_PILE_CARDS) {
            print('Monte cheio, não é possível mover card da mochila');
            return;
          }

          // Pega o caminho da imagem do card que está sendo movido
          final cardResult = await txn.query(
            'inventory',
            columns: ['image_path'],
            where: 'instance_id = ? AND user_id = ?',
            whereArgs: [instanceId, _currentUserId],
          );

          if (cardResult.isNotEmpty) {
            final imagePath = cardResult.first['image_path'] as String;

            // Pega todos os IDs deste card na mochila
            final backpackIds = await txn.query(
              'inventory',
              columns: ['instance_id'],
              where: "location = 'backpack' AND image_path = ? AND user_id = ?",
              whereArgs: [imagePath, _currentUserId],
              orderBy: 'created_at ASC',
            );

            // Encontra o próximo ID não usado
            String? idToMove;
            for (var row in backpackIds) {
              final currentId = row['instance_id'] as String;
              final isUsed = await txn.query(
                'inventory',
                where: "location = 'shared_pile' AND instance_id = ? AND user_id = ?",
                whereArgs: [currentId, _currentUserId],
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
                where: 'instance_id = ? AND user_id = ?',
                whereArgs: [idToMove, _currentUserId],
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
            where: 'instance_id = ? AND user_id = ?',
            whereArgs: [instanceId, _currentUserId],
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
        where: 'id = ? AND user_id = ?',
        whereArgs: [binderId, _currentUserId],
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
        where: 'id = ? AND user_id = ?',
        whereArgs: [binderId, _currentUserId],
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
        where: 'id = ? AND user_id = ?',
        whereArgs: [binderId, _currentUserId],
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
      where: 'user_id = ?',
      whereArgs: [_currentUserId],
    );
  }

  Future<void> updateStarCoins(int amount) async {
    final db = await database;
    await db.update(
      'user_balance',
      {'star_coins': amount},
      where: 'user_id = ?',
      whereArgs: [_currentUserId],
    );
  }

  Future<Map<String, int>> getBalance() async {
    if (_currentUserId == null) {
      debugPrint('Erro: Usuário não definido ao buscar saldo');
      return {'k_coins': 300, 'star_coins': 0};
    }

    final db = await database;
    final result = await db.query('user_balance', where: 'user_id = ?', whereArgs: [_currentUserId]);
    
    if (result.isEmpty) {
      // Verificar se o usuário já tem algum registro no banco
      final userRecords = await db.query('user_balance', where: 'user_id = ?', whereArgs: [_currentUserId]);
      
      // Se for o primeiro login deste usuário, definir 300 coins
      if (userRecords.isEmpty) {
        await db.insert('user_balance', {
          'user_id': _currentUserId,
          'k_coins': 300,  // Definir saldo inicial para 300 K-Coins
          'star_coins': 0,
          'last_reward_time': 0,
        });
        return {'k_coins': 300, 'star_coins': 0};
      }
      
      // Se não for o primeiro login, criar com 0 coins
      await db.insert('user_balance', {
        'user_id': _currentUserId,
        'k_coins': 0,
        'star_coins': 0,
        'last_reward_time': 0,
      });
      return {'k_coins': 0, 'star_coins': 0};
    }
    
    return {
      'k_coins': result.first['k_coins'] as int,
      'star_coins': result.first['star_coins'] as int,
    };
  }

  Future<void> updateLastRewardTime(int timestamp) async {
    final db = await database;
    await db.update(
      'user_balance',
      {'last_reward_time': timestamp},
      where: 'user_id = ?',
      whereArgs: [_currentUserId],
    );
  }

  Future<int> getLastRewardTime() async {
    final db = await database;
    final result = await db.query('user_balance', where: 'user_id = ?', whereArgs: [_currentUserId]);
    if (result.isNotEmpty) {
      return result.first['last_reward_time'] as int;
    }
    return 0;
  }

  Future<void> addPurchasedFrame(String framePath) async {
    final db = await database;
    
    if (_currentUserId == null) {
      throw Exception('Nenhum usuário definido');
    }
    
    try {
      await db.insert('purchased_frames', {
        'user_id': _currentUserId,
        'frame_path': framePath
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } catch (e) {
      print('Erro ao adicionar moldura comprada: $e');
    }
  }

  Future<List<String>> getPurchasedFrames() async {
    final db = await database;
    
    if (_currentUserId == null) {
      throw Exception('Nenhum usuário definido');
    }

    final results = await db.query(
      'purchased_frames', 
      where: 'user_id = ?', 
      whereArgs: [_currentUserId]
    );
    return results.map((row) => row['frame_path'] as String).toList();
  }

  Future<bool> isFramePurchased(String framePath) async {
    final db = await database;
    
    if (_currentUserId == null) {
      throw Exception('Nenhum usuário definido');
    }

    final result = await db.query(
      'purchased_frames',
      where: 'frame_path = ? AND user_id = ?',
      whereArgs: [framePath, _currentUserId],
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
            "SELECT COUNT(*) FROM inventory WHERE location = 'shared_pile' AND user_id = ?", [_currentUserId]));

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
            where: 'instance_id = ? AND user_id = ?',
            whereArgs: [instanceId, _currentUserId],
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
            where: 'instance_id = ? AND user_id = ?',
            whereArgs: [instanceId, _currentUserId],
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
        "SELECT COUNT(*) FROM inventory WHERE location = 'shared_pile' AND user_id = ?", [_currentUserId]));
    return sharedPileCount! < MAX_SHARED_PILE_CARDS;
  }

  Future<bool> canAddMoreBinders() async {
    final db = await database;
    final binderCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM binders WHERE user_id = ?', [_currentUserId])
    ) ?? 0;

    return binderCount < 15;
  }

  Future<void> updateBinderState(String binderId, bool isOpen) async {
    final db = await database;
    try {
      await db.update(
        'binders', 
        {'is_open': isOpen ? 1 : 0}, 
        where: 'id = ? AND user_id = ?', 
        whereArgs: [binderId, _currentUserId]
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
    final result = await db.query('user_balance', where: 'user_id = ?', whereArgs: [_currentUserId]);
    
    if (result.isEmpty) {
      // Verificar se o usuário já tem algum registro no banco
      final userRecords = await db.query('user_balance', where: 'user_id = ?', whereArgs: [_currentUserId]);
      
      // Se for o primeiro login deste usuário, definir 300 coins
      if (userRecords.isEmpty) {
        await db.insert('user_balance', {
          'user_id': _currentUserId,
          'k_coins': 300,
          'star_coins': 0,
          'last_reward_time': 0,
        });
        return 300;
      }
      
      // Se não for o primeiro login, criar com 0 coins
      await db.insert('user_balance', {
        'user_id': _currentUserId,
        'k_coins': 0,
        'star_coins': 0,
        'last_reward_time': 0,
      });
      return 0;
    }
    
    return result.first['k_coins'] as int;
  }

  Future<List<Map<String, dynamic>>> getAllBinders() async {
    final db = await database;
    
    if (_currentUserId == null) {
      throw Exception('Nenhum usuário definido');
    }

    try {
      final binders = await db.query(
        'binders', 
        where: 'user_id = ?', 
        whereArgs: [_currentUserId],
        orderBy: 'CAST(id AS INTEGER) ASC'
      );

      // Se não existem binders, cria um inicial
      if (binders.isEmpty) {
        print('⚠️ Nenhum binder encontrado. Criando binder inicial.');
        final newBinderId = await addNewBinder();
        
        // Buscar o binder recém-criado
        final initialBinders = await db.query(
          'binders', 
          where: 'id = ? AND user_id = ?', 
          whereArgs: [newBinderId, _currentUserId]
        );
        
        return initialBinders;
      }

      return binders;
    } catch (e) {
      print('Erro ao buscar binders: $e');
      return [];
    }
  }

  Future<void> initializeSharedPile() async {
    final db = await database;
    try {
      final existingCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM inventory WHERE location = "shared_pile" AND user_id = ?', [_currentUserId]));

      if (existingCount! > 0) {
        print('Cards já existem no monte compartilhado, pulando inicialização');
        return;
      }

      print('Monte compartilhado inicializado vazio');
    } catch (e) {
      print('Erro ao inicializar monte compartilhado: $e');
    }
  }

  Future<List<Photocard>> getAllPhotocards() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'photocards', 
      where: 'user_id = ?', 
      whereArgs: [_currentUserId]
    );
    return maps.map((map) => Photocard.fromMap(map)).toList();
  }

  Future<Map<String, dynamic>?> getBinder(String binderId) async {
    final db = await database;
    
    if (_currentUserId == null) {
      throw Exception('Nenhum usuário definido');
    }
    
    final result = await db.query(
      'binders', 
      where: 'id = ? AND user_id = ?',
      whereArgs: [binderId, _currentUserId],
      limit: 1
    );

    return result.isNotEmpty ? result.first : null;
  }

  Future<void> debugPrintCards() async {
    final db = await database;
    final cards = await db.query('photocards', where: 'user_id = ?', whereArgs: [_currentUserId]);
    print('📋 Lista de photocards no banco:');
    for (var card in cards) {
      print(card);
    }
  }

  Future<List<Map<String, dynamic>>> getSharedPilePhotocards() async {
    final db = await database;
    try {
      return await db.query(
        'photocards', 
        where: 'user_id = ?', 
        whereArgs: [_currentUserId]
      );
    } catch (e) {
      print('Erro ao buscar photocards: $e');
      return [];
    }
  }

  Future<bool> addToSharedPile(String imagePath) async {
    final db = await database;
    try {
      // Log the current user ID and image path
      print('🔍 Tentando adicionar card ao monte');
      print('👤 ID do usuário atual: $_currentUserId');
      print('🖼️ Caminho da imagem: $imagePath');

      final currentCount = Sqflite.firstIntValue(await db.rawQuery(
          "SELECT COUNT(*) FROM inventory WHERE location = 'shared_pile' AND user_id = ?", [_currentUserId]));

      print('📊 Contagem atual de cards no monte: $currentCount');

      const int MAX_SHARED_PILE_CARDS = 10; // Defina o limite máximo

      if (currentCount! < MAX_SHARED_PILE_CARDS) {
        // Adicionar ao inventário
        final instanceId = await addToInventory(imagePath, 'shared_pile');
        print('✅ Card adicionado ao inventário. ID da instância: $instanceId');
        return true;
      } else {
        await addToInventory(imagePath, 'backpack');
        print('⚠️ Card adicionado à mochila (monte cheio)');
        return false;
      }
    } catch (e) {
      print('❌ Erro ao adicionar card: $e');
      return false;
    }
  }
}

class Photocard {
  final String imagePath;
  final String instanceId;
  final String binderId;
  final int slotIndex;
  final int pageNumber;

  Photocard({
    required this.imagePath,
    required this.instanceId,
    required this.binderId,
    required this.slotIndex,
    required this.pageNumber,
  });

  factory Photocard.fromMap(Map<String, dynamic> map) {
    return Photocard(
      imagePath: map['image_path'] as String,
      instanceId: map['instance_id'] as String,
      binderId: map['binder_id'] as String,
      slotIndex: map['slot_index'] as int,
      pageNumber: map['page_number'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'image_path': imagePath,
      'instance_id': instanceId,
      'binder_id': binderId,
      'slot_index': slotIndex,
      'page_number': pageNumber,
    };
  }
}

class Binder {
  final String id;
  final String slots;
  final String coverAsset;
  final String spineAsset;
  final String? keychainAsset;
  final String binderName;
  final String createdAt;
  final String updatedAt;
  final int isOpen;
  final String userId;

  Binder({
    required this.id,
    required this.slots,
    required this.coverAsset,
    required this.spineAsset,
    this.keychainAsset,
    required this.binderName,
    required this.createdAt,
    required this.updatedAt,
    required this.isOpen,
    required this.userId,
  });

  factory Binder.fromMap(Map<String, dynamic> map) {
    return Binder(
      id: map['id'] as String,
      slots: map['slots'] as String,
      coverAsset: map['cover_asset'] as String,
      spineAsset: map['spine_asset'] as String,
      keychainAsset: map['keychain_asset'] as String?,
      binderName: map['binder_name'] as String,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
      isOpen: map['is_open'] as int,
      userId: map['user_id'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'slots': slots,
      'cover_asset': coverAsset,
      'spine_asset': spineAsset,
      'keychain_asset': keychainAsset,
      'binder_name': binderName,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_open': isOpen,
      'user_id': userId,
    };
  }
}
