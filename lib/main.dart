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
import 'pages/feed_page.dart'; // Import the FeedPage

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dataStorageService = DataStorageService();

  // Check for first-time installation
  final prefs = await SharedPreferences.getInstance();
  bool isFirstInstall = prefs.getBool('first_install') ?? true;

  if (isFirstInstall) {
    // Perform first-time setup
    await dataStorageService.initializeSharedPile();
    await CurrencyService.initializeDefaultValues();
    await prefs.setBool('first_install', false);
  }

  // Inicializa o banco de dados
  await dataStorageService.initDatabase();

  // Inicializa o CurrencyService com o DataStorageService
  CurrencyService.initialize(dataStorageService);

  await dataStorageService.restoreFullState();

  runApp(MyApp(dataStorageService));
}

class MyApp extends StatelessWidget {
  final DataStorageService dataStorageService;

  const MyApp(this.dataStorageService, {super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'K-Photo App',
      theme: ThemeData(
        primarySwatch: Colors.pink,
      ),
      home: SplashScreen(
        dataStorageService:
            dataStorageService, // Passando dataStorageService para a SplashScreen
      ),
      debugShowCheckedModeBanner: false, // Remove o banner de debug
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

  @override
  void initState() {
    super.initState();
    _initializeRewards();
    _startBalanceUpdateTimer();
  }

  @override
  void dispose() {
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
    Timer.periodic(Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_secondsUntilNextReward > 0) {
          _secondsUntilNextReward--;
        } else {
          _secondsUntilNextReward = 60;
          _addKCoins();
        }
      });
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
            ? const FeedPage()
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
