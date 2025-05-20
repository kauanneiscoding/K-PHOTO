// PÁGINA INICIAL DO APP
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart'; // Importando Lottie para a animação
import 'estante_page.dart'; // Certifique-se de que o arquivo tem a definição completa de EstantePage
import 'data_storage_service.dart'; // Importar o DataStorageService
import 'profile_page.dart'; // Adicione esta linha
import 'currency_service.dart'; // Importar o CurrencyService
import 'dart:async';
import 'store_page.dart'; // Importar a StorePage
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:k_photo/config/supabase_config.dart';
import 'package:k_photo/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'package:k_photo/services/user_sync_service.dart';
import 'package:k_photo/pages/feed_page.dart';
import 'package:k_photo/widgets/username_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  final dataStorageService = DataStorageService(Supabase.instance.client);
  final prefs = await SharedPreferences.getInstance();

  // Criar serviço de sincronização
  final userSyncService = UserSyncService(
    Supabase.instance.client, 
    dataStorageService
  );

  // Verificar se é o primeiro login
  bool isFirstInstall = prefs.getBool('first_install') ?? true;
  bool isLoggedIn = Supabase.instance.client.auth.currentUser != null;

  print('Verificação de Login:'); // Log de depuração
  print('Primeiro Install: $isFirstInstall'); // Log de depuração
  print('Usuário Logado: $isLoggedIn'); // Log de depuração
  
  if (isLoggedIn) {
    final user = Supabase.instance.client.auth.currentUser;
    
    if (user != null) {
      print('Usuário logado detectado:');
      print('ID do usuário: ${user.id}');
      print('Email do usuário: ${user.email}');

      // Definir usuário no serviço de armazenamento
      dataStorageService.setCurrentUser(user.id);
      
      // Garantir que o usuário tem saldo inicial
      await dataStorageService.ensureBalanceExistsForUser();
      
      userSyncService.setCurrentUser(user.id);
      
      // Garantir que haja um binder inicial
      try {
        final binders = await dataStorageService.getAllBinders();
        print('Binders existentes: ${binders.length}');
        
        // Só criar binder inicial se NÃO houver NENHUM binder
        if (binders.isEmpty) {
          print('Nenhum binder encontrado. Criando binder inicial.');
          await dataStorageService.addNewBinder();
        } else {
          print('Binders já existem. Não será criado binder inicial.');
        }
      } catch (e) {
        print('Erro ao verificar/criar binder inicial: $e');
      }
      
      // Sincronizar em background
      userSyncService.syncAllUserData();
    } else {
      print('Usuário logado é nulo, apesar de isLoggedIn ser true');
    }
  } else {
    print('Nenhum usuário logado');
  }

  // Inicializa o banco de dados
  await dataStorageService.initDatabase();

  // Restaurar estado antes de inicializar serviços
  await dataStorageService.restoreFullState();

  // Inicializar CurrencyService apenas se o usuário estiver logado
  final currentUser = Supabase.instance.client.auth.currentUser;
  if (isLoggedIn && currentUser != null) {
    await CurrencyService.initialize(dataStorageService);
  }

  runApp(MyApp(
    initialRoute: isLoggedIn ? '/home' : '/login',
    dataStorageService: dataStorageService,
  ));
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  final DataStorageService dataStorageService;

  const MyApp({
    super.key, 
    required this.initialRoute, 
    required this.dataStorageService
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'K-Photo App',
      theme: ThemeData(
        primarySwatch: Colors.pink,
      ),
      initialRoute: initialRoute,
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => HomePage(
          dataStorageService: dataStorageService,
        ),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

// Tela de carregamento com animação Lottie
class SplashScreen extends StatefulWidget {
  final DataStorageService dataStorageService;

  const SplashScreen(
      {super.key,
      required this.dataStorageService}); // Recebendo a instância do serviço de dados

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Simula o tempo de carregamento de 3 segundos antes de ir para a HomePage
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (BuildContext context) => HomePage(
            dataStorageService: widget
                .dataStorageService, // Passando a instância do serviço de dados para a HomePage
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Lottie.asset(
          'assets/your_animation_file.json', // Substitua pelo arquivo Lottie correto
          width: 200,
          height: 200,
          fit: BoxFit.fill,
        ),
      ),
    );
  }
}

// Página inicial do aplicativo com navegação inferior
class HomePage extends StatefulWidget {
  final DataStorageService dataStorageService;

  const HomePage(
      {super.key,
      required this.dataStorageService}); // Recebendo a instância do serviço de dados

  @override
  _HomePageState createState() => _HomePageState();

  Future<void> refreshBalance() async {
    final state = _HomePageState();
    await state._loadBalances();
  }
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  int _kCoins = 0;
  int _starCoins = 0;
  int _secondsUntilNextReward = 60;
  Timer? _balanceUpdateTimer;
  Timer? _timer;
  bool _dialogIsOpen = false;

  @override
  void initState() {
    super.initState();
    _initializeUserAndBalance();
    _initializeRewards();
    _startTimer();
    _startBalanceUpdateTimer();
    _loadBalances();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificarUsernameObrigatorio();
    });
  }

  Future<void> _initializeUserAndBalance() async {
    // 1. Esperar auth.currentUser
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      debugPrint('❌ Erro: Usuário não está logado');
      return;
    }

    // 2. Definir usuário ativo
    widget.dataStorageService.setCurrentUser(user.id);
    
    // 3. Garantir que tem saldo e inicializar rewards
    await widget.dataStorageService.ensureBalanceExistsForUser();

    // 4. Inicializar CurrencyService com o usuário atual
    await CurrencyService.initialize(widget.dataStorageService);

    // 5. Carregar saldo e inicializar rewards
    if (mounted) {
      await _loadBalances(); // Agora é seguro carregar o saldo
      
      final secondsPassed = await CurrencyService.getSecondsSinceLastReward();
      setState(() {
        _secondsUntilNextReward = 60 - (secondsPassed % 60);
      });
      
      _startTimer();
      _startBalanceUpdateTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _balanceUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeRewards() async {
    await _loadBalances();
    final secondsPassed = await CurrencyService.getSecondsSinceLastReward();
    _secondsUntilNextReward = 60 - (secondsPassed % 60);
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsUntilNextReward > 0) {
            _secondsUntilNextReward--;
          } else {
            _addKCoins();
            _secondsUntilNextReward = 180; // Reinicia o timer para 3 minutos
          }
        });
      }
    });
  }

  void _startBalanceUpdateTimer() {
    _balanceUpdateTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
      if (mounted) {
        await _loadBalances();
      }
    });
  }

  Future<void> _addKCoins() async {
    if (!mounted) return;
    await CurrencyService.addKCoins(10);
    await CurrencyService.updateLastRewardTime();
    await _loadBalances();
  }

  Future<void> _loadBalances() async {
    if (!mounted) return;
    final kCoins = await CurrencyService.getKCoins();
    final starCoins = await CurrencyService.getStarCoins();
    setState(() {
      _kCoins = kCoins;
      _starCoins = starCoins;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadBalances();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _verificarUsernameObrigatorio() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final hasUsername = await SupabaseService().hasUsername(user.id);
    if (!hasUsername && mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => UsernameDialog(userId: user.id),
      );
    }
  }

  void _showAddBalanceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Adicionar Saldo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Image.asset(
                  'assets/kcoin.png',
                  width: 30,
                  height: 30,
                ),
                title: Text('1000 K-Coins'),
                onTap: () async {
                  await CurrencyService.addKCoins(1000);
                  await _loadBalances();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('1000 K-Coins adicionados!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
              ListTile(
                leading: Image.asset(
                  'assets/starcoin.png',
                  width: 30,
                  height: 30,
                ),
                title: Text('500 Star-Coins'),
                onTap: () async {
                  await CurrencyService.addStarCoins(500);
                  await _loadBalances();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('500 Star-Coins adicionados!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Cancelar'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.pink[100],
        elevation: 0,
        toolbarHeight: 80, // Aumenta a altura do AppBar
        title: Padding(
          padding: EdgeInsets.only(top: 20), // Adiciona padding no topo
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Container para K-COIN
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    margin: EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.pink[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 35,
                          height: 35,
                          child: Image.asset(
                            'assets/kcoin.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '$_kCoins',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 4),
                        InkWell(
                          onTap: () => _showAddBalanceDialog(),
                          child: Icon(
                            Icons.add_circle,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(_secondsUntilNextReward ~/ 60).toString().padLeft(2, '0')}:${(_secondsUntilNextReward % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: Colors.pink[200],
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
              // Container para STAR-COIN
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.pink[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 35,
                      height: 35,
                      child: Image.asset(
                        'assets/starcoin.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '$_starCoins',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 4),
                    InkWell(
                      onTap: () => _showAddBalanceDialog(),
                      child: Icon(
                        Icons.add_circle,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: _selectedIndex == 0
            ? FeedPage(dataStorageService: widget.dataStorageService)
            : _selectedIndex == 1
                ? EstantePage(
                    dataStorageService: widget.dataStorageService,
                  )
                : _selectedIndex == 2
                    ? const Text('Página em construção')
                : _selectedIndex == 3
                    ? StorePage(dataStorageService: widget.dataStorageService)
                    : _selectedIndex == 4
                        ? ProfilePage(dataStorageService: widget.dataStorageService)
                        : const Text('Página em construção'),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Início',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books),
            label: 'Minha Estante',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz),
            label: 'Trocas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: 'Loja',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.pink[800],
        unselectedItemColor: Colors.pink[200],
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
      ),
    );
  }
}
