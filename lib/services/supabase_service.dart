import 'dart:io';
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
  
  factory SupabaseService([SupabaseClient? supabaseClient]) {
    if (supabaseClient != null) {
      _instance._client = supabaseClient;
    } else {
      _instance._client = Supabase.instance.client;
    }
    return _instance;
  }

  SupabaseService._internal();

  late SupabaseClient _client;

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
        final profileData = {
          'id': response.user!.id,
          'email': email,
          'username': username ?? email.split('@').first,
          'created_at': DateTime.now().toIso8601String(),
        };

        // Inserir perfil diretamente usando o ID do usuário autenticado
        final insertResponse = await _client
          .from('profiles')
          .upsert(profileData, onConflict: 'id')
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
      // Realizar login
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      print('Login realizado com sucesso');
      await afterSuccessfulLogin(response);

      return response;
    } catch (e) {
      print('Erro no login: $e');
      rethrow;
    }
  }

  Future<AuthResponse> signInWithGoogle() async {
    try {
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

      await afterSuccessfulLogin(response);
      return response;
    } catch (e) {
      debugPrint('Erro no login com Google: $e');
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
          print('Sessão restaurada com sucesso');
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
        
        // Salvar informações essenciais do usuário
        await prefs.setString('user_id', response.user!.id);
        await prefs.setString('user_email', response.user!.email ?? '');
        
        // Salvar token de acesso, se disponível
        if (response.session != null) {
          await prefs.setString('access_token', response.session!.accessToken);
        }
        
        print('Informações de login salvas com sucesso');
      }
    } catch (e) {
      print('Erro ao salvar informações de login: $e');
    }
  }

  // Recuperação de Perfil
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();

    return response;
  }

  // Verificar disponibilidade de username
  Future<bool> isUsernameTaken(String username) async {
    final response = await _client
        .from('profiles')
        .select('username')
        .eq('username', username)
        .single();

    return response != null;
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
}
