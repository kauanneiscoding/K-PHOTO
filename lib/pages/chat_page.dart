import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:k_photo/widgets/avatar_with_frame.dart';
import 'package:k_photo/services/chat_service.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class ChatPage extends StatefulWidget {
  final String friendUserId;
  final String friendUsername;
  final String? friendDisplayName;
  final String? friendAvatarUrl;
  final String? friendSelectedFrame;

  const ChatPage({
    Key? key,
    required this.friendUserId,
    required this.friendUsername,
    this.friendDisplayName,
    this.friendAvatarUrl,
    this.friendSelectedFrame,
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SupabaseClient _supabase = Supabase.instance.client;
  final ChatService _chatService = ChatService();
  
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  String? _conversationId;
  DateTime? _oldestMessageTime;
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  
  // Typing indicators
  bool _isFriendTyping = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _initializeChat() async {
    await _loadInitialMessages();
    if (!mounted) return;

    _markMessagesAsRead();
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageSubscription?.cancel();
    _typingTimer?.cancel();
    _chatService.unsubscribeFromMessages();
    super.dispose();
  }

  Future<void> _loadInitialMessages() async {
    try {
      // Obtém ou cria a conversa primeiro
      _conversationId = await _chatService.getOrCreateConversation(widget.friendUserId);
      debugPrint('🔗 Conversation ID: $_conversationId');
      
      final response = await _chatService.getRecentMessages(widget.friendUserId);

      if (mounted) {
        setState(() {
          _messages = response;
          _isLoading = false;
          _hasMoreMessages = response.length >= 50;
          if (response.isNotEmpty) {
            _oldestMessageTime = DateTime.tryParse(response.first['created_at'] ?? '');
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar mensagens iniciais: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _oldestMessageTime == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final olderMessages = await _chatService.getMessages(
        widget.friendUserId,
        limit: 30,
        before: _oldestMessageTime,
      );

      if (mounted) {
        setState(() {
          if (olderMessages.isNotEmpty) {
            _messages = [...olderMessages, ..._messages];
            _oldestMessageTime = DateTime.tryParse(olderMessages.first['created_at'] ?? '');
            _hasMoreMessages = olderMessages.length >= 30;
          } else {
            _hasMoreMessages = false;
          }
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar mais mensagens: $e');
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _setupRealtimeListener() {
    if (_conversationId == null) {
      debugPrint('❌ Conversation ID é nulo');
      return;
    }
    
    _messageSubscription = _chatService
        .subscribeToMessages(_conversationId!)
        .listen(
          (data) {
            if (!mounted) return;
            
            // Verifica se é typing indicator ou mensagem
            if (data['type'] == 'typing') {
              _handleTypingIndicator(data);
            } else {
              _handleNewMessage(data);
            }
          },
          onError: (error) {
            debugPrint('❌ Erro no realtime: $error');
          },
        );
  }

  void _handleTypingIndicator(Map<String, dynamic> data) {
    final isTyping = data['isTyping'] ?? false;
    final userId = data['userId'];
    final currentUserId = _supabase.auth.currentUser?.id;
    
    // Só processa typing do outro usuário
    if (userId != currentUserId && mounted) {
      setState(() {
        _isFriendTyping = isTyping;
      });
    }
  }

  void _handleNewMessage(Map<String, dynamic> newMessage) {
    debugPrint('🔥 Realtime: Nova mensagem recebida');
    debugPrint('📝 ${newMessage['content']}');
    
    // Verifica se a mensagem já existe para evitar duplicatas
    if (!_messages.any((msg) => msg['id'] == newMessage['id'])) {
      setState(() {
        _messages.add(newMessage);
        // Ordena mensagens por data
        _messages.sort((a, b) {
          final aTime = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now();
          final bTime = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.now();
          return aTime.compareTo(bTime);
        });
      });
      _scrollToBottom();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreMessages();
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      await _chatService.markMessagesAsRead(widget.friendUserId);
    } catch (e) {
      debugPrint('❌ Erro ao marcar mensagens como lidas: $e');
    }
  }

  void _onTextChanged(String text) {
    if (_conversationId == null) return;
    
    // Envia indicador de digitação
    _chatService.sendTypingIndicator(_conversationId!, true);
    
    // Cancela timer anterior
    _typingTimer?.cancel();
    
    // Configura timer para parar o indicador após 2 segundos
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_conversationId != null) {
        _chatService.sendTypingIndicator(_conversationId!, false);
      }
    });
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      // Apenas envia para o banco - não adiciona localmente
      await _chatService.sendMessage(
        _conversationId!,
        widget.friendUserId,
        messageText,
      );
      
      // Limpa o campo de input - a mensagem chegará via realtime
      if (mounted) {
        setState(() {
          _messageController.clear();
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao enviar mensagem: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao enviar mensagem'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'Agora';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) {
      return DateFormat('HH:mm').format(dateTime);
    }
    if (difference.inDays < 7) {
      return DateFormat('EEE').format(dateTime);
    }
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _supabase.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.pink.shade50,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.pink.shade600),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            AvatarWithFrame(
              imageUrl: widget.friendAvatarUrl,
              framePath: widget.friendSelectedFrame ?? 'assets/frame_none.png',
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.friendDisplayName?.isNotEmpty == true 
                        ? widget.friendDisplayName!
                        : widget.friendUsername,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.pink.shade800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '@${widget.friendUsername}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.pink.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.pink.shade50,
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            // Lista de mensagens
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: Colors.pink.shade400),
                    )
                  : _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: Colors.pink.shade200,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Nenhuma mensagem ainda.\nComece uma conversa! 💕',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.pink.shade400,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _messages.length + (_hasMoreMessages ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Indicator de carregamento no topo
                            if (index == 0 && _hasMoreMessages) {
                              return Container(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: _isLoadingMore
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.pink.shade400,
                                          ),
                                        )
                                      : Text(
                                          'Puxe para carregar mais',
                                          style: TextStyle(
                                            color: Colors.pink.shade400,
                                            fontSize: 12,
                                          ),
                                        ),
                                ),
                              );
                            }

                            final messageIndex = _hasMoreMessages ? index - 1 : index;
                            if (messageIndex < 0 || messageIndex >= _messages.length) {
                              return const SizedBox.shrink();
                            }

                            final message = _messages[messageIndex];
                            final isMe = message['sender_id'] == currentUserId;
                            final createdAt = DateTime.tryParse(message['created_at'] ?? '') ?? DateTime.now();

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                children: [
                                  if (!isMe) ...[
                                    AvatarWithFrame(
                                      imageUrl: widget.friendAvatarUrl,
                                      framePath: widget.friendSelectedFrame ?? 'assets/frame_none.png',
                                      size: 32,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Flexible(
                                    child: Container(
                                      constraints: BoxConstraints(
                                        maxWidth: MediaQuery.of(context).size.width * 0.7,
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isMe 
                                            ? Colors.pink.shade400
                                            : Colors.white,
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(20),
                                          topRight: const Radius.circular(20),
                                          bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                                          bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.pink.withOpacity(0.1),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            message['content'] ?? '',
                                            style: TextStyle(
                                              color: isMe ? Colors.white : Colors.pink.shade800,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatTime(createdAt),
                                            style: TextStyle(
                                              color: isMe 
                                                  ? Colors.white.withOpacity(0.8)
                                                  : Colors.pink.shade400,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 8),
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.pink.shade100,
                                      child: Icon(
                                        Icons.person,
                                        color: Colors.pink.shade400,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
            ),

            // Indicador de digitação
            if (_isFriendTyping)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    AvatarWithFrame(
                      imageUrl: widget.friendAvatarUrl,
                      framePath: widget.friendSelectedFrame ?? 'assets/frame_none.png',
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.friendDisplayName?.isNotEmpty == true ? widget.friendDisplayName! : widget.friendUsername} está digitando...',
                      style: TextStyle(
                        color: Colors.pink.shade600,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.pink.shade400,
                      ),
                    ),
                  ],
                ),
              ),

            // Campo de input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.pink.shade50,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.pink.shade200, width: 1),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Digite uma mensagem...',
                          hintStyle: TextStyle(color: Colors.pink.shade300),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          suffixIcon: _isSending
                              ? Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.pink.shade400,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        style: TextStyle(color: Colors.pink.shade800),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        onChanged: _onTextChanged,
                        enabled: !_isSending,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.pink.shade400,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.pink.shade300.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _isSending ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}