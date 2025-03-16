import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:k_photo/data_storage_service.dart';
import 'package:k_photo/models/photocard.dart';
import 'package:k_photo/models/binder.dart';

class UserSyncService {
  final SupabaseClient _supabase;
  final DataStorageService _dataStorage;
  String? _currentUserId;

  UserSyncService(this._supabase, this._dataStorage);

  void setCurrentUser(String userId) {
    _currentUserId = userId;
    _dataStorage.setCurrentUser(userId);
  }

  Future<void> syncPhotocards() async {
    if (_currentUserId == null) return;

    try {
      final localPhotocards = await _dataStorage.getAllPhotocards();

      await _supabase
        .from('user_photocards')
        .upsert(localPhotocards.map((pc) => {
          'user_id': _currentUserId,
          'photocard_data': pc.toMap()
        }).toList());
    } catch (e) {
      print('Erro ao sincronizar photocards: $e');
    }
  }

  Future<void> syncCoins() async {
    if (_currentUserId == null) return;

    try {
      final coins = await _dataStorage.getUserCoins();

      await _supabase
        .from('user_coins')
        .upsert({
          'user_id': _currentUserId,
          'coins': coins
        });
    } catch (e) {
      print('Erro ao sincronizar moedas: $e');
    }
  }

  Future<void> syncBinders() async {
    try {
      // Recuperar binders do Supabase primeiro
      final supabaseBinders = await _supabase
        .from('binders')
        .select()
        .eq('user_id', _currentUserId);
      
      print('🔍 Binders do Supabase encontrados: ${supabaseBinders.length}');

      // Recuperar binders locais
      final localBinders = await _dataStorage.getAllBinders();
      print('🔍 Binders locais encontrados: ${localBinders.length}');

      // Se há binders no Supabase, sincronizar com os locais
      if (supabaseBinders.isNotEmpty) {
        // Atualizar ou adicionar binders do Supabase localmente
        for (var binderData in supabaseBinders) {
          // Log dos dados do Supabase
          print('📡 Dados do Binder no Supabase:');
          print('   ID: ${binderData['id']}');
          print('   Nome (name): ${binderData['name']}');
          print('   Nome (binder_name): ${binderData['binder_name']}');

          // Garantir que os dados sejam do tipo correto
          final binderId = (binderData['id'] ?? '').toString();
          final slots = (binderData['slots'] ?? '[]').toString();
          final coverAsset = (binderData['cover_asset'] ?? '').toString();
          final spineAsset = (binderData['spine_asset'] ?? '').toString();
          
          // Priorizar 'name', com fallback para 'binder_name', e então um nome genérico
          final binderName = (
            binderData['name'] ?? 
            binderData['binder_name'] ?? 
            'Binder Sem Nome'
          ).toString();

          // Log do nome processado
          print('🏷️ Nome do Binder Processado: $binderName');

          // Verificar se o binder já existe localmente usando comparação de string
          final existingLocalBinder = localBinders.firstWhere(
            (local) => local['id'].toString() == binderId, 
            orElse: () => <String, dynamic>{}
          );

          if (existingLocalBinder.isEmpty) {
            // Adicionar novo binder se não existir
            final newBinderId = await _dataStorage.addNewBinder();
            
            // Atualizar o binder recém-criado com os dados do Supabase
            await _dataStorage.updateBinderCovers(newBinderId, coverAsset, spineAsset);
          } else {
            // Atualizar binder existente com dados do Supabase
            await _dataStorage.updateBinderCovers(
              binderId, 
              coverAsset,
              spineAsset
            );
          }
        }
        print('☁️ ${supabaseBinders.length} binders sincronizados do Supabase');
      } 
      // Se não há binders no Supabase, criar um inicial APENAS se local também estiver vazio
      else if (localBinders.isEmpty) {
        print('⚠️ Nenhum binder encontrado. Criando binder inicial.');
        final newBinderId = await _dataStorage.addNewBinder();
        print('✨ Novo binder criado com ID: $newBinderId');

        // Sincronizar o novo binder com o Supabase
        final newBinder = await _dataStorage.getBinder(newBinderId);
        if (newBinder != null) {
          // Log dos dados antes da sincronização
          print('📤 Dados para Sincronização com Supabase:');
          print('   ID: $newBinderId');
          print('   Nome: ${newBinder['binder_name']}');

          // Adicionar log para verificar o valor de binder_name antes de enviar
          print('binder_name antes de enviar para o Supabase: ${newBinder['binder_name']}');

          // Substituir null com um valor padrão
          String binderName = newBinder['binder_name'] ?? 'Nome Padrão';  // Caso binder_name seja nulo, usaremos 'Nome Padrão'

          await _supabase.from('binders').upsert({
            'id': newBinderId,
            'user_id': _currentUserId,
            'slots': newBinder['slots'] ?? '[]',
            'cover_asset': newBinder['cover_asset'],
            'spine_asset': newBinder['spine_asset'],
            'name': binderName,  // Usando binderName agora, com valor garantido
            'created_at': newBinder['created_at'] ?? DateTime.now().toIso8601String(),
          });
          print('☁️ Novo binder sincronizado com Supabase');
        }
      }

      // Sincronizar todos os binders locais com Supabase
      final updatedLocalBinders = await _dataStorage.getAllBinders();
      for (var localBinder in updatedLocalBinders) {
        // Log dos dados locais antes da sincronização
        print('📤 Dados do Binder Local para Supabase:');
        print('   ID: ${localBinder['id']}');
        print('   Nome: ${localBinder['binder_name']}');

        // Adicionar log para verificar o valor de binder_name antes de enviar
        print('binder_name antes de enviar para o Supabase: ${localBinder['binder_name']}');

        // Substituir null com um valor padrão
        String binderName = localBinder['binder_name'] ?? 'Nome Padrão';  // Caso binder_name seja nulo, usaremos 'Nome Padrão'

        await _supabase.from('binders').upsert({
          'id': localBinder['id'].toString(),
          'user_id': _currentUserId,
          'slots': localBinder['slots'] ?? '[]',
          'cover_asset': localBinder['cover_asset'],
          'spine_asset': localBinder['spine_asset'],
          'name': binderName,  // Usando binderName agora, com valor garantido
          'created_at': localBinder['created_at'] ?? DateTime.now().toIso8601String(),
        });
      }

      // Verificar novamente se há binders após a sincronização
      final verifyBinders = await _dataStorage.getAllBinders();
      if (verifyBinders.isEmpty) {
        print('❌ ERRO CRÍTICO: Falha ao criar binder inicial');
        throw Exception('Não foi possível criar um binder inicial');
      }
    } catch (e, stackTrace) {
      print('❌ Erro ao sincronizar binders: $e');
      print('Detalhes do erro: $stackTrace');
      
      // Verificar se já existem binders antes de criar um novo
      final existingBinders = await _dataStorage.getAllBinders();
      if (existingBinders.isEmpty) {
        try {
          final fallbackBinderId = await _dataStorage.addNewBinder();
          print('🚨 Binder de emergência criado: $fallbackBinderId');
        } catch (fallbackError) {
          print('❌ Falha crítica ao criar binder de emergência: $fallbackError');
        }
      }
    }
  }

  Future<void> updateBinderCovers(String binderId, String newCover, String newSpine) async {
    try {
      // Buscar os dados do binder no Supabase
      final binderData = await _supabase
          .from('binders')
          .select('name')
          .eq('id', binderId)
          .maybeSingle();  // Usa maybeSingle() para evitar erro caso não haja resultado

      // Se o nome não existir, definir um valor padrão
      final binderName = binderData != null && binderData['name'] != null
          ? binderData['name']
          : "Binder Padrão";  // Nome padrão para evitar erro

      // Adicionar log antes da atualização para verificar o nome do binder
      print('Nome do Binder a ser enviado: $binderName');

      // Agora, realizar o update garantindo que name nunca será null
      await _supabase.from('binders').update({
        'name': binderName,  // Sempre enviando um nome válido
        'cover_asset': newCover,
        'spine_asset': newSpine,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', binderId);

      print('✅ Binder atualizado com sucesso: $binderId');
    } catch (e) {
      print('❌ Erro ao atualizar binder: $e');
    }
  }

  Future<void> verificarBinders() async {
    try {
      final response = await _supabase
          .from('binders')
          .select('*')
          .eq('user_id', _currentUserId); // Filtra pelos binders do usuário atual

      print("📌 Binders no Supabase antes de sair: $response");
    } catch (e) {
      print('❌ Erro ao verificar binders no Supabase: $e');
    }
  }

  Future<void> syncUserBalance() async {
    try {
      final balance = await _dataStorage.getUserCoins();
      print('💰 Saldo local - K-Coins: ${balance}');

      // Primeiro, tenta atualizar o saldo existente
      final updateResult = await _supabase
        .from('user_coins')
        .update({'coins': balance})
        .eq('user_id', _currentUserId)
        .select();

      // Se a atualização não afetou nenhuma linha, tenta inserir
      if (updateResult.isEmpty) {
        await _supabase.from('user_coins').upsert({
          'user_id': _currentUserId,
          'coins': balance,
        });
      }

      print('☁️ Saldo sincronizado com Supabase');
    } catch (e) {
      print('❌ Erro ao sincronizar saldo: $e');
      
      // Tenta recuperar o saldo existente do Supabase
      try {
        final existingBalance = await _supabase
          .from('user_coins')
          .select('coins')
          .eq('user_id', _currentUserId)
          .single();
        
        // Se conseguir recuperar, usa o saldo do Supabase
        if (existingBalance != null) {
          final supabaseCoins = existingBalance['coins'] as int;
          await _dataStorage.updateKCoins(supabaseCoins);
          print('📊 Saldo atualizado com valor do Supabase: $supabaseCoins');
        }
      } catch (recoveryError) {
        print('❌ Erro ao recuperar saldo do Supabase: $recoveryError');
      }
    }
  }

  Future<void> syncAllUserData() async {
    if (_currentUserId == null) {
      print('❌ UserSyncService: Nenhum usuário definido para sincronização');
      return;
    }

    try {
      print('🔄 Iniciando sincronização completa para usuário: $_currentUserId');

      // Sincronizar binders
      await syncBinders();
      
      // Sincronizar inventário
      await syncPhotocards();
      
      // Sincronizar saldo
      await syncUserBalance();
      
      print('✅ Sincronização completa realizada com sucesso');
    } catch (e, stackTrace) {
      print('❌ Erro durante sincronização completa: $e');
      print('Detalhes do erro: $stackTrace');
    }
  }
}
