import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/auth_service.dart';
import 'main.dart';
import 'data_storage_service.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();
  final DataStorageService _dataStorageService = DataStorageService();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLogin = true;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.pink[300]!, Colors.pink[100]!],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'K-Photo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 48),
                
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'E-mail',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, insira um e-mail';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, insira uma senha';
                          }
                          if (value.length < 6) {
                            return 'A senha deve ter pelo menos 6 caracteres';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 16),
                
                _isLoading 
                  ? Center(child: CircularProgressIndicator(color: Colors.white))
                  : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _isLogin ? 'Entrar' : 'Registrar',
                      style: TextStyle(color: Colors.black87),
                    ),
                    onPressed: _submitForm,
                  ),
                
                SizedBox(height: 16),
                
                TextButton(
                  child: Text(
                    _isLogin 
                      ? 'Não tem uma conta? Registre-se' 
                      : 'Já tem uma conta? Faça login',
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                    });
                  },
                ),
                
                SizedBox(height: 16),
                
                ElevatedButton.icon(
                  icon: Image.asset(
                    'assets/google_logo.png', 
                    height: 24, 
                    width: 24
                  ),
                  label: Text(
                    'Entrar com Google',
                    style: TextStyle(color: Colors.black87),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _loginWithGoogle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        User? user;
        if (_isLogin) {
          user = await _authService.signInWithEmailAndPassword(
            _emailController.text.trim(), 
            _passwordController.text
          );
        } else {
          user = await _authService.registerWithEmailAndPassword(
            _emailController.text.trim(), 
            _passwordController.text
          );
        }

        if (user != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => HomePage(
                dataStorageService: _dataStorageService
              )
            )
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isLogin 
                ? 'Erro no login. Verifique suas credenciais.' 
                : 'Erro no registro. Tente novamente.'),
              backgroundColor: Colors.red,
            )
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          )
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _loginWithGoogle() async {
    setState(() => _isLoading = true);
    
    try {
      User? user = await _authService.signInWithGoogle();
      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomePage(
              dataStorageService: _dataStorageService
            )
          )
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha no login com Google. Tente novamente.'),
            backgroundColor: Colors.red,
          )
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro no login com Google: $e'),
          backgroundColor: Colors.red,
        )
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
