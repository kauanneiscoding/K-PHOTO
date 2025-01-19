import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../currency_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      'openid', // Important for ID token
    ],
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Obter usuário atual
  User? get currentUser => _auth.currentUser;

  // Fazer login anônimo
  Future<User?> signInAnonymously() async {
    try {
      UserCredential result = await _auth.signInAnonymously();
      return result.user;
    } catch (e) {
      print('Erro no login anônimo: $e');
      return null;
    }
  }

  // Login com Google
  Future<User?> signInWithGoogle() async {
    try {
      // Configuração detalhada do Google Sign-In
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: [
          'email',
          'profile',
          'openid',
        ],
        clientId: '1014602044921-e0uf0mi7vi7rj6ao8mru9t8hnosdar1u.apps.googleusercontent.com',
      );

      // Diagnóstico de configuração
      print('🔍 DIAGNÓSTICO DETALHADO DE GOOGLE SIGN-IN:');
      print('  Pacote Android: com.kauanne.k_photo');
      print('  Client ID: 1014602044921-e0uf0mi7vi7rj6ao8mru9t8hnosdar1u.apps.googleusercontent.com');
      print('  Escopos: email, profile, openid');

      try {
        // Verificação de conexão
        bool isConnected = await _checkInternetConnection();
        if (!isConnected) {
          print('❌ SEM CONEXÃO DE INTERNET');
          return null;
        }

        // Tentativa de login silencioso primeiro
        final GoogleSignInAccount? silentUser = await googleSignIn.signInSilently();
        if (silentUser != null) {
          print('✅ LOGIN SILENCIOSO REALIZADO');
          
          // Obtém autenticação do login silencioso
          final GoogleSignInAuthentication silentAuth = await silentUser.authentication;
          
          // Cria credencial para Firebase
          final OAuthCredential silentCredential = GoogleAuthProvider.credential(
            accessToken: silentAuth.accessToken!,
            idToken: silentAuth.idToken!,
          );

          // Tenta login no Firebase
          final UserCredential silentUserCredential = 
            await _auth.signInWithCredential(silentCredential);
          
          final User? user = silentUserCredential.user;
          if (user != null) {
            print('✅ LOGIN FIREBASE VIA SILENCIOSO REALIZADO');
            await _saveUserToFirestore(user);
            return user;
          }
        }

        // Se login silencioso falhar, tenta login interativo
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

        if (googleUser == null) {
          print('🚨 LOGIN DO GOOGLE CANCELADO PELO USUÁRIO');
          return null;
        }

        print('✅ USUÁRIO GOOGLE AUTENTICADO:');
        print('  ID: ${googleUser.id}');
        print('  Email: ${googleUser.email}');
        print('  Nome: ${googleUser.displayName}');

        // Obtenção de autenticação
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        print('🔐 DETALHES DA AUTENTICAÇÃO:');
        print('  Access Token: ${googleAuth.accessToken}');
        print('  ID Token: ${googleAuth.idToken}');

        // Verifica se tokens estão presentes
        if (googleAuth.accessToken == null || googleAuth.idToken == null) {
          print('❌ TOKEN DE ACESSO OU ID TOKEN NULO');
          return null;
        }

        // Cria credencial para Firebase
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken!,
          idToken: googleAuth.idToken!,
        );

        // Login no Firebase
        final UserCredential userCredential = 
          await _auth.signInWithCredential(credential);
        
        final User? user = userCredential.user;

        if (user != null) {
          await _checkAndRewardFirstLogin(user);
          
          print('✅ LOGIN FIREBASE REALIZADO COM SUCESSO');
          print('  UID: ${user.uid}');
          print('  Email: ${user.email}');
          
          // Salva informações do usuário no Firestore
          await _saveUserToFirestore(user);
          
          return user;
        }
      } on PlatformException catch (platformError) {
        print('❌ ERRO DE PLATAFORMA NO LOGIN DO GOOGLE:');
        print('  Código: ${platformError.code}');
        print('  Mensagem: ${platformError.message}');
        print('  Detalhes: ${platformError.details}');
      } on FirebaseAuthException catch (firebaseError) {
        print('❌ ERRO DE AUTENTICAÇÃO DO FIREBASE:');
        print('  Código: ${firebaseError.code}');
        print('  Mensagem: ${firebaseError.message}');
      }

      return null;
    } catch (e) {
      print('❌ ERRO CRÍTICO NO LOGIN DO GOOGLE:');
      print('Erro: $e');
      return null;
    }
  }

  // Método para salvar informações do usuário no Firestore
  Future<void> _saveUserToFirestore(User user) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      
      // Verifica se o usuário já existe
      final userDoc = await userRef.get();
      
      if (!userDoc.exists) {
        // Cria novo documento para usuário
        await userRef.set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          
          // Inicializa campos de progresso
          'progress': {
            'totalPhotos': 0,
            'totalPoints': 0,
            'achievements': [],
            'lastLogin': FieldValue.serverTimestamp(),
          }
        }, SetOptions(merge: true));
        
        print('✅ NOVO USUÁRIO CRIADO NO FIRESTORE');
      } else {
        // Atualiza último login
        await userRef.update({
          'progress.lastLogin': FieldValue.serverTimestamp(),
        });
        
        print('✅ USUÁRIO ATUALIZADO NO FIRESTORE');
      }
    } catch (e) {
      print('❌ ERRO AO SALVAR USUÁRIO NO FIRESTORE:');
      print('Erro: $e');
    }
  }

  // Método para obter dados do usuário
  Future<Map<String, dynamic>?> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
      
      return userDoc.data();
    } catch (e) {
      print('❌ ERRO AO BUSCAR DADOS DO USUÁRIO:');
      print('Erro: $e');
      return null;
    }
  }

  // Método para atualizar progresso do usuário
  Future<void> updateUserProgress(Map<String, dynamic> progressUpdate) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
          'progress': FieldValue.arrayUnion([progressUpdate])
        });
      
      print('✅ PROGRESSO DO USUÁRIO ATUALIZADO');
    } catch (e) {
      print('❌ ERRO AO ATUALIZAR PROGRESSO:');
      print('Erro: $e');
    }
  }

  // Login com Email e Senha
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final UserCredential authResult = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return authResult.user;
    } catch (error) {
      print('Erro no login com Email: $error');
      return null;
    }
  }

  // Registro com Email e Senha
  Future<User?> registerWithEmailAndPassword(String email, String password) async {
    try {
      final UserCredential authResult = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = authResult.user;

      if (user != null) {
        // Verifica se é o primeiro login
        await _checkAndRewardFirstLogin(user);
      }

      return user;
    } catch (error) {
      print('Erro no registro: $error');
      return null;
    }
  }

  // Verificar e recompensar primeiro login
  Future<void> _checkAndRewardFirstLogin(User user) async {
    if (user.metadata.creationTime == user.metadata.lastSignInTime) {
      // É o primeiro login
      DocumentReference userDoc = _firestore.collection('users').doc(user.uid);
      
      // Verifica se o documento do usuário já existe
      DocumentSnapshot snapshot = await userDoc.get();
      if (!snapshot.exists) {
        // Cria documento do usuário
        await userDoc.set({
          'email': user.email,
          'displayName': user.displayName,
          'firstLoginRewardReceived': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Adiciona 300 K-coins como recompensa inicial
        await CurrencyService.addKCoins(300);
      }
    }
  }

  // Fazer logout
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  // Verificar se está logado
  bool get isLoggedIn => _auth.currentUser != null;

  // Stream de mudança de estado de autenticação
  Stream<User?> get user => _auth.authStateChanges();

  // Método para verificar conexão de internet
  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      print('❌ SEM CONEXÃO DE INTERNET');
      return false;
    }
  }
}
