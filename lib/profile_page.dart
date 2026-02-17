import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'currency_service.dart';
import 'data_storage_service.dart';
import 'package:k_photo/services/supabase_service.dart';
import 'package:k_photo/services/social_service.dart';
import 'package:k_photo/login_page.dart';
import 'package:k_photo/pages/edit_profile_page.dart';
import 'package:k_photo/services/frame_service.dart';
import 'package:k_photo/widgets/photocard_selector_dialog.dart';
import 'package:k_photo/models/profile_wall.dart';
import 'package:k_photo/models/profile_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  String selectedFrame = 'assets/frame_none.png';
  List<String> frames = ['assets/frame_none.png'];
  String? _cachedUsername;
  late Future<String?> _usernameFuture;
  bool _isLoadingFrames = false;
  final _supabaseService = SupabaseService();
  final SocialService _socialService = SocialService();
  String? _username;
  String? _displayName;
  String? _userBio; // Bio do usuário
  List<ProfileWallSlot> _profileWallSlots = [];
  bool _isLoadingWall = false;
  bool _isLoadingMuralLikes = false;
  bool _isTogglingMuralLike = false;
  int _muralLikesCount = 0;
  bool _isMuralLiked = false;
  
  // Variáveis para fundo de perfil
  String? _profileBackgroundUrl;
  bool _profileBackgroundBlur = false;
  double _profileBackgroundOpacity = 0.2;
  
  // Variável para tema
  ProfileTheme _profileTheme = ProfileTheme.pink;

  @override
  void initState() {
    super.initState();
    // Inicializa o FrameService com o ID do usuário atual
    final userId = widget.dataStorageService.getCurrentUserId();
    if (userId != null) {
      FrameService.setCurrentUserId(userId);
    }
    _loadUsername();
    _loadSelectedFrame();
    _loadPurchasedFrames();
    _loadUserProfile();
    _loadProfileWall();
    _loadMuralLikes(showLoading: true);
  }

  Future<void> _loadMuralLikes({bool showLoading = false}) async {
    final profileUserId = Supabase.instance.client.auth.currentUser?.id;
    if (profileUserId == null) return;

    if (showLoading && mounted) setState(() => _isLoadingMuralLikes = true);
    try {
      final result = await _socialService.getProfileWallLikes(profileUserId);
      if (!mounted) return;
      setState(() {
        _muralLikesCount = (result['likes_count'] as int?) ?? 0;
        _isMuralLiked = (result['is_liked'] as bool?) ?? false;
        _isLoadingMuralLikes = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (showLoading) {
        setState(() => _isLoadingMuralLikes = false);
      }
    }
  }

  Future<void> _toggleMuralLike() async {
    final profileUserId = Supabase.instance.client.auth.currentUser?.id;
    if (profileUserId == null) return;

    if (_isTogglingMuralLike) return;

    final previousIsLiked = _isMuralLiked;
    final previousCount = _muralLikesCount;
    final nextIsLiked = !previousIsLiked;
    final nextCount = nextIsLiked
        ? previousCount + 1
        : (previousCount > 0 ? previousCount - 1 : 0);

    setState(() {
      _isTogglingMuralLike = true;
      _isMuralLiked = nextIsLiked;
      _muralLikesCount = nextCount;
    });

    try {
      await _socialService.toggleProfileWallLike(profileUserId, previousIsLiked);
      // Re-sincroniza em background sem mostrar loading/spinner
      await _loadMuralLikes(showLoading: false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isMuralLiked = previousIsLiked;
        _muralLikesCount = previousCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao curtir/descurtir o mural. Tente novamente.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isTogglingMuralLike = false);
    }
  }

  Future<void> _loadUserProfile() async {
    final profileUserId = Supabase.instance.client.auth.currentUser?.id;
    if (profileUserId == null) return;

    try {
      final response = await _supabaseService.getUserProfile(profileUserId);

      if (response != null && mounted) {
        setState(() {
          _username = response['username'];
          _displayName = response['display_name'];
          _userBio = response['bio']; // Carregar bio
          profileImagePath = response['avatar_url'];
          selectedFrame = response['selected_frame'] ?? 'assets/frame_none.png';
          _profileBackgroundUrl = response['profile_background_url'];
          _profileBackgroundBlur = response['profile_background_blur'] ?? false;
          _profileBackgroundOpacity = (response['profile_background_opacity'] as num?)?.toDouble() ?? 0.2;
          
          // Carregar tema
          final themeString = response['theme'] as String?;
          if (themeString != null) {
            _profileTheme = ProfileTheme.fromString(themeString);
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao recarregar perfil: $e');
    }
  }

  Future<void> _loadProfileWall() async {
    setState(() => _isLoadingWall = true);
    try {
      final wallSlots = await widget.dataStorageService.getProfileWall();
      if (mounted) {
        setState(() {
          _profileWallSlots = wallSlots;
          _isLoadingWall = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar mural: $e');
      if (mounted) {
        setState(() => _isLoadingWall = false);
      }
    }
  }

  void _showPhotocardSelector(int position) {
    final mainContext = context; // Salva referência ao contexto principal
    showDialog(
      context: context,
      builder: (dialogContext) => PhotocardSelectorDialog(
        dataStorageService: widget.dataStorageService,
        currentWallSlots: _profileWallSlots, // Passa os slots atuais
        onPhotocardSelected: (instanceId, imagePath) async {
          try {
            // Primeiro, remove o photocard atual da posição e move para a mochila
            await widget.dataStorageService.removePhotocardFromWall(position);
            
            // Depois, coloca o novo photocard na posição
            await widget.dataStorageService.placePhotocardOnWall(
              position: position,
              photocardInstanceId: instanceId,
              photocardImagePath: imagePath,
              removeFromCurrentLocation: false, // Não remove, já foi removido manualmente
            );
            await _loadProfileWall(); // Recarrega o mural
            
            if (mounted) {
              ScaffoldMessenger.of(mainContext).showSnackBar(
                const SnackBar(
                  content: Text('Photocard trocado com sucesso!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(mainContext).showSnackBar(
                SnackBar(
                  content: Text('Erro ao trocar photocard: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _removePhotocardFromWall(int position) async {
    try {
      await widget.dataStorageService.removePhotocardFromWall(position);
      await _loadProfileWall(); // Recarrega o mural
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photocard removido do mural e movido para a mochila'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao remover photocard do mural: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPhotocardOptions(int position, ProfileWallSlot slot) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) {
          return Opacity(
            opacity: t,
            child: Transform.scale(
              scale: 0.96 + (0.04 * t),
              child: child,
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.pink.withOpacity(0.15),
                blurRadius: 18,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.pink[100],
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Opções do Photocard',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink[700],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.pink[50],
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.pink.withOpacity(0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(Icons.swap_horiz, color: Colors.pink[400]),
                      ),
                      title: const Text('Trocar photocard'),
                      subtitle: const Text('Selecionar outro photocard para esta posição'),
                      onTap: () {
                        Navigator.pop(context);
                        _showPhotocardSelector(position);
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(Icons.delete_outline, color: Colors.red[400]),
                      ),
                      title: const Text('Remover do mural'),
                      subtitle: const Text('Mover photocard de volta para a mochila'),
                      onTap: () {
                        Navigator.pop(context);
                        _removePhotocardFromWall(position);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadSelectedFrame() async {
    try {
      final frame = await widget.dataStorageService.getSelectedFrame();
      setState(() {
        selectedFrame = frame ?? 'assets/frame_none.png';
      });
    } catch (e) {
      debugPrint('❌ Erro ao carregar frame selecionado: $e');
    }
  }

  Future<void> _loadPurchasedFrames() async {
    if (_isLoadingFrames) return;

    setState(() {
      _isLoadingFrames = true;
    });

    try {
      final purchasedFrames = await FrameService.getPurchasedFrames();
      setState(() {
        frames = ['assets/frame_none.png', ...purchasedFrames];
      });
    } catch (e) {
      debugPrint('❌ Erro ao carregar frames comprados: $e');
    } finally {
      setState(() {
        _isLoadingFrames = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    try {
      await _supabaseService.signOut();
      if (!mounted) return;
      
      // Navegar para a tela de login
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      debugPrint('❌ Erro ao fazer logout: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao fazer logout. Tente novamente.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Sair da conta'),
          content: Text('Tem certeza que deseja sair da sua conta?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Fecha o dialog
                _handleLogout(); // Executa o logout
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Sair'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveSelectedFrame(String frame) async {
    try {
      await widget.dataStorageService.setSelectedFrame(frame);
      setState(() {
        selectedFrame = frame;
      });
      debugPrint('✅ Frame selecionado salvo com sucesso: $frame');
    } catch (e) {
      debugPrint('❌ Erro ao salvar frame selecionado: $e');
    }
  }



Future<void> _pickImage() async {
  try {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final fileExtension = image.path.split('.').last;
    final uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    final fullPath = '$userId/$uniqueFileName'; // Subpasta por ID de usuário
    final file = File(image.path);

    // Fazer upload do arquivo
    await Supabase.instance.client.storage
        .from('avatars')
        .upload(fullPath, file);

    // Gerar URL com cache busting
    final String imageUrl = Supabase.instance.client.storage
        .from('avatars')
        .getPublicUrl(fullPath) + '?t=${DateTime.now().millisecondsSinceEpoch}';

    // Atualiza no banco
    await Supabase.instance.client
        .from('user_profile')
        .update({'avatar_url': imageUrl})
        .eq('user_id', userId);

    if (mounted) {
      setState(() {
        profileImagePath = imageUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil atualizada com sucesso!')),
      );
    }
  } catch (e) {
    debugPrint('❌ Erro ao atualizar a foto de perfil: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao atualizar a foto de perfil')),
      );
    }
  }
}


  Widget _buildProfilePicture() {
    return Container(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (selectedFrame == 'assets/frame_none.png')
            // Imagem circular sem moldura, mas com mesmo tamanho
            Container(
              width: 110, // Mesmo tamanho da imagem com moldura
              height: 110, // Mesmo tamanho da imagem com moldura
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: profileImagePath != null
                      ? (profileImagePath!.startsWith('http')
                          ? NetworkImage(profileImagePath!)
                          : FileImage(File(profileImagePath!)) as ImageProvider)
                      : const AssetImage('assets/default_profile.png'),
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
                  clipper: MolduraClipper(selectedFrame),
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: profileImagePath != null
                            ? (profileImagePath!.startsWith('http')
                                ? NetworkImage(profileImagePath!)
                                : FileImage(File(profileImagePath!)) as ImageProvider)
                            : const AssetImage('assets/default_profile.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Image.asset(
                  selectedFrame,
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showFrameSelector() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return FutureBuilder<List<String>>(
          future: FrameService.getPurchasedFrames(),
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
                      children: frames.map((framePath) {
                        return _buildFrameOption(
                          framePath,
                          framePath == 'assets/frame_none.png' ? 'Sem moldura' : 'Moldura ${frames.indexOf(framePath)}',
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

  Widget _buildFrameOption(String framePath, String label) {
    return GestureDetector(
      onTap: () async {
        await _saveSelectedFrame(framePath);
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
                color: selectedFrame == framePath ? Colors.pink : Colors.grey,
                width: 2,
              ),
              image: DecorationImage(
                image: AssetImage(framePath),
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
                  FutureBuilder<String?>(
                    future: _usernameFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        );
                      }

                      final username = snapshot.data;
                      return Text(
                        username != null ? '@$username' : 'Sem username',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
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

                    final userId = _supabaseService.getCurrentUser()?.id;
                    if (userId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Usuário não está logado'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    try {
                      await _supabaseService.setUsername(userId, username);
                      setState(() {
                        _cachedUsername = null;
                        _usernameFuture = _loadUsername();
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Username definido com sucesso!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erro ao definir username: $e'),
                          backgroundColor: Colors.red,
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
    if (_cachedUsername != null) {
      setState(() {
        _username = _cachedUsername;
      });
      return _cachedUsername;
    }

    try {
      _cachedUsername = await _supabaseService.getUsername();
      setState(() {
        _username = _cachedUsername;
      });
      return _cachedUsername;
    } catch (e) {
      debugPrint('❌ Erro ao carregar username: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenBottom = MediaQuery.of(context).padding.bottom;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Stack(
        children: [
          // Fundo de perfil (se existir) - cobrindo absolutamente tudo
          if (_profileBackgroundUrl != null)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(_profileBackgroundUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(_profileBackgroundOpacity),
                    ),
                  ),
                ),
              ),
            ),
          // Botão de logout no topo direito
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.logout, color: Colors.black87, size: 20),
              ),
              onPressed: _showLogoutDialog,
            ),
          ),
          // Conteúdo principal - sem SafeArea para grudar na barra
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 80, // Apenas padding da status bar
              left: 16,
              right: 16,
              bottom: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildProfilePicture(),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: _profileTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: _profileTheme.primaryColor.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      (_displayName?.isNotEmpty ?? false) ? _displayName! : (_username != null ? _username! : 'Carregando...'),
                      style: TextStyle(
                        fontSize: 24,
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w600,
                        color: _profileTheme.textColor,
                      ),
                    ),
                  ),
              const SizedBox(height: 4),
              Text(
                _username != null ? '@$_username' : 'Carregando...',
                style: TextStyle(
                  fontSize: 18,
                  color: _profileTheme.usernameColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => EditProfilePage(
                        currentDisplayName: _displayName,
                        currentUsername: _username,
                        currentPhotoUrl: profileImagePath,
                        currentFrameId: selectedFrame,
                      )),
                    );

                    if (result == 'updated') {
                      await _loadUserProfile(); // Recarrega os dados do perfil
                      await _loadProfileWall(); // Recarrega o mural
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _profileTheme.surfaceColor,
                    foregroundColor: _profileTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Editar perfil'),
                ),
              ),
              const SizedBox(height: 20),
              // Mural
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _profileTheme.surfaceColor.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _profileTheme.primaryColor.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Mural',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _profileTheme.isDark ? Colors.white : _profileTheme.primaryColor,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: _isLoadingMuralLikes ? null : _toggleMuralLike,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _profileTheme.isDark 
                                    ? Colors.grey[700]!.withOpacity(0.8)
                                    : Colors.grey[200]!.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _profileTheme.isDark 
                                      ? Colors.grey[600]!
                                      : Colors.grey[300]!,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 150),
                                      transitionBuilder: (child, animation) => ScaleTransition(
                                        scale: animation,
                                        child: child,
                                      ),
                                      child: Icon(
                                        _isMuralLiked ? Icons.favorite : Icons.favorite_border,
                                        key: ValueKey<bool>(_isMuralLiked),
                                        color: _isMuralLiked 
                                          ? (_profileTheme.isDark ? Colors.pink[300] : Colors.pink[400])
                                          : (_profileTheme.isDark ? Colors.grey[400] : Colors.grey[600]),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 150),
                                      transitionBuilder: (child, animation) => FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      ),
                                      child: Text(
                                        _muralLikesCount.toString(),
                                        key: ValueKey<int>(_muralLikesCount),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: _profileTheme.isDark ? Colors.white : Colors.grey[800],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _isLoadingWall
                        ? const Center(child: CircularProgressIndicator())
                        : GridView.count(
                            padding: const EdgeInsets.only(top:10),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.75, // Mais alto que largo (estilo binder)
                            children: List.generate(3, (index) {
                              final slot = _profileWallSlots.firstWhere(
                                (s) => s.position == index,
                                orElse: () => ProfileWallSlot(position: index),
                              );
                              
                              return Container(
                                height: double.infinity, // Garante proporção correta
                                decoration: BoxDecoration(
                                  color: _profileTheme.isDark ? Colors.grey[800] : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _profileTheme.primaryColor.withOpacity(0.15),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: AspectRatio(
                                    aspectRatio: 2/3, // Proporção padrão de photocard
                                    child: Stack(
                                      children: [
                                        if (slot.isEmpty)
                                          Container(
                                            color: _profileTheme.isDark ? Colors.grey[700] : Colors.grey[50],
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.photo_album_outlined,
                                                    color: _profileTheme.accentColor,
                                                    size: 36,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Vazio',
                                                    style: TextStyle(
                                                      color: _profileTheme.primaryColor,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                        else
                                          slot.photocardImagePath!.startsWith('http')
                                              ? Image.network(
                                                  slot.photocardImagePath!,
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Container(
                                                      color: Colors.grey[200],
                                                      child: Icon(
                                                        Icons.broken_image,
                                                        color: Colors.grey[400],
                                                        size: 40,
                                                      ),
                                                    );
                                                  },
                                                )
                                              : Image.asset(
                                                  slot.photocardImagePath!,
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Container(
                                                      color: Colors.grey[200],
                                                      child: Icon(
                                                        Icons.broken_image,
                                                        color: Colors.grey[400],
                                                        size: 40,
                                                      ),
                                                    );
                                                  },
                                                ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        _userBio?.isNotEmpty == true 
                          ? _userBio!
                          : "✧.*Mural do perfil*.✧",
                        style: TextStyle(
                          fontSize: 16,
                          color: _profileTheme.textColor,
                          fontStyle: _userBio?.isNotEmpty == true ? FontStyle.normal : FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
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