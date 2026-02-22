import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _currentChannel;
  String? _currentConversationId;

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

  /// Obtém mensagens entre o usuário atual e outro usuário com paginação
  Future<List<Map<String, dynamic>>> getMessages(String otherUserId, {int limit = 50, DateTime? before}) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('Usuário não autenticado');

      var query = _supabase
          .from('messages')
          .select('*')
          .or('and(sender_id.eq.$currentUserId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$currentUserId)');

      if (before != null) {
        query = query.lt('created_at', before.toIso8601String());
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response.reversed);
    } catch (e) {
      throw Exception('Erro ao carregar mensagens: $e');
    }
  }

  /// Obtém mensagens mais recentes (para carga inicial)
  Future<List<Map<String, dynamic>>> getRecentMessages(String otherUserId, {int limit = 50}) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('Usuário não autenticado');

      final response = await _supabase
          .from('messages')
          .select('*')
          .or('and(sender_id.eq.$currentUserId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$currentUserId)')
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response.reversed);
    } catch (e) {
      throw Exception('Erro ao carregar mensagens recentes: $e');
    }
  }

  /// Envia uma mensagem para outro usuário
  Future<void> sendMessage(
    String conversationId,
    String receiverId,
    String content,
  ) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('Usuário não autenticado');

    await _supabase.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': currentUserId,
      'receiver_id': receiverId,
      'content': content,
    });
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

  /// Inicia listener realtime para novas mensagens e typing indicators
  Stream<Map<String, dynamic>> subscribeToMessages(String conversationId) {
    final controller = StreamController<Map<String, dynamic>>();

    // Se já existe um channel para outra conversa, limpa
    if (_currentChannel != null && _currentConversationId != conversationId) {
      _currentChannel?.unsubscribe();
      _currentChannel = null;
    }

    // Cria o channel uma única vez
    _currentChannel ??= _supabase.channel('chat_$conversationId');
    _currentConversationId = conversationId;

    // 👇 LISTENER DE MENSAGENS
    _currentChannel!.on(
      RealtimeListenTypes.postgresChanges,
      ChannelFilter(
        event: 'INSERT',
        schema: 'public',
        table: 'messages',
        filter: 'conversation_id=eq.$conversationId',
      ),
      (payload, [ref]) {
        debugPrint('🔥 Nova mensagem realtime');
        controller.add(payload['new']);
      },
    );

    // 👇 LISTENER DE TYPING INDICATORS
    _currentChannel!.on(
      RealtimeListenTypes.broadcast,
      ChannelFilter(event: 'typing'),
      (payload, [ref]) {
        final isTyping = payload['isTyping'] ?? false;
        final userId = payload['userId'];

        debugPrint('⌨️ $userId está digitando: $isTyping');
        
        // Envia dados do typing para o stream
        controller.add({
          'type': 'typing',
          'isTyping': isTyping,
          'userId': userId,
        });
      },
    );

    _currentChannel!.subscribe();

    return controller.stream;
  }

  /// Para o listener realtime
  void unsubscribeFromMessages() {
    _currentChannel?.unsubscribe();
    _currentChannel = null;
    _currentConversationId = null;
    debugPrint('🔥 Realtime channel finalizado');
  }

  /// Obtém mensagens mais recentes que uma data específica
  Future<List<Map<String, dynamic>>> getMessagesAfter(String otherUserId, DateTime after) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('Usuário não autenticado');

      var query = _supabase
          .from('messages')
          .select('*')
          .or('and(sender_id.eq.$currentUserId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$currentUserId)')
          .gt('created_at', after.toIso8601String());

      final response = await query
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erro ao carregar mensagens recentes: $e');
    }
  }

  /// Envia indicador de digitação via broadcast
  Future<void> sendTypingIndicator(String conversationId, bool isTyping) async {
    // Usa o channel existente ou cria um novo
    if (_currentChannel == null || _currentConversationId != conversationId) {
      _currentChannel = _supabase.channel('chat_$conversationId');
      _currentConversationId = conversationId;
      _currentChannel!.subscribe();
    }
    
    // Usa o MESMO channel para enviar
    _currentChannel!.send(
      type: RealtimeListenTypes.broadcast,
      event: 'typing',
      payload: {
        'isTyping': isTyping,
        'userId': _supabase.auth.currentUser?.id,
      },
    );
  }
}