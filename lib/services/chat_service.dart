import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Obtém a lista de conversas do usuário atual
  Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('Usuário não autenticado');

      final response = await _supabase
          .from('conversations')
          .select('''
            *,
            user1:user1_id(id, username, display_name, avatar_url, selected_frame),
            user2:user2_id(id, username, display_name, avatar_url, selected_frame),
            last_message:last_message_id(id, content, created_at, sender_id)
          ''')
          .or('user1_id.eq.$currentUserId,user2_id.eq.$currentUserId')
          .order('updated_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erro ao carregar conversas: $e');
    }
  }

  /// Obtém mensagens entre o usuário atual e outro usuário
  Future<List<Map<String, dynamic>>> getMessages(String otherUserId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('Usuário não autenticado');

      final response = await _supabase
          .from('messages')
          .select('*')
          .or('and(sender_id.eq.$currentUserId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$currentUserId)')
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erro ao carregar mensagens: $e');
    }
  }

  /// Envia uma mensagem para outro usuário
  Future<Map<String, dynamic>> sendMessage(String receiverId, String content) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('Usuário não autenticado');

      // Primeiro, verifica se já existe uma conversa entre os usuários
      final existingConversation = await _getConversationBetweenUsers(currentUserId, receiverId);

      String conversationId;
      if (existingConversation != null) {
        conversationId = existingConversation['id'];
      } else {
        // Cria nova conversa
        final newConversation = await _supabase
            .from('conversations')
            .insert({
              'user1_id': currentUserId,
              'user2_id': receiverId,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();
        conversationId = newConversation['id'];
      }

      // Envia a mensagem
      final messageData = {
        'conversation_id': conversationId,
        'sender_id': currentUserId,
        'receiver_id': receiverId,
        'content': content,
        'created_at': DateTime.now().toIso8601String(),
      };

      final message = await _supabase
          .from('messages')
          .insert(messageData)
          .select()
          .single();

      // Atualiza a conversa com a última mensagem
      await _supabase
          .from('conversations')
          .update({
            'last_message_id': message['id'],
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', conversationId);

      return message;
    } catch (e) {
      throw Exception('Erro ao enviar mensagem: $e');
    }
  }

  /// Marca mensagens como lidas
  Future<void> markMessagesAsRead(String senderId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('Usuário não autenticado');

      await _supabase
          .from('messages')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('sender_id', senderId)
          .eq('receiver_id', currentUserId)
          .is_('read_at', 'null');
    } catch (e) {
      throw Exception('Erro ao marcar mensagens como lidas: $e');
    }
  }

  /// Obtém o número de mensagens não lidas
  Future<int> getUnreadCount() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('Usuário não autenticado');

      final response = await _supabase
          .from('messages')
          .select('id')
          .eq('receiver_id', currentUserId)
          .is_('read_at', 'null');

      return (response as List).length;
    } catch (e) {
      throw Exception('Erro ao contar mensagens não lidas: $e');
    }
  }

  /// Obtém informações básicas de um usuário
  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
      final response = await _supabase
          .from('user_profile')
          .select('username, display_name, avatar_url, selected_frame')
          .eq('user_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      throw Exception('Erro ao obter informações do usuário: $e');
    }
  }

  /// Verifica se existe uma conversa entre dois usuários
  Future<Map<String, dynamic>?> _getConversationBetweenUsers(String user1Id, String user2Id) async {
    try {
      final response = await _supabase
          .from('conversations')
          .select('*')
          .or('and(user1_id.eq.$user1Id,user2_id.eq.$user2Id),and(user1_id.eq.$user2Id,user2_id.eq.$user1Id)')
          .maybeSingle();

      return response;
    } catch (e) {
      return null;
    }
  }

  /// Obtém ou cria uma conversa entre dois usuários
  Future<String> getOrCreateConversation(String otherUserId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('Usuário não autenticado');

      final existingConversation = await _getConversationBetweenUsers(currentUserId, otherUserId);
      
      if (existingConversation != null) {
        return existingConversation['id'];
      } else {
        final newConversation = await _supabase
            .from('conversations')
            .insert({
              'user1_id': currentUserId,
              'user2_id': otherUserId,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();
        return newConversation['id'];
      }
    } catch (e) {
      throw Exception('Erro ao obter ou criar conversa: $e');
    }
  }
}
