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
import 'package:k_photo/models/profile_theme.dart';

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

    // Limpar solicitações antigas periodicamente
    await cleanupOldFriendRequests();

    // Verificar se já existe uma solicitação pendente entre os usuários
    final existingRequest = await _client
        .from('friend_requests')
        .select()
        .or('and(sender_id.eq.${user.id},receiver_id.eq.$receiverId),and(sender_id.eq.$receiverId,receiver_id.eq.${user.id})')
        .in_('status', ['pending', 'accepted'])
        .maybeSingle();

    if (existingRequest != null) {
      if (existingRequest['status'] == 'accepted') {
        throw Exception('Vocês já são amigos!');
      } else if (existingRequest['sender_id'] == user.id) {
        throw Exception('Você já enviou uma solicitação para este usuário.');
      } else {
        throw Exception('Este usuário já te enviou uma solicitação de amizade.');
      }
    }

    // Se não houver solicitação existente, criar uma nova
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

    // Cria a amizade (um único registro com user1_id < user2_id)
    final user1Id = user.id.compareTo(senderId) < 0 ? user.id : senderId;
    final user2Id = user.id.compareTo(senderId) < 0 ? senderId : user.id;
    
    await _client.from('friends').insert({
      'user1_id': user1Id,
      'user2_id': user2Id,
    });

    // Remove a solicitação após a amizade ser criada
    await _client.from('friend_requests')
        .delete()
        .eq('id', requestId);
    
    print('✅ Solicitação de amizade aceita e removida: $requestId');
  }

  /// Recusar solicitação de amizade
  Future<void> declineFriendRequest(String requestId) async {
    // Remove a solicitação após ser recusada
    await _client.from('friend_requests')
        .delete()
        .eq('id', requestId);
    
    print('❌ Solicitação de amizade recusada e removida: $requestId');
  }

  /// Buscar solicitações pendentes recebidas
  Future<List<Map<String, dynamic>>> getPendingFriendRequests() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    // Primeiro, buscar as solicitações pendentes
    final response = await _client
        .from('friend_requests')
        .select('id, sender_id, status, created_at')
        .eq('receiver_id', user.id)
        .eq('status', 'pending');

    if (response.isEmpty) return [];

    // Extrair IDs dos remetentes
    final senderIds = response.map((r) => r['sender_id'] as String).toList();

    // Buscar detalhes dos remetentes
    final sendersResponse = await _client
        .from('user_profile')
        .select('user_id, username, avatar_url, selected_frame')
        .in_('user_id', senderIds);

    // Mapear detalhes dos remetentes para as solicitações
    return response.map<Map<String, dynamic>>((request) {
      final sender = sendersResponse.firstWhere(
        (s) => s['user_id'] == request['sender_id'],
        orElse: () => {
          'user_id': request['sender_id'],
          'username': 'Usuário desconhecido',
          'avatar_url': null,
          'selected_frame': 'assets/frame_none.png',
        },
      );

      return {
        'id': request['id'],
        'sender_id': request['sender_id'],
        'status': request['status'],
        'created_at': request['created_at'],
        'username': sender['username'],
        'avatar_url': sender['avatar_url'],
        'selected_frame': sender['selected_frame'] ?? 'assets/frame_none.png',
      };
    }).toList();
  }

  /// Limpar solicitações de amizade antigas (mais de 30 dias)
  Future<void> cleanupOldFriendRequests() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
      
      final result = await _client
          .from('friend_requests')
          .delete()
          .lt('created_at', thirtyDaysAgo.toIso8601String());
      
      // O delete do Supabase pode retornar null, então verificamos de forma segura
      if (result == null) {
        print('🧹 Limpadas solicitações de amizade antigas (resultado null)');
      } else if (result.error == null) {
        print('🧹 Limpadas solicitações de amizade antigas');
      } else {
        print('⚠️ Erro ao limpar solicitações: ${result.error?.message}');
      }
    } catch (e) {
      print('❌ Erro ao limpar solicitações antigas: $e');
    }
  }

  /// Buscar lista de amigos
  Future<List<String>> getFriendIds() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final response = await _client
        .from('friends')
        .select('user1_id, user2_id')
        .or('user1_id.eq.${user.id},user2_id.eq.${user.id}');

    final friendIds = <String>[];
    for (final friendship in response) {
      final friendId = friendship['user1_id'] == user.id
          ? friendship['user2_id']
          : friendship['user1_id'];
      friendIds.add(friendId as String);
    }

    return friendIds;
  }

  /// Buscar usuário por username
  Future<Map<String, dynamic>?> findUserByUsername(String username) async {
    try {
      final response = await _client
          .from('user_profile')
          .select('user_id, username, avatar_url')
          .eq('username', username)
          .maybeSingle();

      if (response == null) {
        print('Usuário não encontrado: $username');
        return null;
      }

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

  /// Salva os adesivos de um binder no Supabase
  Future<void> saveStickersToSupabase(String binderId, List<Map<String, dynamic>> stickers) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Primeiro, obter os stickers existentes para atualização
      final existingStickers = await _client
          .from('binder_stickers')
          .select('id, image_path, position_x, position_y')
          .eq('user_id', userId)
          .eq('binder_id', binderId);

      final existingIds = <String>{};
      final updates = <Future>[];
      final inserts = <Map<String, dynamic>>[];

      // Processar cada sticker para atualização ou inserção
      for (final sticker in stickers) {
        final id = sticker['id'] as String;
        final imagePath = sticker['image_path'] as String? ?? '';
        final x = (sticker['x'] as num?)?.toDouble() ?? 0.0;
        final y = (sticker['y'] as num?)?.toDouble() ?? 0.0;
        final createdAt = sticker['created_at'] as String? ?? DateTime.now().toIso8601String();

        // Verificar se já existe um sticker com este ID
        final existing = existingStickers.firstWhere(
          (s) => s['id'] == id,
          orElse: () => null,
        );

        if (existing != null) {
          // Atualizar sticker existente
          updates.add(
            _client
                .from('binder_stickers')
                .update({
                  'image_path': imagePath,
                  'position_x': x,
                  'position_y': y,
                })
                .eq('id', id)
                .then((_) => null),
          );
          existingIds.add(id);
        } else {
          // Inserir novo sticker
          inserts.add({
            'id': id,
            'user_id': userId,
            'binder_id': binderId,
            'image_path': imagePath,
            'position_x': x,
            'position_y': y,
            'created_at': createdAt,
          });
        }
      }

      // Remover stickers que não estão mais na lista
      final stickersToRemove = existingStickers
          .where((s) => !existingIds.contains(s['id']))
          .map((s) => s['id'] as String)
          .toList();

      if (stickersToRemove.isNotEmpty) {
        updates.add(
          _client
              .from('binder_stickers')
              .delete()
              .in_('id', stickersToRemove)
              .then((_) => null),
        );
      }

      // Executar todas as operações em lote
      if (inserts.isNotEmpty) {
        updates.add(_client.from('binder_stickers').insert(inserts).then((_) => null));
      }

      if (updates.isNotEmpty) {
        await Future.wait(updates);
      }

      debugPrint('✅ Adesivos sincronizados com sucesso no Supabase');
    } catch (e) {
      debugPrint('❌ Erro ao salvar adesivos no Supabase: $e');
      rethrow;
    }
  }

  /// Carrega os adesivos de um binder do Supabase
  Future<List<Map<String, dynamic>>> loadStickersFromSupabase(String binderId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('binder_stickers')
          .select('id, image_path, position_x, position_y, scale, rotation, created_at')
          .eq('user_id', userId)
          .eq('binder_id', binderId);

      debugPrint('✅ Adesivos carregados do Supabase: ${response.length} itens');
      return List<Map<String, dynamic>>.from(response).map((sticker) => ({
        'id': sticker['id'],  // Manter o ID original
        'image_path': sticker['image_path'],
        'x': sticker['position_x'],
        'y': sticker['position_y'],
        'scale': sticker['scale'] ?? 1.0,  // Usar valor padrão 1.0 se for nulo
        'rotation': sticker['rotation'] ?? 0.0,  // Usar valor padrão 0.0 se for nulo
        'created_at': sticker['created_at'],
      })).toList();
    } catch (e) {
      debugPrint('❌ Erro ao carregar adesivos do Supabase: $e');
      return [];
    }
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

  /// Atualiza o último acesso do usuário
  Future<void> updateLastSeen() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('user_profile')
        .update({'last_seen': DateTime.now().toIso8601String()})
        .eq('user_id', userId);
  }

  /// Buscar perfil do usuário
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await _client
          .from('user_profile')
          .select('user_id, username, display_name, avatar_url, selected_frame, profile_background_url, profile_background_blur, profile_background_opacity, theme, bio, last_username_change')
          .eq('user_id', userId)
          .maybeSingle();
      
      return response;
    } catch (e) {
      debugPrint('❌ Erro ao buscar perfil do usuário: $e');
      return null;
    }
  }

  /// Buscar detalhes dos amigos
  Future<List<Map<String, dynamic>>> getFriendsDetails() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    // Buscar amizades onde o usuário é participante
    final friendshipsResponse = await _client
        .from('friends')
        .select('user1_id, user2_id')
        .or('user1_id.eq.$userId,user2_id.eq.$userId');

    final friendIds = <String>[];
    for (final friendship in friendshipsResponse) {
      final friendId = friendship['user1_id'] == userId
          ? friendship['user2_id']
          : friendship['user1_id'];
      friendIds.add(friendId as String);
    }

    if (friendIds.isEmpty) return [];

    // Buscar detalhes dos amigos
    final detailsResponse = await _client
        .from('user_profile')
        .select('user_id, username, display_name, avatar_url, last_seen, selected_frame')
        .in_('user_id', friendIds);

    return List<Map<String, dynamic>>.from(detailsResponse);
  }

/// Verificar se existe solicitação pendente e aceitar automaticamente
  Future<void> acceptPendingFriendRequest(String senderId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    // Verificar se existe solicitação pendente do senderId para o usuário atual
    final existingRequest = await _client
        .from('friend_requests')
        .select('id, sender_id')
        .eq('sender_id', senderId)
        .eq('receiver_id', user.id)
        .eq('status', 'pending')
        .maybeSingle();

    if (existingRequest != null) {
      // Aceitar a solicitação existente
      await acceptFriendRequest(existingRequest['id'], senderId);
    } else {
      // Não há solicitação pendente, lançar exceção para que o chamador envie nova solicitação
      throw Exception('Nenhuma solicitação pendente encontrada');
    }
  }

/// Verificar se dois usuários são amigos
  Future<bool> isFriend(String userId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    final response = await _client
        .from('friends')
        .select('id')
        .or('and(user1_id.eq.${user.id},user2_id.eq.$userId),and(user1_id.eq.$userId,user2_id.eq.${user.id})')
        .maybeSingle();

    return response != null;
  }

/// Desfazer amizade
Future<void> unfriendUser(String friendId) async {
  final user = _client.auth.currentUser;
  if (user == null) throw Exception('Usuário não autenticado');

  try {
    print('🔍 Verificando amizade existente entre ${user.id} e $friendId...');
    
    // Verifica amizades em ambas as direções (só deve existir uma devido à constraint)
    final friendship1 = await _client
        .from('friends')
        .select('id')
        .eq('user1_id', user.id)
        .eq('user2_id', friendId);
        
    final friendship2 = await _client
        .from('friends')
        .select('id')
        .eq('user1_id', friendId)
        .eq('user2_id', user.id);
        
    print('📊 Amizades encontradas:');
    print('   - ${user.id} -> $friendId: ${friendship1.length} registros');
    print('   - $friendId -> ${user.id}: ${friendship2.length} registros');
    
    if (friendship1.isEmpty && friendship2.isEmpty) {
      print('⚠️ Nenhuma amizade encontrada para remover');
      return;
    }

    // Remove a amizade na direção correta (só deve existir uma)
    if (friendship1.isNotEmpty) {
      final delete1 = await _client
          .from('friends')
          .delete()
          .eq('user1_id', user.id)
          .eq('user2_id', friendId);
          
      print('🗑️ Removida amizade ${user.id} -> $friendId');
    }

    if (friendship2.isNotEmpty) {
      final delete2 = await _client
          .from('friends')
          .delete()
          .eq('user1_id', friendId)
          .eq('user2_id', user.id);
          
      print('🗑️ Removida amizade $friendId -> ${user.id}');
    }
    
    // Verificação final para garantir que não restaram amizades
    final remainingCheck = await _client
        .from('friends')
        .select('id')
        .or('and(user1_id.eq.${user.id},user2_id.eq.$friendId),and(user1_id.eq.$friendId,user2_id.eq.${user.id})');
        
    if (remainingCheck.isNotEmpty) {
      print('⚠️ Aviso: Ainda existem ${remainingCheck.length} amizades remanescentes');
    } else {
      print('✅ Verificação final: Nenhuma amizade remanescente');
    }
    
  } catch (e) {
    print('❌ Erro ao desfazer amizade: $e');
    rethrow;
  }
}

  /// Faz upload de uma nova foto de perfil
  /// Retorna a URL pública da imagem com cache busting
  Future<String> uploadProfilePicture(File imageFile) async {
    try {
      final userId = getCurrentUser()?.id;
      if (userId == null) throw Exception('Usuário não autenticado');

      // Verificar se o arquivo existe
      if (!await imageFile.exists()) {
        throw Exception('Arquivo de imagem não encontrado');
      }

      // Extrair extensão do arquivo
      final fileExtension = path.extension(imageFile.path).toLowerCase();
      if (!['.jpg', '.jpeg', '.png', '.webp'].contains(fileExtension)) {
        throw Exception('Formato de imagem não suportado. Use JPG, PNG ou WebP');
      }

      // Gerar nome de arquivo único com timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '$timestamp$fileExtension';
      final filePath = '$userId/$fileName'; // pasta do usuário

      // Upload para a subpasta do usuário
      await _client.storage
          .from('avatars')
          .upload(filePath, imageFile);

      // Gera a URL pública com cache busting
      final String imageUrl = _client.storage
          .from('avatars')
          .getPublicUrl(filePath) + '?t=$timestamp';

      debugPrint('✅ Upload de imagem de perfil concluído: $imageUrl');
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
    String? theme,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuário não está logado');

    final updates = <String, dynamic>{};
    if (displayName != null) updates['display_name'] = displayName;
    if (username != null) updates['username'] = username;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (frameId != null) updates['frame_id'] = frameId;
    if (theme != null) updates['theme'] = theme;

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
