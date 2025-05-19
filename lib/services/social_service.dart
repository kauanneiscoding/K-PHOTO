import 'package:supabase_flutter/supabase_flutter.dart';

class SocialService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Carregar feed de posts
  Future<List<Map<String, dynamic>>> getFeedPosts() async {
    final response = await _supabase
        .from('posts')
        .select()
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Criar novo post
  Future<void> createPost(String content, {String? mediaPath}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase.from('posts').insert({
      'user_id': user.id,
      'content': content,
      'midia_url': mediaPath,
    });
  }

  // Curtir / descurtir post
  Future<void> toggleLike(String postId, bool isLiked) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    if (isLiked) {
      await _supabase
          .from('likes')
          .delete()
          .match({'post_id': postId, 'user_id': user.id});
    } else {
      await _supabase.from('likes').insert({
        'post_id': postId,
        'user_id': user.id,
      });
    }
  }

  // Republicar / desfazer republicação
  Future<void> toggleRepost(String postId, bool isReposted) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    if (isReposted) {
      await _supabase
          .from('reposts')
          .delete()
          .match({'post_id': postId, 'user_id': user.id});
    } else {
      await _supabase.from('reposts').insert({
        'post_id': postId,
        'user_id': user.id,
      });
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
