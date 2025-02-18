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

      // Priorizar binders do Supabase
      if (supabaseBinders.isNotEmpty) {
        // Limpar binders locais antes de adicionar os do Supabase
        for (var localBinder in localBinders) {
          await _supabase.from('binders').delete().eq('id', localBinder['id']);
        }

        // Adicionar binders do Supabase localmente
        for (var binderData in supabaseBinders) {
          await _dataStorage.addBinder(
            binderData['id'], 
            binderData['slots'] ?? '[]'
          );
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
          await _supabase.from('binders').upsert({
            'id': newBinderId,
            'user_id': _currentUserId,
            'slots': newBinder['slots'] ?? '[]',
            'cover_asset': newBinder['cover_asset'],
            'spine_asset': newBinder['spine_asset'],
            'binder_name': newBinder['binder_name'] ?? newBinderId,
            'created_at': newBinder['created_at'] ?? DateTime.now().toIso8601String(),
          });
          print('☁️ Novo binder sincronizado com Supabase');
        }
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

  Future<void> syncUserBalance() async {
    try {
      final balance = await _dataStorage.getUserCoins();
      print('💰 Saldo local - K-Coins: ${balance}');

      await _supabase.from('user_coins').upsert({
        'user_id': _currentUserId,
        'coins': balance,
      });

      print('☁️ Saldo sincronizado com Supabase');
    } catch (e, stackTrace) {
      print('❌ Erro ao sincronizar saldo: $e');
      print('Detalhes do erro: $stackTrace');
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
