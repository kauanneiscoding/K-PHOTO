import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:k_photo/widgets/avatar_with_frame.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:k_photo/friend_page.dart';
import 'package:k_photo/pages/friend_profile_page.dart';
import 'package:flutter/rendering.dart'; // Para CustomClipper

import '../models/post.dart';
import '../models/comment.dart' as comment_model;
import '../services/database.dart';
import '../data_storage_service.dart';
import '../services/social_service.dart';
import '../services/supabase_service.dart';

// Extensão para adicionar o método firstWhereOrNull ao Iterable
extension IterableExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

class FeedPage extends StatefulWidget {
  final DataStorageService dataStorageService;

  const FeedPage({
    super.key, 
    required this.dataStorageService
  });

  @override
  _FeedPageState createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final List<Post> _posts = [];
  late DatabaseHelper _dbHelper;
  final Set<String> _likedPosts = {};
  final Set<String> _repostedPosts = {};
  Map<String, List<comment_model.Comment>> _postComments = {};
  Map<String, int> _commentCounts = {};
  late final SupabaseService _supabaseService;

  @override
  void initState() {
    super.initState();
    _dbHelper = DatabaseHelper.instance;
    _supabaseService = SupabaseService();
    _updateLastSeen();
    _carregarPosts();
    _carregarPostsCurtidos();
    _carregarPostsRepostados();
  }

  Future<void> _updateLastSeen() async {
    try {
      await _supabaseService.updateLastSeen();
      print('✅ Último acesso atualizado com sucesso no FeedPage');
    } catch (e) {
      print('⚠️ Erro ao atualizar last_seen no FeedPage: $e');
      // Não interrompe o fluxo em caso de falha
    }
  }

  Future<void> _carregarPosts() async {
    final result = await SocialService().getFeedPosts();
    setState(() {
      _posts.clear();
      _posts.addAll(result.map((map) => Post.fromMap(map)));
    });
  }

  Future<void> _carregarPostsCurtidos() async {
    final likedPosts = await _dbHelper.getLikedPosts();
    setState(() {
      _likedPosts.clear();
      _likedPosts.addAll(likedPosts.map((id) => id.toString()));
    });
  }

  Future<void> _carregarPostsRepostados() async {
    final repostedPosts = await _dbHelper.getRepostedPosts();
    setState(() {
      _repostedPosts.clear();
      _repostedPosts.addAll(repostedPosts.map((id) => id.toString()));
    });
  }

  Future<void> _criarPost(String conteudo, String? midia) async {
    if (conteudo.isEmpty) return;
    await SocialService().createPost(conteudo, mediaPath: midia);
    await _carregarPosts();
  }


  Future<void> _curtirPost(Post post) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || post.id == null) return;

    try {
      // Toggle the like status using the SocialService
      await SocialService().toggleLike(post.id!, post.isLiked);
      
      // Update the local state to reflect the change
      setState(() {
        final index = _posts.indexWhere((p) => p.id == post.id);
        if (index != -1) {
          // Toggle the isLiked status
          final newIsLiked = !post.isLiked;
          // Update the likes count
          final newLikesCount = newIsLiked 
              ? post.likesCount + 1 
              : (post.likesCount > 0 ? post.likesCount - 1 : 0);
              
          _posts[index] = _posts[index].copyWith(
            isLiked: newIsLiked,
            likesCount: newLikesCount,
          );
        }
      });
      
      // Refresh the posts to ensure consistency with the server
      await _carregarPosts();
    } catch (e) {
      print('❌ Erro ao curtir/descurtir post: $e');
      // Optionally show an error message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao processar sua curtida. Tente novamente.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _republicarPost(Post post) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || post.id == null) return;

    final isReposted = _repostedPosts.contains(post.id);

    await SocialService().toggleLive(post.id!.toString(), isReposted);
    setState(() {
      if (isReposted) {
        _repostedPosts.remove(post.id!);
      } else {
        _repostedPosts.add(post.id!);
      }
    });

    await _carregarPosts();
  }

  void _repostar(Post post) async {
    try {
      await SocialService().toggleLive(post.id!, post.isReposted);
      setState(() {
        post.isReposted = !post.isReposted;
        if (post.isReposted) {
          post.livesCount = (post.livesCount ?? 0) + 1;
        } else {
          post.livesCount = (post.livesCount ?? 1) - 1;
          if (post.livesCount! < 0) post.livesCount = 0;
        }
      });
    } catch (e) {
      print('Erro ao repostar: $e');
    }
  }

  Future<void> _editarPost(Post post) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || post.id == null) return;

    // Create a text controller with the current post content
    final TextEditingController editController = 
        TextEditingController(text: post.content);

    // Show a dialog to edit the post
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Editar Postagem'),
          content: TextField(
            controller: editController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Edite sua postagem...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                await SocialService().editPost(post.id!.toString(), editController.text);
                await _carregarPosts();
                Navigator.of(context).pop();
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _excluirPost(Post post) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || post.id == null) return;

    // Show a confirmation dialog
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Excluir Postagem'),
          content: const Text('Tem certeza que deseja excluir esta postagem?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    // If confirmed, delete the post
    if (confirmDelete == true) {
      await SocialService().deletePost(post.id!.toString());
      await _carregarPosts();
    }
  }

  Future<void> _carregarComentarios(String postId) async {
    if (!mounted) return;
    
    try {
      // Busca os comentários do Supabase diretamente
      final commentsData = await SocialService().getComments(postId);
      
      // Converte os dados para objetos Comment
      final comments = commentsData.map((data) {
        return comment_model.Comment(
          id: data['id']?.toString(),
          postId: data['post_id']?.toString() ?? '',
          userId: data['user_id']?.toString() ?? '',
          content: data['content']?.toString() ?? '',
          createdAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ?? DateTime.now(),
          username: data['username']?.toString(),
          displayName: data['display_name']?.toString(),
          avatarUrl: data['avatar_url']?.toString(),
          selectedFrame: data['selected_frame']?.toString(),
        );
      }).toList();
      
      if (!mounted) return;
      
      setState(() {
        _postComments[postId] = comments;
        _commentCounts[postId] = comments.length;
      });
    } catch (e, stackTrace) {
      print('❌ Erro ao carregar comentários: $e');
      print('Stack trace: $stackTrace');
      
      if (!mounted) return;
      
      // Define uma lista vazia em caso de erro para evitar exibir erros na UI
      setState(() {
        _postComments[postId] = [];
        _commentCounts[postId] = 0;
      });
      
      // Mostra mensagem de erro apenas se o widget ainda estiver montado
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao carregar comentários. Tente novamente.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      // Relança o erro para que o chamador possa tratá-lo também
      rethrow;
    }
  }

  Future<void> _deletarComentario(String commentId, StateSetter? setModalState) async {
    try {
      // Encontra o comentário para obter o postId
      String? postId;
      for (var entry in _postComments.entries) {
        final comment = entry.value.firstWhereOrNull((c) => c.id == commentId);
        if (comment != null) {
          postId = comment.postId;
          break;
        }
      }

      if (postId == null) {
        throw Exception('Comentário não encontrado');
      }

      // Remove o comentário do Supabase
      await SocialService().deleteComment(commentId);
      
      // Atualiza a UI
      if (mounted) {
        setState(() {
          if (_postComments.containsKey(postId)) {
            _postComments[postId]!.removeWhere((c) => c.id == commentId);
            _commentCounts[postId!] = _postComments[postId]!.length;
          }
        });
      }
      
      // Se estiver em um modal, atualiza o estado do modal também
      if (setModalState != null) {
        setModalState(() {});
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comentário excluído'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Erro ao excluir comentário: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao excluir comentário'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostrarModalCriarPost() {
    final TextEditingController _postController = TextEditingController();
    String? _selectedImagePath;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          decoration: BoxDecoration(
            color: Colors.pink.shade50,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.pink.shade100.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cute header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, color: Colors.pink.shade300, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Compartilhe sua história! 💖',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.pink.shade500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // Post content input
              TextField(
                controller: _postController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Conte algo fofo que aconteceu hoje... 🌸',
                  hintStyle: TextStyle(color: Colors.pink.shade200),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(15),
                ),
              ),
              const SizedBox(height: 15),

              // Image selection
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
                      if (pickedFile != null) {
                        setState(() {
                          _selectedImagePath = pickedFile.path;
                        });
                      }
                    },
                    icon: Icon(Icons.image, color: Colors.white),
                    label: Text('Escolher Foto'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink.shade200,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  if (_selectedImagePath != null) ...[
                    const SizedBox(width: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(_selectedImagePath!),
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 15),

              // Publish button
              ElevatedButton(
                onPressed: () {
                  if (_postController.text.isNotEmpty) {
                    _criarPost(_postController.text, _selectedImagePath);
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 12),
                ),
                child: Text('Publicar'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Refatorado: Modal de Comentários conectado ao Supabase
void _mostrarModalComentarios(Post post) async {
  final TextEditingController _comentarioController = TextEditingController();

  // Mostra um indicador de carregamento
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(
      child: CircularProgressIndicator(),
    ),
  );

  try {
    // Aguarda o carregamento dos comentários
    await _carregarComentarios(post.id!);
    
    // Fecha o indicador de carregamento
    if (mounted) {
      Navigator.of(context).pop();
    }
  } catch (e) {
    // Em caso de erro, fecha o indicador e mostra mensagem de erro
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao carregar comentários')),
      );
      return;
    }
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Comentários',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.pink[800],
              ),
            ),
            const SizedBox(height: 12),

            // Lista de Comentários
            if (_postComments[post.id!]?.isNotEmpty ?? false)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _postComments[post.id!]!.length,
                itemBuilder: (context, index) {
                  final comment = _postComments[post.id!]![index];
                  final displayName = comment.displayName ?? 'Usuário';
                  final username = comment.username ?? 'usuario';
                  final avatarUrl = comment.avatarUrl;
                  final createdAt = comment.createdAt;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: AvatarWithFrame(
                      imageUrl: avatarUrl,
                      framePath: comment.selectedFrame ?? 'assets/frame_none.png',
                      size: 44, // 22 * 2 para manter o mesmo tamanho
                    ),
                    title: Text(
                      displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('@$username', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        Text(comment.content),
                        Text(
                          _formatCommentDate(createdAt),
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'delete') {
                          if (comment.id != null) {
                            _deletarComentario(comment.id!, setModalState).then((_) {
                              _atualizarContadorComentarios(post, -1); // Decrementa o contador
                            });
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Excluir', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                      icon: const Icon(Icons.more_vert, size: 18),
                    ),
                  );
                },
              )
            else
              const Text('Nenhum comentário ainda.', style: TextStyle(color: Colors.grey)),

            const SizedBox(height: 12),

            // Campo de envio
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _comentarioController,
                    decoration: InputDecoration(
                      hintText: 'Adicione um comentário...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: Icon(Icons.send, color: Colors.pink[800]),
                  onPressed: () async {
                    final comentario = _comentarioController.text.trim();
                    if (comentario.isEmpty) return;

                    try {
                      await SocialService().addComment(post.id!, comentario);
                      _comentarioController.clear();
                      await _carregarComentarios(post.id!);
                      _atualizarContadorComentarios(post, 1); // Incrementa o contador
                      setModalState(() {}); // Atualiza o modal
                    } catch (_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erro ao comentar'), backgroundColor: Colors.red),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    ),
  );
}



  // Placeholder methods for user identification
  Future<String> _getCurrentUserId() async {
    // TODO: Implement actual user authentication
    return 'current_user_id';
  }

  Future<String> _getCurrentUserName() async {
    // TODO: Implement actual user authentication
    return 'Nome do Usuário';
  }

  String _formatCommentDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'Agora';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) return '${difference.inHours}h';
    if (difference.inDays < 30) return '${difference.inDays}d';
    
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  void _navegarParaChat() {
    // TODO: Implementar navegação para chat
    print('Navegando para chat...');
  }

  void _navegarParaAmizades() {
    // TODO: Implementar navegação para amizades
    print('Navegando para amizades...');
  }

  void _navegarParaPerfilAmigo(Post post) {
    if (post.userId != null && post.username != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FriendProfilePage(
            friendUserId: post.userId!,
            friendUsername: post.username!,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'K-Feed',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.pink.shade600,
          ),
        ),
        actions: [
          Theme(
            data: Theme.of(context).copyWith(
              popupMenuTheme: PopupMenuThemeData(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 4,
                color: Colors.white,
                textStyle: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            child: PopupMenuButton<String>(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.pink[100]!,
                      Colors.pink[50]!,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink[200]!.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Efeito de brilho
                    Icon(
                      Icons.favorite,
                      color: Colors.white.withOpacity(0.8),
                      size: 26,
                    ),
                    // Ícone principal
                    Icon(
                      Icons.favorite,
                      color: Colors.pink[300],
                      size: 24,
                    ),
                  ],
                ),
              ),
              offset: const Offset(0, 50),
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'chat',
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      leading: Icon(Icons.chat_bubble_rounded, color: Colors.purple[300], size: 26),
                      title: Text(
                        'Chat',
                        style: TextStyle(
                          color: Colors.purple[400],
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    ),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'amizades',
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      leading: Icon(Icons.favorite_border_rounded, color: Colors.blue[300], size: 26),
                      title: Text(
                        'Amizades',
                        style: TextStyle(
                          color: Colors.blue[400],
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => FriendPage()),
                        );
                      },
                    ),
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'chat') {
                  _navegarParaChat();
                } else if (value == 'amizades') {
                  _navegarParaAmizades();
                }
              },
            ),
          ),
        ],
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Create Post Bar
          GestureDetector(
            onTap: _mostrarModalCriarPost,
            child: Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.pink.shade50,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.shade100.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Cute sparkle icon
                  Icon(
                    Icons.auto_awesome_outlined, 
                    color: Colors.pink.shade300, 
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Compartilhe seus momentos fofos! 💕',
                      style: TextStyle(
                        color: Colors.pink.shade400,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Post List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: _posts.length,
              separatorBuilder: (context, index) => const Divider(
                height: 10,
                color: Colors.transparent,
              ),
              itemBuilder: (context, index) {
                final post = _posts[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with user info
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _navegarParaPerfilAmigo(post),
                                borderRadius: BorderRadius.circular(25),
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Imagem de perfil ou ícone
                                      if (post.selectedFrame != null && post.selectedFrame != 'assets/frame_none.png')
                                    // Com moldura
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Imagem de perfil recortada
                                        ClipPath(
                                          clipper: MolduraClipper(post.selectedFrame!),
                                          child: Container(
                                            width: 54,
                                            height: 54,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              image: post.avatarUrl != null && post.avatarUrl!.isNotEmpty
                                                  ? DecorationImage(
                                                      image: post.avatarUrl!.startsWith('http')
                                                          ? NetworkImage(post.avatarUrl!) as ImageProvider
                                                          : FileImage(File(post.avatarUrl!)) as ImageProvider,
                                                      fit: BoxFit.cover,
                                                    )
                                                  : null,
                                              color: (post.avatarUrl == null || post.avatarUrl!.isEmpty) 
                                                  ? Colors.grey[200] 
                                                  : null,
                                            ),
                                            child: (post.avatarUrl == null || post.avatarUrl!.isEmpty)
                                                ? Icon(Icons.person, color: Colors.pink[300], size: 22)
                                                : null,
                                          ),
                                        ),
                                        // Moldura
                                        Image.asset(
                                          post.selectedFrame!,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.contain,
                                        ),
                                      ],
                                    )
                                  else
                                    // Sem moldura
                                    Container(
                                      width: 54,
                                      height: 54,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        image: post.avatarUrl != null && post.avatarUrl!.isNotEmpty
                                            ? DecorationImage(
                                                image: post.avatarUrl!.startsWith('http')
                                                    ? NetworkImage(post.avatarUrl!) as ImageProvider
                                                    : FileImage(File(post.avatarUrl!)) as ImageProvider,
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                        color: (post.avatarUrl == null || post.avatarUrl!.isEmpty) 
                                            ? Colors.grey[200] 
                                            : null,
                                      ),
                                      child: (post.avatarUrl == null || post.avatarUrl!.isEmpty)
                                          ? Icon(Icons.person, color: Colors.pink[300], size: 22)
                                          : null,
                                    ),
                                ],
                              ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () => _navegarParaPerfilAmigo(post),
                                    child: Text(
                                      (post.displayName == null || post.displayName!.trim().isEmpty)
                                          ? (post.username?.trim().isEmpty ?? true ? 'Anonymous' : post.username ?? 'user')
                                          : post.displayName!,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '@${post.username ?? 'user'}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    _formatPostDate(post.createdAt),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Mostrar opções de editar/excluir apenas para posts do usuário atual
                            if (post.userId == Supabase.instance.client.auth.currentUser?.id)
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                                onSelected: (String choice) {
                                  if (choice == 'edit') {
                                    _editarPost(post);
                                  } else if (choice == 'delete') {
                                    _excluirPost(post);
                                  }
                                },
                                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                  PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[50],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(Icons.edit_rounded, 
                                            color: Colors.blue[600], 
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text('Editar', 
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[800],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.red[50],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(Icons.delete_rounded, 
                                            color: Colors.red[400], 
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text('Excluir', 
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[800],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      
                      // Post content
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        child: Text(
                          post.content,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ),
                      
                      // Optional media
                      if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(15),
                            bottomRight: Radius.circular(15),
                          ),
                          child: Image.network(
                            post.mediaUrl!,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 200,
                                color: Colors.grey[100],
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      
                      // Interaction buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Like button
                            // Like button
                            _buildInteractionButton(
                              icon: Icons.favorite_border,
                              count: post.likesCount,
                              onPressed: () => _curtirPost(post),
                              color: Colors.pink[300]!,
                              isLiked: post.isLiked,
                            ),
                            
                            // Comment button
                            _buildInteractionButton(
                              icon: Icons.comment_outlined,
                              count: post.commentsCount,
                              onPressed: () => _mostrarModalComentarios(post),
                              color: Colors.green[300]!,
                            ),
                            
                            // Repost button
                            _buildInteractionButton(
                              icon: Icons.repeat_outlined,
                              count: post.livesCount,
                              onPressed: () => _repostar(post),
                              color: Colors.blue,
                              isReposted: post.isReposted,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Atualiza o contador de comentários de um post
  void _atualizarContadorComentarios(Post post, int delta) {
    setState(() {
      final index = _posts.indexWhere((p) => p.id == post.id);
      if (index != -1) {
        _posts[index] = post.copyWith(commentsCount: post.commentsCount + delta);
      }
    });
  }

  // Helper method to format post date
  String _formatPostDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'Agora';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) return '${difference.inHours}h';
    if (difference.inDays < 30) return '${difference.inDays}d';
    
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  // Helper method to build interaction buttons
  Widget _buildInteractionButton({
    required IconData icon,
    required int count,
    required VoidCallback onPressed,
    required Color color,
    bool isLiked = false,
    bool isReposted = false,
  }) {
    // Determine the icon to display based on the interaction type and state
    Widget getIcon() {
      if (icon == Icons.favorite_border || icon == Icons.favorite) {
        return Icon(
          isLiked ? Icons.favorite : Icons.favorite_border,
          color: isLiked ? Colors.pink[700] : color,
          size: 20,
        );
      } else if (icon == Icons.repeat_outlined || icon == Icons.repeat) {
        return Icon(
          isReposted ? Icons.repeat : Icons.repeat_outlined,
          color: isReposted ? Colors.blue[700] : color,
          size: 20,
        );
      } else {
        return Icon(icon, color: color, size: 20);
      }
    }

    // Determine the text color based on the interaction state
    Color getTextColor() {
      if (isLiked && (icon == Icons.favorite_border || icon == Icons.favorite)) {
        return Colors.pink[700]!;
      } else if (isReposted && (icon == Icons.repeat_outlined || icon == Icons.repeat)) {
        return Colors.blue[700]!;
      }
      return color;
    }
    
    // Get the background color based on the interaction state
    Color getBackgroundColor() {
      if (isLiked && (icon == Icons.favorite_border || icon == Icons.favorite)) {
        return Colors.pink[50]!;
      } else if (isReposted && (icon == Icons.repeat_outlined || icon == Icons.repeat)) {
        return Colors.blue[50]!;
      }
      return color.withOpacity(0.1);
    }

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: getBackgroundColor(),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            getIcon(),
            const SizedBox(width: 5),
            Text(
              count.toString(),
              style: TextStyle(
                color: getTextColor(),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MolduraClipper extends CustomClipper<Path> {
  final String molduraAsset;

  MolduraClipper(this.molduraAsset);

  @override
  Path getClip(Size size) {
    return Path()
      ..addOval(Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: (size.width - 6) / 2, // Margem ajustada para o novo tamanho
      ));
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
