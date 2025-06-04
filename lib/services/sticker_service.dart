import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sticker_data.dart';
import 'data_storage_service.dart';

class StickerService {
  final _supabase = Supabase.instance.client;
  final DataStorageService _dataStorage = DataStorageService();

  // Carrega adesivos do cache local e sincroniza com o Supabase
  Future<List<StickerData>> getStickersForBinder(String binderId) async {
    try {
      // Tenta carregar do cache local primeiro
      final localStickers = await _loadLocalStickers(binderId);
      
      // Sincroniza com o Supabase em segundo plano
      _syncWithSupabase(binderId);
      
      return localStickers;
    } catch (e) {
      print('❌ Erro ao carregar adesivos: $e');
      return [];
    }
  }

  // Salva adesivos localmente e no Supabase
  Future<void> saveStickers(String binderId, List<StickerData> stickers) async {
    try {
      // Converte para o formato de mapa para armazenamento
      final stickersData = stickers.map((sticker) => sticker.toMap()).toList();
      
      // Salva localmente
      await _dataStorage.saveStickersOnBinder(binderId, stickersData);
      
      // Sincroniza com o Supabase
      await _saveStickersToSupabase(binderId, stickers);
      
    } catch (e) {
      print('❌ Erro ao salvar adesivos: $e');
      rethrow;
    }
  }

  // Carrega adesivos do cache local
  Future<List<StickerData>> _loadLocalStickers(String binderId) async {
    try {
      final stickersData = await _dataStorage.loadStickersFromBinder(binderId);
      return stickersData.map((data) => StickerData.fromMap(data)).toList();
    } catch (e) {
      print('⚠️ Erro ao carregar adesivos locais: $e');
      return [];
    }
  }

  // Sincroniza adesivos locais com o Supabase
  Future<void> _syncWithSupabase(String binderId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('binder_stickers')
          .select('*')
          .eq('user_id', userId)
          .eq('binder_id', binderId);

      if (response != null) {
        final stickers = (response as List)
            .map((data) => StickerData.fromMap(data))
            .toList();
            
        await _dataStorage.saveStickersOnBinder(
          binderId, 
          stickers.map((s) => s.toMap()).toList()
        );
      }
    } catch (e) {
      print('⚠️ Erro ao sincronizar adesivos com Supabase: $e');
    }
  }

  // Salva adesivos no Supabase
  Future<void> _saveStickersToSupabase(
      String binderId, List<StickerData> stickers) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Remove os adesivos antigos
      await _supabase
          .from('binder_stickers')
          .delete()
          .eq('user_id', userId)
          .eq('binder_id', binderId);

      // Prepara os novos adesivos para inserção
      if (stickers.isNotEmpty) {
        final entries = stickers.map((sticker) => ({
              'user_id': userId,
              'binder_id': binderId,
              'sticker_id': sticker.id,
              'pos_x': sticker.x,
              'pos_y': sticker.y,
              'scale': sticker.scale,
              'rotation': sticker.rotation,
              'image_path': sticker.imagePath,
            })).toList();

        await _supabase.from('binder_stickers').insert(entries);
      }
    } catch (e) {
      print('⚠️ Erro ao salvar adesivos no Supabase: $e');
      rethrow;
    }
  }
}
