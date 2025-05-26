import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../models/post.dart';
import '../models/comment.dart' as comment_model;
import '../services/database.dart';
import '../data_storage_service.dart';
import '../services/social_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:k_photo/friend_page.dart';
import '../services/supabase_service.dart';

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

    await SocialService().toggleRepost(post.id!.toString(), isReposted);
    setState(() {
      if (isReposted) {
        _repostedPosts.remove(post.id!);
      } else {
        _repostedPosts.add(post.id!);
      }
    });

    await _carregarPosts();
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
    try {
      final comments = await _dbHelper.getCommentsByPostId(postId);
      final commentCount = await _dbHelper.getCommentCountByPostId(postId);
      
      setState(() {
        _postComments[postId] = comments;
        _commentCounts[postId] = commentCount;
      });
    } catch (e) {
      print('Erro ao carregar comentários: $e');
    }
  }

  Future<void> _deletarComentario(comment_model.Comment comment, StateSetter? setModalState) async {
    try {
      await _dbHelper.deleteComment(comment.id!);
      
      // Remove the comment from the local list
      if (_postComments.containsKey(comment.postId)) {
        _postComments[comment.postId]!.removeWhere((c) => c.id == comment.id);
      }
      
      // Update the UI if a modal state setter is provided
      if (setModalState != null) {
        setModalState(() {});
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Comentário excluído'),
          backgroundColor: Colors.red[300],
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao excluir comentário'),
          backgroundColor: Colors.red[300],
        ),
      );
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

  void _mostrarModalComentarios(Post post) {
    final TextEditingController _comentarioController = TextEditingController();
    
    // Load comments when modal opens
    _carregarComentarios(post.id!.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Comentários',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink[800],
                ),
              ),
              SizedBox(height: 10),
              
              // Comments List
              if (_postComments[post.id!] != null && _postComments[post.id!]!.isNotEmpty)
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _postComments[post.id!]!.length,
                  itemBuilder: (context, index) {
                    final comment = _postComments[post.id!]![index];
                    return ListTile(
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(comment.userName ?? 'Usuário Anônimo'),
                                Text(comment.content),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatCommentDate(comment.createdAt),
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                              WillPopScope(
                                onWillPop: () async {
                                  FocusManager.instance.primaryFocus?.requestFocus();
                                  return false;
                                },
                                child: PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert, size: 16, color: Colors.grey),
                                  padding: EdgeInsets.zero,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  onCanceled: () {
                                    // Prevent automatic keyboard dismissal
                                    FocusManager.instance.primaryFocus?.requestFocus();
                                  },
                                  onSelected: (value) {
                                    if (value == 'delete') {
                                      _deletarComentario(comment, setModalState);
                                    }
                                    // Prevent keyboard dismissal
                                    FocusManager.instance.primaryFocus?.requestFocus();
                                  },
                                  itemBuilder: (BuildContext context) => [
                                    PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Text(
                                        'Excluir', 
                                        style: TextStyle(
                                          color: Colors.red, 
                                          fontSize: 12
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                    );
                  },
                )
              else
                Text(
                  'Nenhum comentário ainda.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              
              SizedBox(height: 10),
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
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      maxLines: null,
                    ),
                  ),
                  SizedBox(width: 10),
                  IconButton(
                    icon: Icon(Icons.send, color: Colors.pink[800]),
                    onPressed: () async {
                      String comentario = _comentarioController.text.trim();
                      if (comentario.isNotEmpty) {
                        // TODO: Replace with actual user authentication
                        String currentUserId = await _getCurrentUserId();
                        String currentUserName = await _getCurrentUserName();

                        final newComment = comment_model.Comment(
                          id: const Uuid().v4(),  // Generate a new UUID
                          postId: post.id!,
                          userId: currentUserId,
                          content: comentario,
                          userName: currentUserName,
                          createdAt: DateTime.now(),
                        );

                        try {
                          await _dbHelper.addComment(newComment);
                          
                          // Reload comments and update the UI
                          await _carregarComentarios(post.id!.toString());
                          
                          // Update the modal's state to show new comments
                          setModalState(() {});
                          
                          _comentarioController.clear();
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Comentário enviado!'),
                              backgroundColor: Colors.green[300],
                              duration: Duration(seconds: 1),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erro ao enviar comentário'),
                              backgroundColor: Colors.red[300],
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
              SizedBox(height: 10),
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
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                // Profile picture
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    image: post.avatarUrl != null && post.avatarUrl!.isNotEmpty
                                        ? DecorationImage(
                                            image: post.avatarUrl!.startsWith('http')
                                                ? NetworkImage(post.avatarUrl!) as ImageProvider
                                                : FileImage(File(post.avatarUrl!)),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: (post.avatarUrl == null || post.avatarUrl!.isEmpty)
                                      ? Icon(Icons.person, color: Colors.pink[300])
                                      : null,
                                ),
                                // Frame
                                if (post.selectedFrame != null && post.selectedFrame != 'assets/frame_none.png')
                                  Image.asset(
                                    post.selectedFrame!,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.contain,
                                  ),
                              ],
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (post.displayName == null || post.displayName!.trim().isEmpty)
                                        ? (post.username?.trim().isEmpty ?? true ? 'Anonymous' : post.username ?? 'user')
                                        : post.displayName!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
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
                            // Edit and Delete options
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Colors.grey),
                              onSelected: (String choice) {
                                if (choice == 'edit') {
                                  _editarPost(post);
                                } else if (choice == 'delete') {
                                  _excluirPost(post);
                                }
                              },
                              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                const PopupMenuItem<String>(
                                  value: 'edit',
                                  child: ListTile(
                                    leading: Icon(Icons.edit, color: Colors.blue),
                                    title: Text('Editar'),
                                  ),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'delete',
                                  child: ListTile(
                                    leading: Icon(Icons.delete, color: Colors.red),
                                    title: Text('Excluir'),
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
                              count: _commentCounts[post.id] ?? 0,
                              onPressed: () => _mostrarModalComentarios(post),
                              color: Colors.green[300]!,
                            ),
                            
                            // Repost button
                            _buildInteractionButton(
                              icon: Icons.repeat_outlined,
                              count: post.repostsCount,
                              onPressed: () => _republicarPost(post),
                              color: Colors.blue[300]!,
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
          color: isLiked ? Colors.pink : color,
          size: 20,
        );
      } else if (icon == Icons.repeat_outlined || icon == Icons.repeat) {
        return Icon(
          isReposted ? Icons.repeat : Icons.repeat_outlined,
          color: isReposted ? Colors.blue : color,
          size: 20,
        );
      } else {
        return Icon(icon, color: color, size: 20);
      }
    }

    // Determine the text color based on the interaction state
    Color getTextColor() {
      if (isLiked && (icon == Icons.favorite_border || icon == Icons.favorite)) {
        return Colors.pink;
      } else if (isReposted && (icon == Icons.repeat_outlined || icon == Icons.repeat)) {
        return Colors.blue;
      }
      return color;
    }

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
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
