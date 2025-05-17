import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart' as uuid;

class StoreCard {
  final String imagePath;
  final int price;

  StoreCard({required this.imagePath, required this.price});
}

class DataStorageService {
  final SupabaseClient _supabaseClient;
  String? _currentUserId;

  DataStorageService([SupabaseClient? supabaseClient]) 
      : _supabaseClient = supabaseClient ?? Supabase.instance.client {
    _currentUserId = _supabaseClient.auth.currentUser?.id;
  }

  // Constantes
  static const int MAX_SHARED_PILE_CARDS = 10;
  
  // Variável de execução
  bool _isExecuting = false;

  Database? _database;

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
        version: 16,  // Increment version to force migration
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
                is_open INTEGER DEFAULT 0,
                name TEXT
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
                is_open INTEGER DEFAULT 0,
                name TEXT
              )
            ''');
            print('✅ binders table created/updated in onUpgrade');

            if (oldVersion < 16) {
              // Migração para adicionar a coluna 'name'
              try {
                await db.execute('ALTER TABLE binders ADD COLUMN name TEXT');
                print('✅ Coluna "name" adicionada à tabela binders');
              } catch (e) {
                print('❌ Erro ao adicionar coluna "name": $e');
              }
            }
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
    String binderId,
    int pageNumber,
    int slotIndex,
    String? imagePath, {
    required String instanceId,
  }) async {
    if (_currentUserId == null || imagePath == null) return;

    final timestamp = DateTime.now().toIso8601String();

    await _supabaseClient!.from('inventory').update({
      'location': 'binder',
      'binder_id': binderId,
      'page_number': pageNumber,
      'slot_index': slotIndex,
      'updated_at': timestamp,
    }).eq('user_id', _currentUserId).eq('instance_id', instanceId);
  }

  Future<List<Map<String, dynamic>>> loadBinderPhotocards(String binderId) async {
    if (_currentUserId == null) return [];
    final response = await _supabaseClient
        .from('inventory')
        .select()
        .eq('user_id', _currentUserId)
        .eq('binder_id', binderId)
        .eq('location', 'binder');
    return List<Map<String, dynamic>>.from(response);
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
      {String? binderId, int? slotIndex, int? pageNumber}) async {
    if (_currentUserId == null) throw Exception('Usuário não autenticado');
    final timestamp = DateTime.now().toIso8601String();
    final instanceId = DateTime.now().millisecondsSinceEpoch.toString();

    await _supabaseClient.from('inventory').insert({
      'instance_id': instanceId,
      'user_id': _currentUserId,
      'image_path': imagePath,
      'location': location,
      'binder_id': binderId,
      'slot_index': slotIndex,
      'page_number': pageNumber,
      'created_at': timestamp,
      'updated_at': timestamp,
    });

    return instanceId;
  }

  Future<List<Map<String, dynamic>>> getSharedPile() async {
    if (_currentUserId == null) return [];
    final response = await _supabaseClient
        .from('inventory')
        .select()
        .eq('user_id', _currentUserId)
        .eq('location', 'shared_pile');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, String>>> getBackpackCards() async {
    final db = await database;
    final results = await db.query(
      'inventory', 
      where: 'user_id = ? AND location = ?', 
      whereArgs: [_currentUserId, 'backpack']
    );
  
    return results.map((map) => 
      map.map((key, value) => MapEntry(key, value?.toString() ?? ''))
    ).toList();
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

  String generateUniqueBinderId() {
    // Gera um UUID único para o binder, garantindo que seja sempre uma string
    return uuid.Uuid().v4();
  }

  // Método para gerar um índice de estilo baseado no ID do binder
  int _generateStyleIndex(String binderId) {
    // Usar o hashCode para gerar um índice consistente baseado na string
    return binderId.hashCode.abs() % 4 + 1;
  }

  Future<void> movePhotocardToPile(String imagePath,
      {String? instanceId}) async {
    if (_currentUserId == null) return;

    try {
      // Verifica se há espaço no monte
      final response = await _supabaseClient
          .from('inventory')
          .select('count')
          .eq('location', 'shared_pile')
          .eq('user_id', _currentUserId)
          .single();

      final sharedPileCount = response['count'] as int;
      if (sharedPileCount >= MAX_SHARED_PILE_CARDS) {
        // Se o monte estiver cheio, move o card mais antigo para a mochila
        final oldestCard = await _supabaseClient
            .from('inventory')
            .select()
            .eq('location', 'shared_pile')
            .eq('user_id', _currentUserId)
            .order('created_at')
            .limit(1)
            .single();

        await updateCardLocation(oldestCard['instance_id'], 'backpack');
      }

      // Adiciona o novo card ao monte
      final newInstanceId = instanceId ?? DateTime.now().millisecondsSinceEpoch.toString();
      await _supabaseClient.from('inventory').insert({
        'instance_id': newInstanceId,
        'image_path': imagePath,
        'location': 'shared_pile',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'user_id': _currentUserId
      });

      print('Photocard movido para o monte: $imagePath (instanceId: $newInstanceId)');
    } catch (e) {
      print('Erro ao mover photocard para o monte: $e');
      rethrow;
    }
  }

  Future<List<Map<String, String>>> getAvailablePhotocards() async {
    if (_currentUserId == null) return [];
    final response = await _supabaseClient
        .from('inventory')
        .select('image_path, instance_id')
        .eq('user_id', _currentUserId)
        .eq('location', 'backpack');

    final uniqueCards = <String, Map<String, String>>{};
    for (final card in response) {
      final imagePath = card['image_path'] as String;
      if (!uniqueCards.containsKey(imagePath)) {
        uniqueCards[imagePath] = {
          'image_path': imagePath,
          'instance_id': card['instance_id'] as String,
        };
      }
    }
    return uniqueCards.values.toList();
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

  Future<List<Map<String, dynamic>>> getSharedPileCards() async {
    if (_currentUserId == null) return [];

    try {
      final result = await _supabaseClient!
          .from('inventory')
          .select()
          .eq('user_id', _currentUserId)
          .eq('location', 'shared_pile');

      print('🗃️ Monte compartilhado carregado: ${result.length} cards');
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('❌ Erro ao carregar monte compartilhado: $e');
      return [];
    }
  }

  Future<Map<String, List<String>>> getBackpackPhotocardsCount() async {
    if (_currentUserId == null) return {};
    final response = await _supabaseClient
        .from('inventory')
        .select('image_path, instance_id')
        .eq('user_id', _currentUserId)
        .eq('location', 'backpack');

    final Map<String, List<String>> cardCount = {};
    for (final row in response) {
      final imagePath = row['image_path'] as String;
      final instanceId = row['instance_id'] as String;
      cardCount.putIfAbsent(imagePath, () => []);
      cardCount[imagePath]!.add(instanceId);
    }
    return cardCount;
  }

  Future<void> updateCardLocation(
    String instanceId,
    String newLocation, {
    String? binderId,
    int? slotIndex,
    int? pageNumber,
  }) async {
    if (_currentUserId == null || instanceId.isEmpty) return;

    await _supabaseClient
        .from('inventory')
        .update({
          'location': newLocation,
          'binder_id': binderId,
          'slot_index': slotIndex,
          'page_number': pageNumber,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('instance_id', instanceId)
        .eq('user_id', _currentUserId);
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
    if (_currentUserId == null) return;

    try {
      if (fromLocation == 'backpack') {
        // Verifica se há espaço no monte
        final response = await _supabaseClient
            .from('inventory')
            .select('count')
            .eq('location', 'shared_pile')
            .eq('user_id', _currentUserId)
            .single();

        final sharedPileCount = response['count'] as int;
        if (sharedPileCount >= MAX_SHARED_PILE_CARDS) {
          print('Monte cheio, não é possível mover card da mochila');
          return;
        }

        // Move para o monte
        await updateCardLocation(instanceId, 'shared_pile');
        print('Card movido da mochila para o monte (ID: $instanceId)');
      } else {
        // Move do monte para a mochila
        await updateCardLocation(instanceId, 'backpack');
        print('Card movido do monte para a mochila');
      }
    } catch (e) {
      print('Erro ao mover card entre mochila e monte: $e');
      rethrow;
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

      // Sincronizar com Supabase
      try {
        await _supabaseClient!.from('binders').upsert({
          'id': binderId,
          'user_id': _currentUserId,
          'cover_asset': cover,
          'spine_asset': spine,
          'updated_at': DateTime.now().toIso8601String(),
        });
        print('Capas do binder sincronizadas com Supabase');
      } catch (supabaseError) {
        print('Erro ao sincronizar capas com Supabase: $supabaseError');
      }
    } catch (e) {
      print('Erro ao atualizar capas do binder: $e');
      rethrow;
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
  if (_currentUserId == null) return;

  try {
    await _supabaseClient!.from('binders').update({
      'keychain_asset': keychainPath,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', binderId).eq('user_id', _currentUserId);

    print('🔗 Keychain do binder $binderId salvo com sucesso no Supabase!');
  } catch (e) {
    print('❌ Erro ao salvar keychain do binder no Supabase: $e');
  }
}


  Future<void> updateKCoins(int newAmount) async {
    if (_currentUserId == null) return;
    await _supabaseClient
        .from('user_balance')
        .update({'k_coins': newAmount})
        .eq('user_id', _currentUserId);
  }

  Future<void> updateStarCoins(int newAmount) async {
    if (_currentUserId == null) return;
    await _supabaseClient
        .from('user_balance')
        .update({'star_coins': newAmount})
        .eq('user_id', _currentUserId);
  }

  Future<Map<String, int>> getBalance() async {
  if (_currentUserId == null) {
    debugPrint('Erro: Usuário não definido ao buscar saldo');
    return {'k_coins': 300, 'star_coins': 0};
  }

  try {
    final result = await _supabaseClient
        .from('user_balance')
        .select()
        .eq('user_id', _currentUserId)
        .maybeSingle();

    if (result != null) {
      return {
        'k_coins': result['k_coins'] ?? 300,
        'star_coins': result['star_coins'] ?? 0,
      };
    } else {
      // ✅ Cria o saldo inicial no Supabase
      await _supabaseClient.from('user_balance').insert({
        'user_id': _currentUserId,
        'k_coins': 300,
        'star_coins': 0,
        'last_reward_time': 0,
      });

      debugPrint('🪙 Saldo inicial criado para $_currentUserId');
      return {'k_coins': 300, 'star_coins': 0};
    }
  } catch (e) {
    debugPrint('❌ Erro ao buscar saldo no Supabase: $e');
    return {'k_coins': 300, 'star_coins': 0};
  }
}

  // Garante que o usuário tem um registro de saldo no Supabase
  Future<void> ensureBalanceExistsForUser() async {
    if (_currentUserId == null) {
      debugPrint('❌ Erro: Usuário não definido ao verificar saldo');
      return;
    }

    try {
      final result = await _supabaseClient
          .from('user_balance')
          .select()
          .eq('user_id', _currentUserId)
          .maybeSingle();

      if (result == null) {
        // Criar saldo inicial se não existir
        await _supabaseClient.from('user_balance').insert({
          'user_id': _currentUserId,
          'k_coins': 300,
          'star_coins': 0,
          'last_reward_time': 0,
        });
        debugPrint('🪙 Saldo inicial criado para $_currentUserId');
      }
    } catch (e) {
      debugPrint('❌ Erro ao verificar/criar saldo no Supabase: $e');
    }
  }

  Future<void> updateLastRewardTime(int timestamp) async {
    if (_currentUserId == null) {
      debugPrint('❌ Erro: Usuário não definido ao atualizar last_reward_time');
      return;
    }

    try {
      await _supabaseClient
          .from('user_balance')
          .update({'last_reward_time': timestamp})
          .eq('user_id', _currentUserId);
    } catch (e) {
      debugPrint('❌ Erro ao atualizar last_reward_time no Supabase: $e');
    }
  }

  Future<int> getLastRewardTime() async {
    if (_currentUserId == null) {
      debugPrint('❌ Erro: Usuário não definido ao buscar last_reward_time');
      return 0;
    }

    try {
      final result = await _supabaseClient
          .from('user_balance')
          .select('last_reward_time')
          .eq('user_id', _currentUserId)
          .maybeSingle();
      
      return result?['last_reward_time'] ?? 0;
    } catch (e) {
      debugPrint('❌ Erro ao buscar last_reward_time no Supabase: $e');
      return 0;
    }
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
    if (_currentUserId == null) return;

    try {
      // Verifica se há espaço no monte
      final response = await _supabaseClient
          .from('inventory')
          .select('count')
          .eq('location', 'shared_pile')
          .eq('user_id', _currentUserId)
          .single();

      final sharedPileCount = response['count'] as int;
      if (sharedPileCount >= MAX_SHARED_PILE_CARDS) {
        // Se o monte estiver cheio, move direto para a mochila
        await updateCardLocation(instanceId, 'backpack');
        print('📦 Monte cheio: card $instanceId movido para a mochila');
      } else {
        // Se houver espaço, move para o monte
        await updateCardLocation(instanceId, 'shared_pile');
        print('📦 Card $instanceId movido para o monte');
      }
    } catch (e) {
      print('❌ Erro ao mover card específico para o monte: $e');
      rethrow;
    }
  }Future<bool> canChangeUsername() async {
  if (_currentUserId == null) {
    debugPrint('❌ Erro: Usuário não definido ao verificar mudança de username');
    return false;
  }

  try {
    final response = await _supabaseClient
        .from('username')
        .select('last_change')
        .eq('user_id', _currentUserId)
        .maybeSingle();

    if (response == null || response['last_change'] == null) {
      debugPrint('✅ Primeira mudança de username permitida');
      return true;
    }

    final lastChange = DateTime.parse(response['last_change']);
    final daysPassed = DateTime.now().difference(lastChange).inDays;
    final canChange = daysPassed >= 20;

    debugPrint(canChange
        ? '✅ Pode mudar username (${daysPassed} dias desde a última mudança)'
        : 'ℹ️ Precisa esperar mais ${20 - daysPassed} dias para mudar o username');

    return canChange;
  } catch (e) {
    debugPrint('❌ Erro ao verificar permissão de mudança de username: $e');
    return false;
  }
}

Future<DateTime?> getNextUsernameChangeDate() async {
  if (_currentUserId == null) {
    debugPrint('❌ Erro: Usuário não definido ao buscar próxima data de mudança');
    return null;
  }

  try {
    final response = await _supabaseClient
        .from('username')
        .select('last_change')
        .eq('user_id', _currentUserId)
        .maybeSingle();

    if (response == null || response['last_change'] == null) {
      debugPrint('✅ Mudança de username disponível imediatamente');
      return null;
    }

    final lastChange = DateTime.parse(response['last_change']);
    final nextChange = lastChange.add(Duration(days: 20));
    
    debugPrint('ℹ️ Próxima mudança de username disponível em: ${nextChange.toIso8601String()}');
    return nextChange;
  } catch (e) {
    debugPrint('❌ Erro ao buscar próxima data de mudança: $e');
    return null;
  }
}

Future<bool> isUsernameAvailable(String username) async {
  try {
    final cleanUsername = username.trim().toLowerCase();
    final existing = await _supabaseClient
        .from('username')
        .select('user_id')
        .eq('name', cleanUsername)
        .maybeSingle();

    final isAvailable = existing == null;
    debugPrint(isAvailable
        ? '✅ Username "$cleanUsername" está disponível'
        : 'ℹ️ Username "$cleanUsername" já está em uso');

    return isAvailable;
  } catch (e) {
    debugPrint('❌ Erro ao verificar disponibilidade do username: $e');
    return false;
  }
}

Future<bool> setUsername(String username) async {
  if (_currentUserId == null) {
    debugPrint('❌ Erro: Usuário não definido ao definir username');
    return false;
  }

  try {
    final now = DateTime.now().toIso8601String();
    final cleanUsername = username.trim().toLowerCase();

    await _supabaseClient
        .from('username')
        .upsert({
          'user_id': _currentUserId,
          'name': cleanUsername,
          'last_change': now,
        }, onConflict: 'user_id');

    debugPrint('✅ Username definido com sucesso: $cleanUsername');
    return true;
  } catch (e) {
    debugPrint('❌ Erro ao definir username: $e');
    return false;
  }
}

Future<String?> getUsername() async {
  if (_currentUserId == null) {
    debugPrint('❌ Erro: Usuário não definido ao buscar username');
    return null;
  }

  try {
    final response = await _supabaseClient
        .from('username')
        .select('name')
        .eq('user_id', _currentUserId)
        .maybeSingle();

    if (response == null) {
      debugPrint('ℹ️ Nenhum username encontrado para $_currentUserId');
      return null;
    }

    return response['name'] as String?;
  } catch (e) {
    debugPrint('❌ Erro ao buscar username no Supabase: $e');
    return null;
  }
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
    if (_currentUserId == null) return 0;
    final result = await _supabaseClient
        .from('user_balance')
        .select('k_coins')
        .eq('user_id', _currentUserId)
        .maybeSingle();
    return result != null ? result['k_coins'] ?? 0 : 0;
  }

  Future<List<Map<String, dynamic>>> getAllBinders() async {
    if (_currentUserId == null) {
      throw Exception('Nenhum usuário definido');
    }

    try {
      print('📡 Buscando binders diretamente do Supabase...');
      
      final response = await _supabaseClient!
          .from('binders')
          .select()
          .eq('user_id', _currentUserId!)
          .order('created_at');

      final List<Map<String, dynamic>> binders = List<Map<String, dynamic>>.from(response);

      print('📦 Binders encontrados: ${binders.length}');
      for (final binder in binders) {
        print('🧾 Binder ID: ${binder['id']} - Nome: ${binder['name']}');
      }

      // Se não houver binders, cria o primeiro automaticamente
      if (binders.isEmpty) {
        print('🆕 Nenhum binder encontrado, criando o primeiro binder...');
        final newBinderId = await addNewBinder();
        return await getAllBinders(); // Recursivamente tenta de novo
      }

      return binders;
    } catch (e) {
      print('❌ Erro ao buscar binders do Supabase: $e');
      return [];
    }
  }

  Future<void> preventBinderDuplication() async {
    final db = await database;
    
    if (_currentUserId == null) {
      throw Exception('Nenhum usuário definido');
    }

    // Buscar binders duplicados
    final duplicateBinders = await db.rawQuery('''
      SELECT id, COUNT(*) as count 
      FROM binders 
      WHERE user_id = ? 
      GROUP BY id 
      HAVING count > 1
    ''', [_currentUserId]);

    if (duplicateBinders.isNotEmpty) {
      print('🚨 Binders duplicados encontrados: ${duplicateBinders.length}');
      
      // Remover duplicatas, mantendo o primeiro registro
      for (var duplicate in duplicateBinders) {
        final binderId = duplicate['id'] as String;
        
        // Excluir registros duplicados, mantendo o primeiro
        await db.delete(
          'binders', 
          where: 'id = ? AND user_id = ? AND rowid NOT IN (SELECT MIN(rowid) FROM binders WHERE id = ? AND user_id = ?)',
          whereArgs: [binderId, _currentUserId, binderId, _currentUserId]
        );
      }
      
      print('✅ Binders duplicados removidos com sucesso');
    } else {
      print('✅ Nenhum binder duplicado encontrado');
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
      whereArgs: [binderId, _currentUserId]
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
    const int MAX_SHARED_PILE_CARDS = 10;

    if (_currentUserId == null) return false;

    final currentPile = await _supabaseClient!
        .from('inventory')
        .select('instance_id')
        .eq('user_id', _currentUserId)
        .eq('location', 'shared_pile');

    print('📦 Monte atual: ${currentPile.length} cards');

    if (currentPile.length < MAX_SHARED_PILE_CARDS) {
      await addToInventory(imagePath, 'shared_pile');
      return true;
    } else {
      await addToInventory(imagePath, 'backpack');
      return false;
    }
  }

  Future<void> addBinder(String binderId, String slots) async {
    final db = await database;
    
    try {
      final safeBinderId = binderId.toString();
      final styleIndex = (safeBinderId.hashCode % 4) + 1;
      final coverAsset = 'assets/capas/capabinder$styleIndex.png';
      final spineAsset = 'assets/capas/lombadabinder$styleIndex.png';

      // First, check if the binder already exists
      final existingBinder = await db.query(
        'binders', 
        where: 'id = ? AND user_id = ?', 
        whereArgs: [safeBinderId, _currentUserId]
      );

      if (existingBinder.isNotEmpty) {
        await db.update(
          'binders', 
          {
            'slots': slots ?? '[]',
            'cover_asset': coverAsset,
            'spine_asset': spineAsset,
            'name': safeBinderId,  // Use 'name' instead of 'binder_name'
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ? AND user_id = ?',
          whereArgs: [safeBinderId, _currentUserId]
        );
      } else {
        // Insert new binder
        try {
          final response = await _supabaseClient!.from('binders').upsert({
            'id': safeBinderId,
            'user_id': _currentUserId,
            'slots': slots ?? '[]',
            'cover_asset': coverAsset,
            'spine_asset': spineAsset,
            'name': safeBinderId,  // Use 'name' instead of 'binder_name'
            'created_at': DateTime.now().toIso8601String(),
            'is_open': 0,
          });

          // Verifique se a resposta não é nula antes de acessar response.data
          if (response == null) {
            print('Erro: resposta nula ao inserir binder no Supabase.');
            return;
          }

          print('Resposta da inserção: ${response.data}'); // Verifique a resposta da inserção

          if (response.data == null) {
            print('Erro ao inserir binder: ${response.status}');
            return;
          }
        } catch (e) {
          print('Erro ao inserir binder no Supabase: $e');
          rethrow;
        }
      }

      print('Binder processed. ID: $safeBinderId, Cover: $coverAsset, Spine: $spineAsset');
      notifyBinderUpdate();
    } catch (e) {
      print('Error processing binder: $e');
      rethrow;
    }
  }

  // Método para obter o binder inicial
  Future<Map<String, dynamic>?> getInitialBinder() async {
    final db = await database;
    
    if (_currentUserId == null) {
      throw Exception('Nenhum usuário definido');
    }

    // Buscar binders iniciais
    final initialBinders = await db.query(
      'binders', 
      where: '(name = ? OR binder_name = ?) AND user_id = ?', 
      whereArgs: ['Primeiro Binder', 'Primeiro Binder', _currentUserId],
      limit: 1
    );

    // Retornar o primeiro binder inicial encontrado, se existir
    return initialBinders.isNotEmpty ? initialBinders.first : null;
  }

  // Método para criar o binder inicial
  Future<String> _createInitialBinder() async {
    final db = await database;

    // Gerar um novo UUID para o binder
    final newBinderId = generateUniqueBinderId();

    // Determinar assets baseados no ID do binder
    final styleIndex = _generateStyleIndex(newBinderId);
    final coverAsset = 'assets/capas/capabinder$styleIndex.png';
    final spineAsset = 'assets/capas/lombadabinder$styleIndex.png';

    try {
      // Log dos dados antes da inserção
      print('📝 Criando Binder Inicial:');
      print('   ID: $newBinderId');
      print('   Nome: Primeiro Binder');
      print('   Usuário: $_currentUserId');
      print('   Índice de Estilo: $styleIndex');

      // Inserir novo binder inicial
      await db.insert('binders', {
        'id': newBinderId,
        'user_id': _currentUserId,
        'slots': '[]',
        'cover_asset': coverAsset,
        'spine_asset': spineAsset,
        'name': 'Primeiro Binder',  // Nome fixo para o binder inicial
        'binder_name': 'Primeiro Binder',  // Manter compatibilidade
        'created_at': DateTime.now().toIso8601String(),
        'is_open': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      print('✅ Binder Inicial Criado: $newBinderId');
      
      notifyBinderUpdate();
      return newBinderId;
    } catch (e) {
      print('❌ Erro ao criar binder inicial: $e');
      rethrow;
    }
  }

  Future<String> addNewBinder() async {
    try {
      // Validar o usuário atual antes de qualquer operação
      await _validateCurrentUser();

      final db = await database;
      
      // Log detalhado de início da operação
      print('🔍 Iniciando Criação de Novo Binder');
      print('   Timestamp: ${DateTime.now().toIso8601String()}');
      print('   Usuário Atual: $_currentUserId');

      // Verificar todos os binders existentes para o usuário atual
      final existingBinders = await db.query(
        'binders', 
        where: 'user_id = ?',
        whereArgs: [_currentUserId]
      );

      // Log de binders existentes
      print('📋 Binders Existentes para o Usuário: ${existingBinders.length}');
      for (var binder in existingBinders) {
        print('   Binder ID: ${binder['id']}');
        print('   Nome: ${binder['name'] ?? binder['binder_name']}');
      }

      // Gerar nome único para o binder
      String generateUniqueName(int count) {
        // Se não há binders, criar o inicial
        if (count == 0) {
          return 'Primeiro Binder';
        }
        
        // Verificar se o nome já existe
        final proposedName = 'Binder ${count + 1}';
        final nameExists = existingBinders.any(
          (binder) => 
            (binder['name'] as String?)?.toLowerCase() == proposedName.toLowerCase() ||
            (binder['binder_name'] as String?)?.toLowerCase() == proposedName.toLowerCase()
        );

        return nameExists ? generateUniqueName(count + 1) : proposedName;
      }

      // Determinar o nome do binder
      final binderName = generateUniqueName(existingBinders.length);
      
      // Log detalhado para verificar o nome
      print('🏷️ Nome do Binder Gerado: $binderName');
      print('🔢 Contagem de Binders Existentes: ${existingBinders.length}');

      // Gerar um novo UUID para o binder
      final newBinderId = generateUniqueBinderId();

      // Determinar assets baseados no ID do binder
      final styleIndex = _generateStyleIndex(newBinderId);
      final coverAsset = 'assets/capas/capabinder$styleIndex.png';
      final spineAsset = 'assets/capas/lombadabinder$styleIndex.png';

      // Log dos dados antes da inserção
      print('📝 Dados para Inserção do Novo Binder:');
      print('   ID: $newBinderId');
      print('   Nome: $binderName');
      print('   Usuário: $_currentUserId');
      print('   Índice de Estilo: $styleIndex');

      // Verificar se o binder já existe antes de inserir
      final existingBinderCheck = await _supabaseClient!.from('binders').select().eq('id', newBinderId).eq('user_id', _currentUserId);

      if (existingBinderCheck.isNotEmpty) {
        print('❌ Binder com este ID já existe. Gerando novo ID.');
        return await addNewBinder(); // Recursivamente gerar novo ID
      }

      // Inserir novo binder
      try {
        final response = await _supabaseClient!.from('binders').upsert({
          'id': newBinderId,
          'user_id': _currentUserId,
          'slots': '[]',
          'cover_asset': coverAsset,
          'spine_asset': spineAsset,
          'name': binderName,  // Use 'name' instead of 'binder_name'
          'created_at': DateTime.now().toIso8601String(),
          'is_open': 0,
        });

        // Verifique se a resposta não é nula antes de acessar response.data
        if (response == null) {
          print('Erro: resposta nula ao inserir binder no Supabase.');
          return '';
        }

        print('Resposta da inserção: ${response.data}'); // Verifique a resposta da inserção

        if (response.data == null) {
          print('Erro ao inserir binder: ${response.status}');
          return '';
        }
      } catch (e) {
        print('Erro ao inserir binder no Supabase: $e');
        rethrow;
      }

      print('✅ Novo Binder Adicionado: ');
      print('ID: $newBinderId');
      print('Nome: $binderName');
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
        
        // Log específico para verificar o nome
        print('📋 Nome do Binder Verificado: ${verifyBinder.first['name']}');
        print('📋 Nome do Binder (binder_name): ${verifyBinder.first['binder_name']}');
      }

      notifyBinderUpdate();
      return newBinderId;
    } catch (e, stackTrace) {
      print('❌ Erro ao adicionar novo binder: $e');
      print('Detalhes do erro: $stackTrace');
      
      // Tentar recuperar informações adicionais sobre o erro
      final user = Supabase.instance.client.auth.currentUser;
      print('Informações do Usuário no Momento do Erro:');
      print('   ID do Usuário: ${user?.id ?? "N/A"}');
      print('   Email do Usuário: ${user?.email ?? "N/A"}');
      
      rethrow;
    }
  }

  // Método para verificar e validar o usuário atual
  Future<void> _validateCurrentUser() async {
    // Verificar se o usuário atual está definido
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      // Log detalhado sobre o estado do usuário
      print('❌ ERRO CRÍTICO: Usuário atual não definido');
      
      // Tentar recuperar o usuário do Supabase
      final user = Supabase.instance.client.auth.currentUser;
      
      if (user == null) {
        print('🚨 Nenhum usuário autenticado no Supabase');
        throw Exception('Nenhum usuário autenticado');
      }

      // Definir o usuário atual com o ID do Supabase
      print('🔍 Usuário recuperado do Supabase: ${user.id}');
      _currentUserId = user.id;
    }

    // Log adicional para verificação
    print('✅ Usuário Atual Validado:');
    print('   ID do Usuário: $_currentUserId');
    print('   Email do Usuário: ${Supabase.instance.client.auth.currentUser?.email ?? "N/A"}');
  }

  Future<void> ensureBinderExists() async {
    try {
      final response = await _supabaseClient!
          .from('binders')
          .select()
          .eq('user_id', _currentUserId)
          .execute();

      print('Resposta da consulta: ${response.data}'); // Veja o que realmente está retornando

      // Verifique se a resposta é uma lista
      if (response.data is List) {
          List<dynamic> binders = response.data;
          print('Binders encontrados: ${binders.length}');

          if (binders.isEmpty) {
              print('⚠️ Nenhum binder encontrado. Criando um novo.');
              await _createNewBinder();
          } else {
              print('✅ Binders já existem, carregando normalmente.');
          }
      } else {
          print('Erro: resposta inesperada do Supabase.');
      }
    } catch (e) {
      print('Erro ao sincronizar binders: $e');
    }
  }

Future<void> syncBinders() async {
  try {
    final response = await _supabaseClient!
        .from('binders')
        .select()
        .eq('user_id', _currentUserId)
        .execute();

    if (response.data == null) {
      print('❌ Erro ao obter binders: resposta nula.');
      return;
    }

    List<dynamic> binders = response.data;
    print('🔍 Binders encontrados: ${binders.length}');

    if (binders.isEmpty) {
      print('⚠️ Nenhum binder encontrado. Verificando novamente antes de criar.');
      
      // Fazer uma segunda verificação antes de criar
      await Future.delayed(Duration(seconds: 1)); // Pequeno delay para evitar race condition
      final doubleCheck = await _supabaseClient!
          .from('binders')
          .select()
          .eq('user_id', _currentUserId)
          .execute();

      if (doubleCheck.data != null && doubleCheck.data.isNotEmpty) {
        print('✅ Binder detectado na segunda verificação, cancelando criação.');
        return;
      }

      print('🚨 Nenhum binder encontrado após verificação. Criando um novo.');
      await _createNewBinder();
    }
  } catch (e) {
    print('❌ Erro ao sincronizar binders: $e');
  }
}



  Future<void> _createNewBinder() async {
    try {
      // Verifique se o binder já existe para o usuário
      final existingBindersResponse = await _supabaseClient!
          .from('binders')
          .select()
          .eq('user_id', _currentUserId)
          .execute();

      // Verifique se a resposta é bem-sucedida
      if (existingBindersResponse.data == null) {
        print('Erro ao verificar binders existentes: ${existingBindersResponse.status}');
        return;
      }

      // Se não houver binders existentes, crie um novo
      if (existingBindersResponse.data.isEmpty) {
        final binderId = generateUniqueBinderId(); // Gere um ID único para o binder
        final response = await _supabaseClient!.from('binders').insert({
          'id': binderId,
          'name': 'Primeiro Binder',
          'user_id': _currentUserId,
          'cover_asset': 'assets/capas/capabinder2.png', // ou qualquer outro
        }).execute();

        // Verifique se a resposta não é nula antes de acessar response.data
        if (response == null) {
          print('Erro: resposta nula ao inserir binder no Supabase.');
          return;
        }

        print('Resposta da inserção: ${response.data}'); // Verifique a resposta da inserção

        // Verifique se a resposta da inserção é bem-sucedida
        if (response.data == null) {
          print('Erro ao inserir binder: ${response.status}');
          return;
        }

        print('Novo binder criado com sucesso!');
      } else {
        print('Já existem binders para esse usuário.');
      }
    } catch (e) {
      print('Erro ao criar novo binder: $e');
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
  final String name;

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
    required this.name,
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
      name: map['name'] as String,
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
      'name': name,
    };
  }
}
