import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../services/database.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  _FeedPageState createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final List<Post> _posts = [];
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final Set<int> _likedPosts = {};
  final Set<int> _repostedPosts = {};
  Map<int, List<Comment>> _postComments = {};
  Map<int, int> _commentCounts = {};

  @override
  void initState() {
    super.initState();
    _carregarPosts();
    _carregarPostsCurtidos();
    _carregarPostsRepostados();
  }

  Future<void> _carregarPosts() async {
    final posts = await _dbHelper.getPosts();
    setState(() {
      _posts.clear();
      _posts.addAll(posts);
    });
  }

  Future<void> _carregarPostsCurtidos() async {
    final likedPosts = await _dbHelper.getLikedPosts();
    setState(() {
      _likedPosts.clear();
      _likedPosts.addAll(likedPosts);
    });
  }

  Future<void> _carregarPostsRepostados() async {
    final repostedPosts = await _dbHelper.getRepostedPosts();
    setState(() {
      _repostedPosts.clear();
      _repostedPosts.addAll(repostedPosts);
    });
  }

  Future<void> _criarPost(String conteudo, String? midia) async {
    if (conteudo.isEmpty) return;

    final novoPost = Post(
      autor: 'Usuário Atual', // Substitua com autenticação real
      conteudo: conteudo,
      midia: midia,
    );

    await _dbHelper.addPost(novoPost);
    await _carregarPosts();
  }

  Future<void> _curtirPost(Post post) async {
    if (_likedPosts.contains(post.id)) {
      // If already liked, unlike the post
      await _dbHelper.descurtirPost(post.id!);
      await _dbHelper.saveLikedPostState(post.id!, false);
      setState(() {
        _likedPosts.remove(post.id!);
      });
    } else {
      // If not liked, like the post
      await _dbHelper.curtirPost(post.id!);
      await _dbHelper.saveLikedPostState(post.id!, true);
      setState(() {
        _likedPosts.add(post.id!);
      });
    }

    // Refresh posts to show updated like count
    await _carregarPosts();
  }

  Future<void> _republicarPost(Post post) async {
    if (_repostedPosts.contains(post.id)) {
      // If already reposted, unrepost the post
      await _dbHelper.desrepostarPost(post.id!);
      await _dbHelper.saveRepostedPostState(post.id!, false);
      setState(() {
        _repostedPosts.remove(post.id!);
      });
    } else {
      // If not reposted, repost the post
      await _dbHelper.republicarPost(post.id!);
      await _dbHelper.saveRepostedPostState(post.id!, true);
      setState(() {
        _repostedPosts.add(post.id!);
      });
    }

    // Refresh posts to show updated repost count
    await _carregarPosts();
  }

  Future<void> _editarPost(Post post) async {
    // Create a text controller with the current post content
    final TextEditingController editController = 
        TextEditingController(text: post.conteudo);

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
                // Update the post content
                final updatedPost = Post(
                  id: post.id,
                  autor: post.autor,
                  conteudo: editController.text,
                  midia: post.midia,
                  curtidas: post.curtidas,
                  republicacoes: post.republicacoes,
                  dataPublicacao: post.dataPublicacao,
                );

                // Save the updated post
                await _dbHelper.updatePost(updatedPost);
                
                // Refresh posts
                await _carregarPosts();

                // Close the dialog
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
      await _dbHelper.deletePost(post.id!);
      await _carregarPosts();
    }
  }

  Future<void> _carregarComentarios(int postId) async {
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

  Future<void> _deletarComentario(Comment comment, StateSetter? setModalState) async {
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
    _carregarComentarios(post.id!);

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

                        final newComment = Comment(
                          postId: post.id!,
                          userId: currentUserId,
                          userName: currentUserName,
                          content: comentario,
                        );

                        try {
                          await _dbHelper.addComment(newComment);
                          
                          // Reload comments and update the UI
                          await _carregarComentarios(post.id!);
                          
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'K-Photo Feed', 
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.pink.shade600,
          ),
        ),
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
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.pink[100],
                              child: Icon(Icons.person, color: Colors.pink[300]),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post.autor,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    _formatPostDate(post.dataPublicacao),
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
                          post.conteudo,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ),
                      
                      // Optional media
                      if (post.midia != null)
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(15),
                            bottomRight: Radius.circular(15),
                          ),
                          child: Image.file(
                            File(post.midia!),
                            width: double.infinity,
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
                          ),
                        ),
                      
                      // Interaction buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Like button
                            _buildInteractionButton(
                              icon: _likedPosts.contains(post.id) 
                                  ? Icons.favorite 
                                  : Icons.favorite_border,
                              count: post.curtidas,
                              onPressed: () => _curtirPost(post),
                              color: _likedPosts.contains(post.id) 
                                  ? Colors.pink 
                                  : Colors.pink[300]!,
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
                              icon: _repostedPosts.contains(post.id) 
                                  ? Icons.repeat 
                                  : Icons.repeat_outlined,
                              count: post.republicacoes,
                              onPressed: () => _republicarPost(post),
                              color: _repostedPosts.contains(post.id) 
                                  ? Colors.blue 
                                  : Colors.blue[300]!,
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
  }) {
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
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 5),
            Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
