import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sticker_data.dart';
import 'supabase_service.dart';

class StickerService {
  final _supabase = Supabase.instance.client;
  final _supabaseService = SupabaseService();

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
      final stickersData = await _supabaseService.loadStickersFromSupabase(binderId);
      return stickersData.map((data) => StickerData(
        id: data['id'],
        imagePath: data['image_path'],
        x: (data['x'] as num).toDouble(),
        y: (data['y'] as num).toDouble(),
        scale: (data['scale'] as num?)?.toDouble() ?? 1.0,
        rotation: (data['rotation'] as num?)?.toDouble() ?? 0.0,
      )).toList();
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
        // No need to save to local storage here as we're already syncing with Supabase
        // The next call to getStickersForBinder will fetch from Supabase
      }
    } catch (e) {
      print('⚠️ Erro ao sincronizar adesivos com Supabase: $e');
    }
  }

  // Salva ou atualiza adesivos no Supabase
  Future<void> _saveStickersToSupabase(
      String binderId, List<StickerData> stickers) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Busca os stickers existentes
      final existingStickers = await _supabase
          .from('binder_stickers')
          .select('id, image_path, position_x, position_y, scale, rotation')
          .eq('user_id', userId)
          .eq('binder_id', binderId);

      // Separa os stickers em novos e existentes
      final List<Map<String, dynamic>> newStickers = [];
      final List<Map<String, dynamic>> updatedStickers = [];
      final Set<String> existingStickerIds = (existingStickers as List?)?.map((s) => s['id'] as String).toSet() ?? {};

      for (final sticker in stickers) {
        // Verifica se o sticker já existe comparando pelo ID
        final existingSticker = (existingStickers as List?)?.firstWhere(
          (s) => s['id'] == sticker.id,  // Compara com o ID do sticker
          orElse: () => null,
        );

        final stickerData = {
          'user_id': userId,
          'binder_id': binderId,
          'image_path': sticker.imagePath,
          'position_x': sticker.x,
          'position_y': sticker.y,
          'scale': sticker.scale,
          'rotation': sticker.rotation,
        };
        
        // Se encontrou um sticker existente, mantém o ID original
        if (existingSticker != null) {
          stickerData['id'] = existingSticker['id'];
        } else {
          // Para novos stickers, define o ID fornecido
          stickerData['id'] = sticker.id;
        }

        if (existingSticker != null) {
          // Atualiza apenas se a posição, escala ou rotação mudaram
          if (existingSticker['position_x'] != sticker.x ||
              existingSticker['position_y'] != sticker.y ||
              existingSticker['scale'] != sticker.scale ||
              existingSticker['rotation'] != sticker.rotation) {
            updatedStickers.add({
              'id': existingSticker['id'],
              ...stickerData,
            });
          }
        } else {
          newStickers.add(stickerData);
        }
      }


      // Remove stickers que não estão mais na lista
      final stickerIds = stickers.map((s) => s.id).toList();
      if (stickerIds.isNotEmpty) {
        await _supabase
            .from('binder_stickers')
            .delete()
            .eq('user_id', userId)
            .eq('binder_id', binderId)
            .not('id', 'in', stickerIds);
      }

      // Insere novos stickers
      if (newStickers.isNotEmpty) {
        await _supabase.from('binder_stickers').insert(newStickers);
      }

      // Atualiza stickers existentes
      for (final sticker in updatedStickers) {
        final id = sticker['id'];
        await _supabase
            .from('binder_stickers')
            .update({
              'position_x': sticker['position_x'],
              'position_y': sticker['position_y'],
              'scale': sticker['scale'],
              'rotation': sticker['rotation']
            })
            .eq('id', id);
      }
    } catch (e) {
      print('⚠️ Erro ao salvar adesivos no Supabase: $e');
      rethrow;
    }
  }
}
