import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service responsible for handling social interactions like likes, comments, and reposts

class SocialService {
  final SupabaseClient _supabase = Supabase.instance.client;

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
            likes_count:likes(count)
          ''')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response).map((post) {
        final userProfile = post['user_profile'] as Map<String, dynamic>?;
        final likes = post['likes'] as List<dynamic>? ?? [];
        final likesCount = (post['likes_count'] as List<dynamic>?)?.firstOrNull?['count'] ?? 0;
        
        final basePost = userProfile == null
            ? {
                ...post,
                'username': 'usuario',
                'display_name': 'Usuário',
                'avatar_url': null,
                'likes_count': likesCount,
              }
            : {
                ...post,
                'username': userProfile['username'] ?? 'usuario',
                'display_name': userProfile['display_name'] ?? 'Usuário',
                'avatar_url': userProfile['avatar_url'],
                'selected_frame': userProfile['selected_frame'],
                'likes_count': likesCount,
              };
        
        return {
          ...basePost,
          'is_liked': likes.any((like) => like['user_id'] == userId),
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
  try {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

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
  } catch (e) {
    print('❌ Error toggling like: $e');
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
  /// Returns true if the post is now reposted, false otherwise
  Future<bool> toggleRepost(String postId, bool isReposted) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      if (isReposted) {
        await _supabase
            .from('reposts')
            .delete()
            .match({'post_id': postId, 'user_id': user.id});
        return false;
      } else {
        await _supabase.from('reposts').insert({
          'post_id': postId,
          'user_id': user.id,
          'created_at': DateTime.now().toIso8601String(),
        });
        return true;
      }
    } catch (e) {
      print('❌ Error toggling repost: $e');
      rethrow;
    }
  }

  /// Gets the number of reposts for a post
  Future<int> getRepostCount(String postId) async {
    try {
      final response = await _supabase
          .from('reposts')
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

      return response['id'].toString();
    } catch (e) {
      print('❌ Error adding comment: $e');
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
              avatar_url
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
