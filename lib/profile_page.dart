import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'currency_service.dart';
import 'data_storage_service.dart';
import 'package:k_photo/services/supabase_service.dart';
import 'package:k_photo/login_page.dart';

class ProfilePage extends StatefulWidget {
  final DataStorageService dataStorageService;

  const ProfilePage({
    Key? key,
    required this.dataStorageService,
  }) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? profileImagePath;
  int selectedFrame = 0;
  final String _selectedFrameKey = 'selected_frame';
  List<String> frames = ['assets/frame_none.png'];
  String? _cachedUsername;
  late Future<String?> _usernameFuture;

  @override
  void initState() {
    super.initState();
    _usernameFuture = _loadUsername();
    _loadSelectedFrame();
    _loadPurchasedFrames();
  }

  Future<void> _loadPurchasedFrames() async {
    final purchasedFrames =
        await widget.dataStorageService.getPurchasedFrames();
    setState(() {
      frames = ['assets/frame_none.png', ...purchasedFrames];
    });
  }

  Future<void> _loadSelectedFrame() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedFrame = prefs.getInt(_selectedFrameKey) ?? 0;
    });
  }

  Future<void> _saveSelectedFrame(int frame) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedFrameKey, frame);
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        profileImagePath = image.path;
      });
    }
  }

  Widget _buildProfilePicture() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          child: Stack(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (selectedFrame == 0)
                      // Imagem circular sem moldura, mas com mesmo tamanho
                      Container(
                        width: 110, // Mesmo tamanho da imagem com moldura
                        height: 110, // Mesmo tamanho da imagem com moldura
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: profileImagePath != null
                                ? FileImage(File(profileImagePath!))
                                    as ImageProvider
                                : AssetImage('assets/default_profile.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    else
                      // Imagem com moldura
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipPath(
                            clipper: MolduraClipper(frames[selectedFrame]),
                            child: Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: DecorationImage(
                                  image: profileImagePath != null
                                      ? FileImage(File(profileImagePath!))
                                          as ImageProvider
                                      : AssetImage('assets/default_profile.png'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          Image.asset(
                            frames[selectedFrame],
                            width: 120,
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.pink[200],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showFrameSelector() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return FutureBuilder<List<String>>(
          future: widget.dataStorageService.getPurchasedFrames(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            final List<String> allFrames = ['assets/frame_none.png'];
            if (snapshot.data != null) {
              allFrames.addAll(snapshot.data!);
            }

            return SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Escolha uma moldura',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: allFrames.asMap().entries.map((entry) {
                        final index = entry.key;
                        return _buildFrameOption(
                          index,
                          index == 0 ? 'Sem moldura' : 'Moldura ${index}',
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }

  Widget _buildFrameOption(int frameIndex, String label) {
    return GestureDetector(
      onTap: () async {
        setState(() {
          selectedFrame = frameIndex;
        });
        await _saveSelectedFrame(frameIndex);
        Navigator.pop(context);
      },
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selectedFrame == frameIndex ? Colors.pink : Colors.grey,
                width: 2,
              ),
              image: DecorationImage(
                image: AssetImage(frames[frameIndex]),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(height: 5),
          Text(label),
        ],
      ),
    );
  }

  void _showUsernameDialog() {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Escolha seu username'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      hintText: 'Digite seu username',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 8),
                  FutureBuilder<bool>(
                    future: widget.dataStorageService.canChangeUsername(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return SizedBox();

                      if (!snapshot.data!) {
                        return FutureBuilder<DateTime?>(
                          future: widget.dataStorageService
                              .getNextUsernameChangeDate(),
                          builder: (context, dateSnapshot) {
                            if (!dateSnapshot.hasData ||
                                dateSnapshot.data == null) {
                              return SizedBox();
                            }

                            final daysLeft = dateSnapshot.data!
                                .difference(DateTime.now())
                                .inDays;

                            return Text(
                              'Você poderá trocar seu username em $daysLeft dias',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                            );
                          },
                        );
                      }

                      return Text(
                        'O username poderá ser alterado após 20 dias.',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () async {
                    final username = controller.text.trim();
                    if (username.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Username não pode estar vazio'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final canChange =
                        await widget.dataStorageService.canChangeUsername();
                    if (!canChange) {
                      final nextDate = await widget.dataStorageService
                          .getNextUsernameChangeDate();
                      if (nextDate != null) {
                        final daysLeft =
                            nextDate.difference(DateTime.now()).inDays;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Você poderá trocar seu username em $daysLeft dias'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }

                    final isAvailable = await widget.dataStorageService
                        .isUsernameAvailable(username);
                    if (!isAvailable) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Este username já está em uso'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final success =
                        await widget.dataStorageService.setUsername(username);
                    if (success) {
                      Navigator.pop(context);
                      setState(() {
                        _cachedUsername = null;
                        _usernameFuture = _loadUsername();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Username definido com sucesso!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String?> _loadUsername() async {
    if (_cachedUsername != null) return _cachedUsername;
    _cachedUsername = await widget.dataStorageService.getUsername();
    return _cachedUsername;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: double.infinity,
                    height: 250,
                    decoration: BoxDecoration(
                      color: Colors.pink[100],
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          top: 10,
                          right: 10,
                          child: IconButton(
                            icon: Icon(Icons.logout),
                            onPressed: () async {
                              try {
                                // Usar o serviço do Supabase para fazer logout
                                final supabaseService = SupabaseService();
                                await supabaseService.signOut();

                                // Navegar para a tela de login, removendo todas as rotas anteriores
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (context) => LoginPage()), 
                                  (Route<dynamic> route) => false
                                );
                              } catch (e) {
                                // Mostrar mensagem de erro se o logout falhar
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Erro ao fazer logout: $e'),
                                    backgroundColor: Colors.red,
                                  )
                                );
                              }
                            },
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildProfilePicture(),
                            SizedBox(height: 10),
                            Text(
                              '@username',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 10),
                            TextButton(
                              onPressed: _showFrameSelector,
                              child: Text(
                                'Trocar moldura',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
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

class MolduraClipper extends CustomClipper<Path> {
  final String molduraAsset;

  MolduraClipper(this.molduraAsset);

  @override
  Path getClip(Size size) {
    return Path()
      ..addOval(Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: (size.width - 20) / 2, // Ligeiramente menor que a moldura
      ));
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
