import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service responsible for handling social interactions like likes, comments, and reposts

class SocialService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> getProfileWallLikes(String profileUserId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return {'likes_count': 0, 'is_liked': false};

    try {
      final profileResponse = await _supabase
          .from('user_profile')
          .select('mural_likes_count')
          .eq('user_id', profileUserId)
          .maybeSingle();

      final likesCount = (profileResponse?['mural_likes_count'] as int?) ?? 0;

      final likedResponse = await _supabase
          .from('profile_wall_likes')
          .select('id')
          .eq('profile_user_id', profileUserId)
          .eq('user_id', userId)
          .maybeSingle();

      return {
        'likes_count': likesCount,
        'is_liked': likedResponse != null,
      };
    } catch (e) {
      print('❌ Erro ao carregar likes do mural: $e');
      return {'likes_count': 0, 'is_liked': false};
    }
  }

  Future<void> toggleProfileWallLike(String profileUserId, bool isLiked) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      if (isLiked) {
        await _supabase
            .from('profile_wall_likes')
            .delete()
            .eq('profile_user_id', profileUserId)
            .eq('user_id', userId);
      } else {
        await _supabase.from('profile_wall_likes').insert({
          'profile_user_id': profileUserId,
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      await _supabase.rpc('update_profile_wall_likes_count', params: {
        'profile_user_id_param': profileUserId,
      });
    } catch (e) {
      print('❌ Erro ao curtir/descurtir mural: $e');
      rethrow;
    }
  }

  // Carregar feed de posts
Future<List<Map<String, dynamic>>> getFeedPosts() async {
  final userId = _supabase.auth.currentUser?.id;
  if (userId == null) return [];

  try {
    final response = await _supabase
        .from('posts')
        .select('''
          *,
          user_profile!user_id(
            username,
            display_name,
            avatar_url,
            selected_frame
          ),
          likes!post_id(user_id),
          lives!post_id(user_id),
          comments_count
        ''')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response).map((post) {
      final userProfile = post['user_profile'] as Map<String, dynamic>?;
      final likes = post['likes'] as List<dynamic>? ?? [];
      final lives = post['lives'] as List<dynamic>? ?? [];

      int commentsCount = (post['comments_count'] as int?) ?? 0;

      return {
        ...post,
        'username': userProfile?['username'] ?? 'usuario',
        'display_name': userProfile?['display_name'] ?? 'Usuário',
        'avatar_url': userProfile?['avatar_url'],
        'selected_frame': userProfile?['selected_frame'],
        'likes_count': post['likes_count'] ?? 0,
        'lives_count': post['lives_count'] ?? 0,
        'comments_count': commentsCount,
        'is_liked': likes.any((like) => like['user_id'] == userId),
        'is_reposted': lives.any((live) => live['user_id'] == userId),
      };
    }).toList();
  } catch (e) {
    print('❌ Erro ao carregar posts: $e');
    return [];
  }
}




  Future<String?> uploadImageToSupabase(File imageFile, String userId) async {
  try {
    final path = 'user/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';

    final bytes = await imageFile.readAsBytes();

    final response = await _supabase.storage
        .from('post-images')
        .uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));

    // Gera a URL pública para exibir no feed
    final publicUrl = _supabase.storage.from('post-images').getPublicUrl(path);
    return publicUrl;
  } catch (e) {
    print('Erro ao fazer upload da imagem: $e');
    return null;
  }
}

  // Criar novo post
  Future<void> createPost(String content, {String? mediaPath}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    String? mediaUrl;
    if (mediaPath != null) {
      final imageFile = File(mediaPath);
      mediaUrl = await uploadImageToSupabase(imageFile, user.id);
    }

    await _supabase.from('posts').insert({
      'user_id': user.id,
      'content': content,
      'midia_url': mediaUrl,
    });
  }

  /// Toggles a like on a post
  /// If the post is already liked, removes the like
  /// If the post is not liked, adds a like
  Future<void> toggleLike(String postId, bool isLiked) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      if (isLiked) {
        // Remove o like
        await _supabase
            .from('likes')
            .delete()
            .eq('user_id', userId)
            .eq('post_id', postId);
      } else {
        // Adiciona o like
        await _supabase.from('likes').insert({
          'user_id': userId,
          'post_id': postId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Atualizar contador de likes
      await _supabase.rpc('update_post_likes_count', params: {
        'post_id_param': postId,
      });
    } catch (e) {
      print('❌ Erro ao curtir/descurtir: $e');
      rethrow;
    }
  }


  /// Gets the number of likes for a post
  Future<int> getLikesCount(String postId) async {
    try {
      final response = await _supabase
          .from('likes')
          .select('id', const FetchOptions(count: CountOption.exact))
          .eq('post_id', postId);
      return response.count ?? 0;
    } catch (e) {
      print('❌ Error getting likes count: $e');
      rethrow;
    }
  }

  /// Toggles a repost on a post
Future<void> toggleLive(String postId, bool isReposted) async {
  try {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    if (isReposted) {
      // Remove o repost
      await _supabase
          .from('lives')
          .delete()
          .eq('user_id', userId)
          .eq('post_id', postId);
    } else {
      // Adiciona o repost
      await _supabase.from('lives').insert({
        'user_id': userId,
        'post_id': postId,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    // Atualiza contador de lives
    await _supabase.rpc('update_post_lives_count', params: {
      'post_id_param': postId,
    });
  } catch (e) {
    print('❌ Error toggling live: $e');
    rethrow;
  }
}



  /// Gets the number of reposts for a post
  Future<int> getLivesCount(String postId) async {
    try {
      final response = await _supabase
          .from('lives')
          .select('id', const FetchOptions(count: CountOption.exact))
          .eq('post_id', postId);
      return response.count ?? 0;
    } catch (e) {
      print('❌ Error getting repost count: $e');
      rethrow;
    }
  }

  /// Adds a comment to a post
  /// Returns the created comment ID
 Future<String> addComment(String postId, String content) async {
  try {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    if (content.trim().isEmpty) throw Exception('Comment cannot be empty');

    final response = await _supabase
        .from('comments')
        .insert({
          'post_id': postId,
          'user_id': user.id,
          'content': content,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select('id')
        .single();

    // 🔥 Atualiza contador de comentários
    await _supabase.rpc('update_post_comments_count', params: {
      'post_id_param': postId,
    });

    return response['id'].toString();
  } catch (e) {
    print('❌ Error adding comment: $e');
    rethrow;
  }
}



  /// Deletes a comment by its ID
/// Returns true if successful, false otherwise
Future<bool> deleteComment(String commentId) async {
  try {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final commentResponse = await _supabase
        .from('comments')
        .select('post_id, user_id')
        .eq('id', commentId)
        .single();

    if (commentResponse == null) {
      throw Exception('Comment not found');
    }

    final commentOwnerId = commentResponse['user_id']?.toString();
    final postId = commentResponse['post_id']?.toString();
    if (commentOwnerId != user.id) {
      throw Exception('You can only delete your own comments');
    }

    await _supabase
        .from('comments')
        .delete()
        .eq('id', commentId);

    // 🔥 Atualiza contador de comentários
    await _supabase.rpc('update_post_comments_count', params: {
      'post_id_param': postId,
    });

    return true;
  } catch (e) {
    print('❌ Error deleting comment: $e');
    rethrow;
  }
}


  /// Gets comments for a post with user information
  Future<List<Map<String, dynamic>>> getComments(String postId) async {
    try {
      final response = await _supabase
          .from('comments')
          .select('''
            *,
            user_profile!user_id(
              username,
              display_name,
              avatar_url,
              selected_frame
            )
          ''')
          .eq('post_id', postId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response).map((comment) {
        final userProfile = comment['user_profile'] as Map<String, dynamic>?;
        return {
          ...comment,
          'username': userProfile?['username'] ?? 'usuario',
          'display_name': userProfile?['display_name'] ?? 'Usuário',
          'avatar_url': userProfile?['avatar_url'],
          'selected_frame': userProfile?['selected_frame'],
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting comments: $e');
      rethrow;
    }
  }

  // Editar post
  Future<void> editPost(String postId, String newContent) async {
    await _supabase
        .from('posts')
        .update({'content': newContent})
        .eq('id', postId);
  }

  // Deletar post
  Future<void> deletePost(String postId) async {
    await _supabase.from('posts').delete().eq('id', postId);
  }
}
