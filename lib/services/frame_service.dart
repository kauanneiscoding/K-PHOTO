import 'package:supabase_flutter/supabase_flutter.dart';

class FrameService {
  static final SupabaseClient _supabaseClient = Supabase.instance.client;
  static String? _currentUserId;

  static void setCurrentUserId(String userId) {
    _currentUserId = userId;
  }

  /// Verifica se um frame foi comprado pelo usuário atual
  static Future<bool> isFramePurchased(String framePath) async {
    if (_currentUserId == null) {
      print('⚠️ Tentativa de verificar frame sem usuário definido');
      return false;
    }

    try {
      final response = await _supabaseClient
          .from('purchased_frames')
          .select('frame_path')
          .eq('user_id', _currentUserId!)
          .eq('frame_path', framePath);

      return response.isNotEmpty;
    } catch (e) {
      print('❌ Erro ao verificar frame comprado: $e');
      return false;
    }
  }

  /// Registra a compra de um frame para o usuário atual
  static Future<bool> purchaseFrame(String framePath) async {
    if (_currentUserId == null) {
      print('⚠️ Tentativa de comprar frame sem usuário definido');
      return false;
    }

    try {
      await _supabaseClient
          .from('purchased_frames')
          .upsert({
            'user_id': _currentUserId!,
            'frame_path': framePath,
            'purchased_at': DateTime.now().toIso8601String(),
          });

      print('✅ Frame $framePath comprado com sucesso');
      return true;
    } catch (e) {
      print('❌ Erro ao comprar frame: $e');
      return false;
    }
  }

  /// Obtém todos os frames comprados pelo usuário atual
  static Future<List<String>> getPurchasedFrames() async {
    if (_currentUserId == null) {
      print('⚠️ Tentativa de obter frames sem usuário definido');
      return [];
    }

    try {
      final response = await _supabaseClient
          .from('purchased_frames')
          .select('frame_path')
          .eq('user_id', _currentUserId!);

      return List<String>.from(response.map((item) => item['frame_path']));
    } catch (e) {
      print('❌ Erro ao obter frames comprados: $e');
      return [];
    }
  }

  /// Remove um frame da lista de comprados (se necessário)
  static Future<bool> removePurchasedFrame(String framePath) async {
    if (_currentUserId == null) {
      print('⚠️ Tentativa de remover frame sem usuário definido');
      return false;
    }

    try {
      await _supabaseClient
          .from('purchased_frames')
          .delete()
          .eq('user_id', _currentUserId!)
          .eq('frame_path', framePath);

      print('✅ Frame $framePath removido com sucesso');
      return true;
    } catch (e) {
      print('❌ Erro ao remover frame: $e');
      return false;
    }
  }
}
