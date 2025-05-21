import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:k_photo/config/supabase_config.dart';
import 'package:path/path.dart' as path;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:k_photo/currency_service.dart';
import 'package:k_photo/data_storage_service.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  final _profileController = StreamController<Map<String, dynamic>?>.broadcast();
  SupabaseClient _client = Supabase.instance.client;
  
  factory SupabaseService([SupabaseClient? supabaseClient]) {
    if (supabaseClient != null) {
      _instance._client = supabaseClient;
    }
    return _instance;
  }

  SupabaseService._internal() {
    final userId = _client.auth.currentUser?.id;
    if (userId != null) {
      _client.from('user_profile')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', userId)
        .listen(
          (data) {
            if (data.isNotEmpty) {
              _profileController.add(data.first);
            }
          },
          onError: (error) {
            debugPrint('Erro no stream de perfil: $error');
          },
        );
    }
  }

  // Métodos de Autenticação
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? username,
  }) async {
    try {
      print('Iniciando registro de usuário: $email');
      
      // Realizar registro de autenticação
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );

      print('Usuário registrado com sucesso: ${response.user?.id}');

      // Verificar se o usuário foi criado com sucesso
      if (response.user == null) {
        throw Exception('Falha ao criar usuário');
      }

      // Tentar criar perfil do usuário
      try {
        final userProfile = {
          'user_id': response.user!.id,
          'username': username ?? email.split('@').first,
          'display_name': username ?? email.split('@').first,
          'avatar_url': null,
          'created_at': DateTime.now().toIso8601String(),
          'last_username_change': DateTime.now().toIso8601String(),
        };

        // Inserir perfil na tabela user_profile
        final insertResponse = await _client
          .from('user_profile')
          .upsert(userProfile)
          .select();

        print('Perfil do usuário criado com sucesso: $insertResponse');

        // Inicializar valores padrão após o registro
        await CurrencyService.initializeDefaultValues();
        final dataStorageService = DataStorageService();
        await dataStorageService.addNewBinder();
        print('Valores padrão inicializados: 300 K-Coins e primeiro binder');
      } catch (profileError) {
        print('Erro ao criar perfil do usuário: $profileError');
        // Log detalhado do erro
        if (profileError is PostgrestException) {
          print('Detalhes do erro Postgrest: ${profileError.message}');
          print('Código do erro: ${profileError.code}');
          print('Detalhes: ${profileError.details}');
        }
        
        // Continuar mesmo se o perfil não puder ser criado
      }

      return response;
    } catch (e) {
      print('Erro no cadastro: $e');
      rethrow;
    }
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      print('🔐 Iniciando autenticação');
      print('📧 Email: $email');
      
      // Realizar login
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Detalhes de autenticação
      print('🎉 Login realizado com sucesso');
      print('👤 Detalhes do usuário:');
      print('   ID: ${response.user?.id}');
      print('   Email: ${response.user?.email}');
      print('   Criado em: ${response.user?.createdAt}');
      
      // Verificar sessão atual
      final session = _client.auth.currentSession;
      if (session != null) {
        print('🔑 Detalhes da sessão:');
        print('   Token de acesso: ${session.accessToken.substring(0, 10)}...');
        print('   Expira em: ${session.expiresAt}');
      }

      await afterSuccessfulLogin(response);

      return response;
    } catch (e) {
      print('❌ Erro de autenticação');
      print('📝 Detalhes do erro: $e');
      
      // Tratamento específico de erros de autenticação
      if (e is AuthException) {
        print('🚨 Tipo de erro de autenticação: ${e.message}');
        print('🔍 Código do erro: ${e.statusCode}');
      }
      
      rethrow;
    }
  }

  Future<AuthResponse> signInWithGoogle() async {
    try {
      print('🌐 Iniciando login com Google');
      
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: kIsWeb 
          ? '527176737870-4kgh5jf6hp6nhcqco6g638k1b0d7j1oo.apps.googleusercontent.com' 
          : '527176737870-4kgh5jf6hp6nhcqco6g638k1b0d7j1oo.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );
      
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        throw Exception('Google Sign In Cancelled');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.idToken == null) {
        throw Exception('ID Token is null');
      }
      
      // Usar signInWithIdToken para login com Google
      final response = await _client.auth.signInWithIdToken(
        provider: Provider.google,
        idToken: googleAuth.idToken!,
      );

      print('🎉 Login com Google iniciado');
      print('🔗 URL de redirecionamento gerada');
      
      await afterSuccessfulLogin(response);
      return response;
    } catch (e) {
      print('❌ Erro no login com Google');
      print('📝 Detalhes do erro: $e');
      
      if (e is AuthException) {
        print('🚨 Tipo de erro de autenticação: ${e.message}');
        print('🔍 Código do erro: ${e.statusCode}');
      }
      
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      // Limpar dados locais antes de fazer logout
      await _client.auth.signOut(
        scope: SignOutScope.local, // Logout local
      );
      
      // Opcional: Limpar dados de sessão local
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      print('Logout realizado com sucesso');
    } catch (e) {
      print('Erro durante o logout: $e');
      rethrow;
    }
  }

  // Verificar validade da sessão atual
  Future<bool> isSessionValid() async {
    try {
      final session = _client.auth.currentSession;
      final user = _client.auth.currentUser;

      print('Verificação de Sessão no Supabase Service:');
      print('Sessão existe: ${session != null}');
      print('Usuário existe: ${user != null}');
      
      if (session == null || user == null) {
        return false;
      }

      // Verificar se o token não expirou
      final isExpired = session.isExpired;
      print('Sessão expirada: $isExpired');

      return !isExpired;
    } catch (e) {
      print('Erro ao verificar sessão: $e');
      return false;
    }
  }

  // Salvar sessão localmente
  Future<void> saveSession() async {
    try {
      final session = _client.auth.currentSession;
      if (session != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', session.user.id);
        await prefs.setString('user_email', session.user.email ?? '');
        await prefs.setString('access_token', session.accessToken);
        
        print('Sessão salva com sucesso');
      }
    } catch (e) {
      print('Erro ao salvar sessão: $e');
    }
  }

  // Recuperar sessão salva
  Future<bool> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final userEmail = prefs.getString('user_email');
      final accessToken = prefs.getString('access_token');

      if (userId != null && userEmail != null && accessToken != null) {
        // Verificar se o usuário atual corresponde aos dados salvos
        final currentUser = _client.auth.currentUser;
        
        if (currentUser != null && currentUser.id == userId) {
          // Atualizar DataStorageService com o ID do usuário
          final dataStorageService = DataStorageService();
          dataStorageService.setCurrentUser(userId);
          
          print('✅ Sessão restaurada com sucesso');
          return true;
        }
      }
      
      print('Não foi possível restaurar a sessão');
      return false;
    } catch (e) {
      print('Erro ao restaurar sessão: $e');
      return false;
    }
  }

  // Após login bem-sucedido
  Future<void> afterSuccessfulLogin(AuthResponse response) async {
    try {
      if (response.user != null) {
        final prefs = await SharedPreferences.getInstance();
        final userId = response.user!.id;
        
        // Salvar informações essenciais do usuário
        await prefs.setString('user_id', userId);
        await prefs.setString('user_email', response.user!.email ?? '');
        
        // Salvar token de acesso, se disponível
        if (response.session != null) {
          await prefs.setString('access_token', response.session!.accessToken);
        }
        
        // Atualizar DataStorageService com o ID do usuário
        final dataStorageService = DataStorageService();
        dataStorageService.setCurrentUser(userId);
        
        print('✅ Informações de login salvas e serviços atualizados');
      }
    } catch (e) {
      print('❌ Erro ao salvar informações de login: $e');
    }
  }

  // Recuperação de Perfil
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _client
          .from('user_profile')
          .select()
          .eq('user_id', userId)
          .single();

      return response;
    } catch (e) {
      debugPrint('❌ Erro ao buscar perfil do usuário: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserBalance() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _client
          .from('user_balance')
          .select()
          .eq('user_id', userId)
          .single();

      return response;
    } catch (e) {
      // Se o erro for que o registro não existe, criar um novo
      if (e is PostgrestException && e.code == 'PGRST116') {
        try {
          final newBalance = {
            'user_id': userId,
            'k_coins': 0,
            'star_coins': 0,
            'last_reward_time': DateTime.now().millisecondsSinceEpoch,
          };

          final insertResponse = await _client
              .from('user_balance')
              .upsert(newBalance)
              .select()
              .single();

          return insertResponse;
        } catch (insertError) {
          debugPrint('❌ Erro ao criar saldo inicial: $insertError');
          return null;
        }
      }
      debugPrint('❌ Erro ao buscar saldo: $e');
      return null;
    }
  }

  // Verificar disponibilidade de username
  Future<bool> isUsernameTaken(String username) async {
    try {
      final response = await _client
          .from('user_profile')
          .select('username')
          .eq('username', username)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('❌ Erro ao verificar username: $e');
      return false;
    }
  }

  // Método para obter o ID do usuário atual
  String? getCurrentUserId() {
    final user = _client.auth.currentUser;
    return user?.id;
  }

  // Método para verificar se há um usuário logado
  bool isUserLoggedIn() {
    return _client.auth.currentUser != null;
  }

  // Métodos de Upload de Imagem (opcional)
  Future<String> uploadProfileImage({
    required File imageFile,
    String? userId,
  }) async {
    try {
      userId ??= _client.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuário não autenticado');

      final fileName = '$userId/${DateTime.now().toIso8601String()}${path.extension(imageFile.path)}';
      
      final response = await _client.storage.from(SupabaseConfig.avatarsBucket).upload(
        fileName,
        imageFile,
        fileOptions: const FileOptions(upsert: true),
      );

      final imageUrl = _client.storage.from(SupabaseConfig.avatarsBucket).getPublicUrl(fileName);
      
      return imageUrl;
    } catch (e) {
      debugPrint('Erro no upload da imagem: $e');
      rethrow;
    }
  }

  // Reenviar email de confirmação
  Future<void> resendConfirmationEmail({required String email}) async {
    try {
      print('Reenviando email de confirmação para: $email');
      
      await _client.auth.resend(
        type: OtpType.signup,
        email: email,
      );
      
      print('Email de confirmação reenviado com sucesso');
    } catch (e) {
      print('Erro ao reenviar email de confirmação: $e');
      rethrow;
    }
  }

  // Método para configurar o Supabase para ignorar verificação de email
  Future<void> disableEmailVerification() async {
    try {
      // No Supabase, a verificação de email é configurada no projeto
      // Você precisará fazer isso no painel do Supabase:
      // 1. Vá para Authentication > Settings
      // 2. Desmarque "Enable email confirmations"
      print('ATENÇÃO: Desative a verificação de email no painel do Supabase');
    } catch (e) {
      print('Erro ao tentar desativar verificação de email: $e');
      rethrow;
    }
  }

  // Limpar dados do usuário antes de deletar
  Future<bool> cleanupUserData(String userId) async {
    try {
      // Desativar RLS temporariamente ou usar modo de admin
      await _client.rpc('disable_rls_for_cleanup');

      // Limpar dados em cascata
      await _client.from('binders').delete().eq('user_id', userId);
      await _client.from('inventory').delete().eq('user_id', userId);
      await _client.from('user_balance').delete().eq('user_id', userId);
      await _client.from('purchased_frames').delete().eq('user_id', userId);
      await _client.from('profiles').delete().eq('id', userId);

      print('Dados do usuário $userId limpos com sucesso');
      return true;
    } catch (e) {
      print('Erro ao limpar dados do usuário: $e');
      return false;
    } finally {
      // Reativar RLS
      await _client.rpc('enable_rls_after_cleanup');
    }
  }

  // Deletar conta de usuário
  Future<bool> deleteUserAccount() async {
    try {
      final user = _client.auth.currentUser;
      
      if (user == null) {
        print('Nenhum usuário logado para deletar');
        return false;
      }

      // Primeiro, limpar dados do usuário
      await cleanupUserData(user.id);

      // Deletar usuário do Supabase Auth
      await _client.auth.admin.deleteUser(user.id);
      
      // Fazer logout
      await _client.auth.signOut();

      print('Conta de usuário deletada com sucesso: ${user.id}');
      return true;
    } catch (e) {
      print('Erro ao deletar conta de usuário: $e');
      return false;
    }
  }

  // Deletar usuários sem binders
  Future<void> deleteUsersWithoutBinders() async {
    try {
      // Obter todos os usuários
      final users = await _client.from('profiles').select('id, email');
      
      for (var user in users) {
        final userId = user['id'] as String;
        
        // Verificar se o usuário tem binders
        final binderResponse = await _client
          .from('binders')
          .select('id')
          .eq('user_id', userId)
          .limit(1);
        
        if (binderResponse.isEmpty) {
          try {
            // Limpar dados do usuário antes de deletar
            await cleanupUserData(userId);

            // Deletar usuário do Supabase Auth
            await _client.auth.admin.deleteUser(userId);
            
            print('Usuário deletado: ${user['email']}');
          } catch (deleteError) {
            print('Erro ao deletar usuário ${user['email']}: $deleteError');
          }
        }
      }
    } catch (e) {
      print('Erro geral ao deletar usuários sem binders: $e');
    }
  }

  /// Enviar solicitação de amizade
  Future<void> sendFriendRequest(String receiverId) async {
    final user = _client.auth.currentUser;
    if (user == null || receiverId == user.id) return;

    await _client.from('friend_requests').upsert({
      'sender_id': user.id,
      'receiver_id': receiverId,
      'status': 'pending',
    });
  }

  /// Aceitar solicitação de amizade
  Future<void> acceptFriendRequest(String requestId, String senderId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    // Atualiza a solicitação
    await _client.from('friend_requests').update({
      'status': 'accepted',
    }).eq('id', requestId);

    // Cria a amizade nas duas direções
    await _client.from('friends').insert([
      {'user_id': user.id, 'friend_id': senderId},
      {'user_id': senderId, 'friend_id': user.id},
    ]);
  }

  /// Recusar solicitação de amizade
  Future<void> declineFriendRequest(String requestId) async {
    await _client.from('friend_requests')
        .update({'status': 'declined'})
        .eq('id', requestId);
  }

  /// Buscar solicitações pendentes recebidas
  Future<List<Map<String, dynamic>>> getPendingFriendRequests() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final response = await _client
        .from('friend_requests')
        .select('id, sender_id, status')
        .eq('receiver_id', user.id)
        .eq('status', 'pending');

    return List<Map<String, dynamic>>.from(response);
  }

  /// Buscar lista de amigos
  Future<List<String>> getFriendIds() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final response = await _client
        .from('friends')
        .select('friend_id')
        .eq('user_id', user.id);

    return List<Map<String, dynamic>>.from(response)
        .map((r) => r['friend_id'] as String)
        .toList();
  }

  /// Buscar usuário por username
  Future<Map<String, dynamic>?> findUserByUsername(String username) async {
    try {
      final response = await _client
          .from('user_profile')
          .select('user_id, username, avatar_url')
          .eq('username', username)
          .maybeSingle();

      if (response == null) return null;

      return {
        'id': response['user_id'],
        'username': response['username'],
        'avatar_url': response['avatar_url'],
      };
    } catch (e) {
      print('Erro ao buscar usuário: $e');
      return null;
    }
  }

  /// Buscar username do usuário atual
  Future<String?> getUsername() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final result = await _client
          .from('user_profile')
          .select('username')
          .eq('user_id', userId)
          .maybeSingle();
      return result?['username'] as String?;
    } catch (e) {
      debugPrint('❌ Erro ao buscar username: $e');
      return null;
    }
  }

  /// Retorna o display name do usuário atual
  Future<String?> getDisplayName() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final result = await _client
          .from('user_profile')
          .select('display_name')
          .eq('user_id', userId)
          .maybeSingle();
      return result?['display_name'] as String?;
    } catch (e) {
      debugPrint('❌ Erro ao buscar display name: $e');
      return null;
    }
  }

  /// Verifica se o usuário já tem username definido
  Future<bool> hasUsername(String userId) async {
    final result = await _client
        .from('user_profile')
        .select('username')
        .eq('user_id', userId)
        .maybeSingle();

    return result != null && result['username'] != null;
  }

  /// Define o username fixo
  Future<bool> setUsername(String userId, String username) async {
    try {
      await _client.from('user_profile').upsert({
        'user_id': userId,
        'username': username,
        'last_username_change': DateTime.now().toIso8601String(),
      });
      debugPrint('✅ Username definido com sucesso: $username');
      return true;
    } catch (e) {
      debugPrint('❌ Erro ao definir username: $e');
      return false;
    }
  }

  /// Retorna o usuário atual
  User? getCurrentUser() {
    return _client.auth.currentUser;
  }

  /// Retorna o stream de atualizações do perfil
  Stream<Map<String, dynamic>?> get profileStream => _profileController.stream;

  /// Define ou atualiza o apelido
  Future<void> updateDisplayName(String displayName) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuário não está logado');

    try {
      await _client.from('user_profile').update({
        'display_name': displayName,
      }).eq('user_id', userId);
      
      // Buscar perfil atualizado e notificar
      final profile = await getCurrentUserProfile();
      if (profile != null) {
        _profileController.add(profile);
      }
      
      debugPrint('✅ Display name atualizado com sucesso: $displayName');
    } catch (e) {
      debugPrint('❌ Erro ao atualizar display name: $e');
      rethrow;
    }
  }

  /// Buscar detalhes dos amigos
  Future<List<Map<String, dynamic>>> getFriendsDetails() async {
    final friendIds = await getFriendIds();
    if (friendIds.isEmpty) return [];

    final response = await _client
        .from('profiles')
        .select('id, username, avatar_url, last_seen')
        .in_('id', friendIds);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Faz upload de uma nova foto de perfil
  Future<String> uploadProfilePicture(File imageFile) async {
    try {
      final userId = getCurrentUser()?.id;
      if (userId == null) throw Exception('Usuário não está logado');

      final fileExt = path.extension(imageFile.path);
      final fileName = 'profile_$userId$fileExt';
      
      final response = await _client.storage
          .from('profile_pictures')
          .upload(fileName, imageFile);

      if (response.isEmpty) {
        throw Exception('Erro ao fazer upload da imagem');
      }

      final imageUrl = _client.storage
          .from('profile_pictures')
          .getPublicUrl(fileName);

      return imageUrl;
    } catch (e) {
      debugPrint('❌ Erro ao fazer upload da foto de perfil: $e');
      throw Exception('Erro ao fazer upload da imagem: $e');
    }
  }

  /// Atualiza o perfil do usuário
  Future<void> updateUserProfile({
    String? displayName,
    String? username,
    String? avatarUrl,
    String? frameId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuário não está logado');

    final updates = <String, dynamic>{};
    if (displayName != null) updates['display_name'] = displayName;
    if (username != null) updates['username'] = username;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (frameId != null) updates['frame_id'] = frameId;

    try {
      await _client.from('user_profile').update(updates).eq('user_id', userId);
      
      // Buscar perfil atualizado e notificar
      final profile = await getCurrentUserProfile();
      if (profile != null) {
        _profileController.add(profile);
      }
      
      debugPrint('✅ Perfil atualizado com sucesso');
    } catch (e) {
      debugPrint('❌ Erro ao atualizar perfil: $e');
      rethrow;
    }
  }
}
