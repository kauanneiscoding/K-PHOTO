import 'package:flutter/material.dart';
import 'models/keychain.dart';

class EditBinderPage extends StatefulWidget {
  final String currentCover;
  final String currentSpine;
  final String? currentKeychain;
  final Function(String cover, String spine, String? keychain) onCoversChanged;

  const EditBinderPage({
    Key? key,
    required this.currentCover,
    required this.currentSpine,
    this.currentKeychain,
    required this.onCoversChanged,
  }) : super(key: key);

  @override
  State<EditBinderPage> createState() => _EditBinderPageState();
}

class _EditBinderPageState extends State<EditBinderPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String selectedCover;
  late String selectedSpine;
  String? selectedKeychain;

  final List<Map<String, String>> availableCovers = [
    {
      'cover': 'assets/capas/capabinder1.png',
      'spine': 'assets/capas/lombadabinder1.png',
    },
    {
      'cover': 'assets/capas/capabinder2.png',
      'spine': 'assets/capas/lombadabinder2.png',
    },
    {
      'cover': 'assets/capas/capabinder3.png',
      'spine': 'assets/capas/lombadabinder3.png',
    },
    {
      'cover': 'assets/capas/capabinder4.png',
      'spine': 'assets/capas/lombadabinder4.png',
    },
  ];

  final List<Keychain> availableKeychains = [
    Keychain(id: '1', imagePath: 'assets/keychain/keychain1.png'),
    Keychain(id: '2', imagePath: 'assets/keychain/keychain2.png'),
    Keychain(id: '3', imagePath: 'assets/keychain/keychain3.png'),
  ];

  @override
  void initState() {
    super.initState();
    selectedCover = widget.currentCover;
    selectedSpine = widget.currentSpine;
    selectedKeychain = widget.currentKeychain;
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Editar Binder'),
        actions: [
          TextButton(
            onPressed: () {
              widget.onCoversChanged(
                  selectedCover, selectedSpine, selectedKeychain);
              Navigator.pop(context);
            },
            child: Text(
              'Salvar',
              style: TextStyle(
                color: Colors.pink[300],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Visualização da capa e chaveiro
          Center(
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: MediaQuery.of(context).size.height * 0.7,
                    margin: EdgeInsets.only(bottom: 160),
                    child: Image.asset(
                      selectedCover,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                if (selectedKeychain != null && selectedKeychain!.isNotEmpty)
                  Positioned(
                    left: MediaQuery.of(context).size.width * 0.02,
                    top: MediaQuery.of(context).size.height * 0.08,
                    child: Transform(
                      transform: Matrix4.identity()
                        ..rotateZ(0)
                        ..translate(-78.0, 10.0),
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.60,
                        height: MediaQuery.of(context).size.width * 0.60,
                        child: Image.asset(
                          selectedKeychain!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Barra de navegação inferior
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.pink[300],
                    labelColor: Colors.pink[300],
                    unselectedLabelColor: Colors.grey[600],
                    tabs: [
                      Tab(text: 'Capas'),
                      Tab(text: 'Chaveiros'),
                      Tab(text: 'Adesivos'),
                    ],
                  ),
                  Container(
                    height: 150,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Aba de Capas
                        ListView(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.all(8),
                          children: availableCovers.map((cover) {
                            final isSelected = selectedCover == cover['cover'];
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedCover = cover['cover']!;
                                  selectedSpine = cover['spine']!;
                                });
                              },
                              child: Container(
                                width: 100,
                                margin: EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.pink[300]!
                                        : Colors.grey[300]!,
                                    width: isSelected ? 3 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Image.asset(
                                  cover['cover']!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        // Aba de Chaveiros
                        ListView(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.all(8),
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedKeychain = null;
                                });
                              },
                              child: Container(
                                width: 80,
                                margin: EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: selectedKeychain == null
                                        ? Colors.pink[300]!
                                        : Colors.grey[300]!,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.remove_circle,
                                    color: Colors.grey[400]),
                              ),
                            ),
                            ...availableKeychains.map((keychain) =>
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedKeychain = keychain.imagePath;
                                    });
                                  },
                                  child: Container(
                                    width: 80,
                                    margin: EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: selectedKeychain ==
                                                keychain.imagePath
                                            ? Colors.pink[300]!
                                            : Colors.grey[300]!,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Image.asset(
                                      keychain.imagePath,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                )),
                          ],
                        ),
                        // Aba de Adesivos
                        Center(
                          child: Text(
                            'Em breve!',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
