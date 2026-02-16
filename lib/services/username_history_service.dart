import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UsernameHistoryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Salva o username antigo no histórico ao trocar
  Future<void> saveUsernameToHistory(String userId, String oldUsername) async {
    try {
      await _supabase.from('username_history').insert({
        'user_id': userId,
        'username': oldUsername,
        'changed_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now().add(Duration(days: 30)).toIso8601String(),
      });
      
      debugPrint('✅ Username "$oldUsername" salvo no histórico por 30 dias');
    } catch (e) {
      debugPrint('❌ Erro ao salvar username no histórico: $e');
      rethrow;
    }
  }

  /// Verifica se um username está disponível (não está em uso nem no histórico)
  Future<bool> isUsernameAvailable(String username, {String? currentUserId}) async {
    try {
      // 1. Verifica se está em uso atualmente
      final currentUse = await _supabase
          .from('user_profile')
          .select('username')
          .eq('username', username)
          .neq('user_id', currentUserId ?? '')
          .maybeSingle();

      if (currentUse != null) {
        return false; // Já está em uso
      }

      // 2. Verifica se está no histórico (bloqueado por 30 dias)
      final historyCheck = await _supabase
          .from('username_history')
          .select('username')
          .eq('username', username)
          .gt('expires_at', DateTime.now().toIso8601String())
          .maybeSingle();

      return historyCheck == null; // Disponível se não está no histórico
    } catch (e) {
      debugPrint('❌ Erro ao verificar disponibilidade do username: $e');
      return false;
    }
  }

  /// Limpa registros expirados do histórico
  Future<void> cleanupExpiredUsernames() async {
    try {
      await _supabase.rpc('cleanup_expired_usernames');
      debugPrint('🧹 Limpeza de usernames expirados concluída');
    } catch (e) {
      debugPrint('❌ Erro ao limpar usernames expirados: $e');
    }
  }

  /// Obtém o histórico de usernames de um usuário
  Future<List<Map<String, dynamic>>> getUserUsernameHistory(String userId) async {
    try {
      final response = await _supabase
          .from('username_history')
          .select('username, changed_at, expires_at')
          .eq('user_id', userId)
          .order('changed_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Erro ao obter histórico de usernames: $e');
      return [];
    }
  }

  /// Verifica se um username específico expirou (pode ser reutilizado)
  Future<bool> isUsernameExpired(String username) async {
    try {
      final result = await _supabase
          .from('username_history')
          .select('expires_at')
          .eq('username', username)
          .maybeSingle();

      if (result == null) return true; // Não está no histórico

      final expiresAt = DateTime.parse(result['expires_at']);
      return DateTime.now().isAfter(expiresAt);
    } catch (e) {
      debugPrint('❌ Erro ao verificar expiração do username: $e');
      return false;
    }
  }
}
