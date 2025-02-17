import 'package:flutter/material.dart';
import 'package:k_photo/services/supabase_service.dart';
import 'package:k_photo/main.dart' as main;
import 'package:k_photo/data_storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:k_photo/services/user_sync_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final SupabaseService _supabaseService = SupabaseService();
  final DataStorageService _dataStorageService = DataStorageService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isLoginMode = true;

  void _navigateToHomePage() {
    // Obter usuário atual
    final user = Supabase.instance.client.auth.currentUser;
    
    if (user != null) {
      print('🔐 Navegando para HomePage com usuário autenticado:');
      print('🆔 ID do usuário: ${user.id}');
      print('📧 Email do usuário: ${user.email ?? "Sem email"}');
      print('📅 Usuário criado em: ${user.createdAt}');

      // Verificar sessão atual
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        print('🔑 Detalhes da sessão:');
        print('   Token de acesso: ${session.accessToken.substring(0, 10)}...');
        print('   Expira em: ${session.expiresAt}');
      }

      // Definir usuário no serviço de armazenamento
      _dataStorageService.setCurrentUser(user.id);

      // Verificar se o usuário foi definido corretamente
      if (_dataStorageService.isUserDefined()) {
        print('✅ Usuário definido com sucesso no DataStorageService');
        
        // Navegar para HomePage
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => main.HomePage(
              dataStorageService: _dataStorageService,
            )
          )
        );
      } else {
        print('❌ Falha ao definir usuário no DataStorageService');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: Não foi possível definir o usuário'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      print('❌ Tentativa de navegação sem usuário definido');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: Usuário não autenticado'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Método para garantir criação de binder
  Future<void> _ensureInitialBinder(DataStorageService dataStorageService) async {
    try {
      final binders = await dataStorageService.getAllBinders();
      print('🔍 Binders existentes durante login: ${binders.length}');
      
      // Só criar binder inicial se NÃO houver NENHUM binder
      if (binders.isEmpty) {
        print('🆕 Nenhum binder encontrado. Criando binder inicial no login.');
        await dataStorageService.addNewBinder();
      } else {
        print('✅ Binders já existem. Não será criado binder inicial.');
      }
    } catch (e) {
      print('❌ Erro ao verificar/criar binder inicial no login: $e');
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _supabaseService.signInWithGoogle();
      
      if (response.user != null) {
        _dataStorageService.setCurrentUser(response.user!.id);

        // Garantir binder inicial
        await _ensureInitialBinder(_dataStorageService);

        final userSyncService = UserSyncService(
          Supabase.instance.client, 
          _dataStorageService
        );
        
        userSyncService.setCurrentUser(response.user!.id);
        await userSyncService.syncAllUserData();

        _navigateToHomePage();
      } else {
        throw Exception('Usuário não autenticado');
      }
    } catch (e) {
      debugPrint('Erro detalhado no login com Google: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro no login: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        throw Exception('Email e senha são obrigatórios');
      }

      final response = await _supabaseService.signIn(
        email: email, 
        password: password
      );

      if (response.user != null) {
        _dataStorageService.setCurrentUser(response.user!.id);

        // Garantir binder inicial
        await _ensureInitialBinder(_dataStorageService);

        final userSyncService = UserSyncService(
          Supabase.instance.client, 
          _dataStorageService
        );
        
        userSyncService.setCurrentUser(response.user!.id);
        await userSyncService.syncAllUserData();

        _navigateToHomePage();
      } else {
        throw Exception('Usuário não autenticado');
      }
    } catch (e) {
      String errorMessage = 'Erro no login';
      
      print('Erro no login: $e');
      
      if (e is AuthException) {
        switch (e.message) {
          case 'Email not confirmed':
            // Ignorar erro de email não confirmado
            try {
              final response = await _supabaseService.signIn(
                email: _emailController.text.trim(), 
                password: _passwordController.text.trim()
              );
              return; // Sair do método se o login for bem-sucedido
            } catch (loginError) {
              print('Erro no login após ignorar confirmação: $loginError');
              errorMessage = 'Erro ao fazer login';
            }
            break;
          case 'email rate limit exceeded':
            errorMessage = 'Muitas tentativas de login. Tente novamente mais tarde.';
            break;
          default:
            errorMessage = e.message ?? 'Erro de autenticação';
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signUp() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // Validações adicionais
      if (email.isEmpty || !email.contains('@')) {
        throw Exception('Email inválido');
      }

      if (password.length < 6) {
        throw Exception('Senha deve ter no mínimo 6 caracteres');
      }

      print('Tentando registrar usuário: $email');
      print('Verificando status do email antes do registro');

      final response = await _supabaseService.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        _dataStorageService.setCurrentUser(response.user!.id);

        // Garantir binder inicial
        await _ensureInitialBinder(_dataStorageService);

        // Inicializar serviço de sincronização
        final userSyncService = UserSyncService(
          Supabase.instance.client, 
          _dataStorageService
        );
        
        userSyncService.setCurrentUser(response.user!.id);
        await userSyncService.syncAllUserData();

        _navigateToHomePage();
      } else {
        throw Exception('Usuário não autenticado');
      }
    } catch (e) {
      print('Erro no registro: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _checkCurrentSession();
  }

  Future<void> _checkCurrentSession() async {
    try {
      // Tentar restaurar sessão
      final supabaseService = SupabaseService(Supabase.instance.client);
      final sessionRestored = await supabaseService.restoreSession();

      if (sessionRestored) {
        // Se sessão restaurada com sucesso, navegar para HomePage
        _navigateToHomePage();
        return;
      }

      // Verificação padrão de sessão
      final session = Supabase.instance.client.auth.currentSession;
      final user = Supabase.instance.client.auth.currentUser;

      print('Verificação de Sessão no Login Page:');
      print('Sessão existe: ${session != null}');
      print('Usuário existe: ${user != null}');
      
      if (session != null && user != null) {
        print('Sessão Atual:');
        print('ID do Usuário: ${user.id}');
        print('Email do Usuário: ${user.email}');
        print('Token de Acesso: ${session.accessToken.substring(0, 10)}...');
        
        // Verificar se a sessão não está expirada
        if (!session.isExpired) {
          // Navegar automaticamente para HomePage se sessão válida
          _navigateToHomePage();
        } else {
          print('Sessão expirada, necessário novo login');
        }
      }
    } catch (e) {
      print('Erro na verificação de sessão: $e');
      // Opcional: mostrar mensagem de erro ao usuário
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao verificar sessão: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'K-PHOTO',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              
              // Email TextField
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              
              // Password TextField
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              
              // Login/Signup Buttons
              _isLoading 
                ? const CircularProgressIndicator()
                : Column(
                    children: [
                      ElevatedButton(
                        onPressed: _isLoginMode ? _signIn : _signUp,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(_isLoginMode ? 'Entrar' : 'Cadastrar'),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLoginMode = !_isLoginMode;
                          });
                        },
                        child: Text(
                          _isLoginMode 
                            ? 'Não tem conta? Cadastre-se' 
                            : 'Já tem conta? Faça login'
                        ),
                      ),
                    ],
                  ),
              
              const SizedBox(height: 24),
              
              // Google Sign In Button
              _isLoading 
                ? const SizedBox.shrink()
                : OutlinedButton.icon(
                    icon: Image.asset(
                      'assets/google_logo.png', 
                      height: 24, 
                      width: 24
                    ),
                    label: const Text('Entrar com Google'),
                    onPressed: _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
