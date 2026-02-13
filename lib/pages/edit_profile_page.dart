import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // Para CustomClipper
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:k_photo/data_storage_service.dart';
import 'package:k_photo/models/profile_wall.dart';
import 'package:k_photo/widgets/photocard_selector_dialog.dart';

class EditProfilePage extends StatefulWidget {
  final String? currentDisplayName;
  final String? currentUsername;
  final String? currentPhotoUrl;
  final String? currentFrameId;

  const EditProfilePage({
    super.key,
    this.currentDisplayName,
    this.currentUsername,
    this.currentPhotoUrl,
    this.currentFrameId,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _displayNameController = TextEditingController();

  String? _avatarUrl;
  String _selectedFrame = 'assets/frame_none.png';
  List<String> _availableFrames = [];
  final TextEditingController _usernameController = TextEditingController();
  
  // Variáveis para fundo de perfil
  String? _profileBackgroundUrl;
  bool _profileBackgroundBlur = false;
  double _profileBackgroundOpacity = 0.2;
  
  // Variáveis para o mural
  List<ProfileWallSlot> _profileWallSlots = [];
  List<ProfileWallSlot> _originalProfileWallSlots = []; // Estado original
  bool _isLoadingWall = false;
  final DataStorageService _dataStorageService = DataStorageService();
  bool _wallHasChanges = false; // Controle de mudanças

  @override
  void initState() {
    super.initState();
    _displayNameController.text = widget.currentDisplayName ?? '';
    _usernameController.text = widget.currentUsername ?? '';
    _avatarUrl = widget.currentPhotoUrl;
    if (widget.currentFrameId != null) {
      _selectedFrame = widget.currentFrameId!;
    }
    _loadUserProfile();
    _loadPurchasedFrames();
    _loadProfileWall();
  }

  Future<void> _loadUserProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final response = await _supabase
        .from('user_profile')
        .select('display_name, avatar_url, selected_frame, profile_background_url, profile_background_blur, profile_background_opacity')
        .eq('user_id', userId)
        .maybeSingle();

    if (response != null) {
      setState(() {
        _displayNameController.text = response['display_name'] ?? '';
        _avatarUrl = response['avatar_url'];
        _selectedFrame = response['selected_frame'] ?? 'assets/frame_none.png';
        _profileBackgroundUrl = response['profile_background_url'];
        _profileBackgroundBlur = response['profile_background_blur'] ?? false;
        _profileBackgroundOpacity = (response['profile_background_opacity'] as num?)?.toDouble() ?? 0.2;
      });
    }
  }

  Future<void> _loadPurchasedFrames() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final response = await _supabase
        .from('purchased_frames')
        .select('frame_path')
        .eq('user_id', userId);

    setState(() {
      _availableFrames = List<String>.from(response.map((e) => e['frame_path']));
      _availableFrames.insert(0, 'assets/frame_none.png'); // sempre incluir opção de sem moldura
    });
  }

  Future<void> _loadProfileWall() async {
    setState(() => _isLoadingWall = true);
    try {
      final wallSlots = await _dataStorageService.getProfileWall();
      if (mounted) {
        setState(() {
          // Se há mudanças pendentes, não sobrescreve o estado local
          if (!_wallHasChanges) {
            // Garante que sempre tenha 3 posições (0, 1, 2)
            _profileWallSlots = List.generate(3, (index) {
              final existingSlot = wallSlots.firstWhere(
                (s) => s.position == index,
                orElse: () => ProfileWallSlot(position: index),
              );
              return existingSlot;
            });
            _originalProfileWallSlots = List.from(_profileWallSlots); // Salva estado original
          }
          _isLoadingWall = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingWall = false);
      }
      debugPrint('❌ Erro ao carregar mural: $e');
    }
  }

  void _showPhotocardSelector(int position) {
    final mainContext = context; // Salva referência ao contexto principal
    showDialog(
      context: context,
      builder: (context) => PhotocardSelectorDialog(
        dataStorageService: _dataStorageService,
        currentWallSlots: _profileWallSlots, // Passa os slots atuais
        onPhotocardSelected: (instanceId, imagePath) async {
          // Primeiro, verifica se já existe um photocard na posição e move para a mochila
          final currentSlot = _profileWallSlots.firstWhere(
            (s) => s.position == position,
            orElse: () => ProfileWallSlot(position: position),
          );
          
          if (!currentSlot.isEmpty) {
            // Move o photocard atual de volta para a mochila e sincroniza imediatamente
            await _dataStorageService.updateCardLocation(
              currentSlot.photocardInstanceId!,
              'backpack',
              binderId: null,
              slotIndex: null,
              pageNumber: null,
            );
            debugPrint('✅ Photocard ${currentSlot.photocardInstanceId} movido para mochila (troca no mural)');
          }
          
          // Atualiza apenas o estado local, não salva no banco ainda
          final newSlot = ProfileWallSlot(
            position: position,
            photocardInstanceId: instanceId,
            photocardImagePath: imagePath,
            placedAt: DateTime.now(),
          );
          
          setState(() {
            // Garante que a lista tenha tamanho suficiente
            while (_profileWallSlots.length <= position) {
              _profileWallSlots.add(ProfileWallSlot(position: _profileWallSlots.length));
            }
            _profileWallSlots[position] = newSlot;
            _wallHasChanges = true;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(mainContext).showSnackBar(
              const SnackBar(
                content: Text('Photocard trocado! Salve as alterações para confirmar.'),
                backgroundColor: Colors.blue,
              ),
            );
          }
        },
      ),
    );
  }

  void _removePhotocardFromWall(int position) async {
    // Move o photocard para a mochila imediatamente
    final slot = _profileWallSlots.firstWhere(
      (s) => s.position == position,
      orElse: () => ProfileWallSlot(position: position),
    );
    
    if (slot != null && !slot.isEmpty) {
      // Move o photocard para a mochila e sincroniza imediatamente
      await _dataStorageService.updateCardLocation(
        slot.photocardInstanceId!,
        'backpack',
        binderId: null,
        slotIndex: null,
        pageNumber: null,
      );
      debugPrint('✅ Photocard ${slot.photocardInstanceId} movido para mochila (remoção do mural)');
    }
    
    // Remove apenas do estado local, não do banco ainda
    setState(() {
      // Garante que a lista tenha tamanho suficiente
      while (_profileWallSlots.length <= position) {
        _profileWallSlots.add(ProfileWallSlot(position: _profileWallSlots.length));
      }
      _profileWallSlots[position] = ProfileWallSlot(position: position);
      _wallHasChanges = true;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Photocard removido! Salve as alterações para confirmar.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showPhotocardOptions(int position, ProfileWallSlot slot) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Opções do Photocard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.pink[700],
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.swap_horiz, color: Colors.pink[600]),
              title: const Text('Trocar photocard'),
              subtitle: const Text('Selecionar outro photocard para esta posição'),
              onTap: () {
                Navigator.pop(context);
                _showPhotocardSelector(position);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.remove_circle_outline, color: Colors.red[600]),
              title: const Text('Remover do mural'),
              subtitle: const Text('Remover photocard e mover para a mochila'),
              onTap: () {
                Navigator.pop(context);
                _removePhotocardFromWall(position);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  bool _isUploading = false;

Future<void> _pickAvatar() async {
  if (_isUploading) return;

  final picker = ImagePicker();
  try {
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
    );

    if (image == null) return;

    setState(() => _isUploading = true);

    final file = File(image.path);
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Novo caminho com subpasta por userId
    final fileExtension = image.path.split('.').last;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    final fullPath = '$userId/$fileName';

    // 1. Upload da nova imagem
    await _supabase.storage
        .from('avatars')
        .upload(fullPath, file);

    // 2. Gerar URL pública com cache busting
    final imageUrl = _supabase.storage
        .from('avatars')
        .getPublicUrl(fullPath) + '?t=${DateTime.now().millisecondsSinceEpoch}';

    // 3. Remover avatar anterior do bucket (se houver)
    if (_avatarUrl != null) {
      try {
        final oldPath = Uri.decodeFull(Uri.parse(_avatarUrl!).pathSegments
            .skipWhile((s) => s != 'avatars')
            .skip(1)
            .join('/'));
        await _supabase.storage.from('avatars').remove([oldPath]);
        debugPrint('🗑️ Avatar antigo removido: $oldPath');
      } catch (e) {
        debugPrint('❌ Erro ao remover avatar antigo: $e');
      }
    }

    // 4. Atualizar o Supabase com a nova URL
    await _supabase.from('user_profile')
        .update({'avatar_url': imageUrl})
        .eq('user_id', userId);

    if (mounted) {
      setState(() {
        _avatarUrl = imageUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil atualizada com sucesso!')),
      );
    }
  } catch (e) {
    debugPrint('❌ Erro ao atualizar avatar: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao atualizar avatar')),
      );
    }
  } finally {
    if (mounted) setState(() => _isUploading = false);
  }
}



  Future<void> _updateProfileAvatar(String imageUrl) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase
          .from('user_profile')
          .update({'avatar_url': imageUrl})
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('❌ Erro ao atualizar URL do avatar no perfil: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao salvar alterações do perfil')),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final updates = {
      'display_name': _displayNameController.text.trim(),
      'username': _usernameController.text.trim(),
      'avatar_url': _avatarUrl,
      'selected_frame': _selectedFrame,
      'profile_background_url': _profileBackgroundUrl,
      'profile_background_blur': _profileBackgroundBlur,
      'profile_background_opacity': _profileBackgroundOpacity,
    };

    try {
      // Salva as alterações do perfil
      await _supabase.from('user_profile').update(updates).eq('user_id', userId);
      
      // Salva as alterações do mural se houver mudanças
      if (_wallHasChanges) {
        await _saveWallChanges();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil atualizado com sucesso')),
        );
      }
      // Retorna 'updated' para a ProfilePage recarregar os dados
      Navigator.pop(context, 'updated');
    } catch (e) {
      debugPrint('❌ Erro ao salvar perfil: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar perfil: $e')),
        );
      }
    }
  }

  Future<void> _saveWallChanges() async {
    try {
      // Primeiro, remove todos os photocards do mural do usuário
      await _supabase
          .from('profile_wall')
          .delete()
          .eq('user_id', _supabase.auth.currentUser!.id);

      // Depois, insere os photocards atualizados
      final List<Map<String, dynamic>> wallInserts = [];
      
      for (final slot in _profileWallSlots) {
        if (!slot.isEmpty) {
          // Move o photocard da localização atual para o mural
          await _dataStorageService.updateCardLocation(
            slot.photocardInstanceId!,
            'profile_wall',
            binderId: null,
            slotIndex: null,
            pageNumber: null,
          );
          
          // Adiciona ao mural
          wallInserts.add({
            'user_id': _supabase.auth.currentUser!.id,
            'position': slot.position,
            'photocard_instance_id': slot.photocardInstanceId,
            'photocard_image_path': slot.photocardImagePath,
            'placed_at': DateTime.now().toIso8601String(),
          });
          
          debugPrint('✅ Photocard ${slot.photocardInstanceId} movido para o mural (salvando)');
        }
      }

      if (wallInserts.isNotEmpty) {
        await _supabase
            .from('profile_wall')
            .insert(wallInserts);
      }
      
      // Atualiza o estado original
      _originalProfileWallSlots = List.from(_profileWallSlots);
      _wallHasChanges = false;
      
    } catch (e) {
      debugPrint('❌ Erro ao salvar mural: $e');
      rethrow;
    }
  }

  void _selectFrame(String path) {
    setState(() {
      _selectedFrame = path;
    });
  }

  Widget _buildProfilePicture() {
    return GestureDetector(
      onTap: _pickAvatar,
      child: Container(
        width: 120,
        height: 120,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_selectedFrame == 'assets/frame_none.png' || _selectedFrame.isEmpty)
              // Imagem circular sem moldura, mas com mesmo tamanho
              Container(
                width: 110, // Mesmo tamanho da imagem com moldura
                height: 110, // Mesmo tamanho da imagem com moldura
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: _avatarUrl != null && _avatarUrl!.isNotEmpty
                      ? DecorationImage(
                          image: _avatarUrl!.startsWith('http')
                              ? NetworkImage(_avatarUrl!) as ImageProvider
                              : FileImage(File(_avatarUrl!)) as ImageProvider,
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: (_avatarUrl == null || _avatarUrl!.isEmpty) 
                      ? Colors.grey[200] 
                      : null,
                ),
                child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                    ? Icon(Icons.person, color: Colors.pink[300], size: 50)
                    : null,
              )
            else
              // Imagem com moldura
              Stack(
                alignment: Alignment.center,
                children: [
                  ClipPath(
                    clipper: MolduraClipper(_selectedFrame),
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: _avatarUrl != null && _avatarUrl!.isNotEmpty
                            ? DecorationImage(
                                image: _avatarUrl!.startsWith('http')
                                    ? NetworkImage(_avatarUrl!) as ImageProvider
                                    : FileImage(File(_avatarUrl!)) as ImageProvider,
                                fit: BoxFit.cover,
                              )
                            : null,
                        color: (_avatarUrl == null || _avatarUrl!.isEmpty) 
                            ? Colors.grey[200] 
                            : null,
                      ),
                      child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                          ? Icon(Icons.person, color: Colors.pink[300], size: 50)
                          : null,
                    ),
                  ),
                  Image.asset(
                    _selectedFrame,
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            // Ícone da câmera
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.pink[200],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenBottom = MediaQuery.of(context).padding.bottom;
    
    // Build children list dynamically to avoid conditional syntax issues
    List<Widget> stackChildren = [];
    
    // Add background if exists - cobrindo absolutamente tudo
    if (_profileBackgroundUrl != null) {
      stackChildren.add(
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: screenHeight + screenBottom, // Altura total incluindo área da barra
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
      );
    }
    
    // Add main content
    stackChildren.add(
      Positioned(
        left: 0,
        top: 0,
        right: 0,
        bottom: 0,
        child: WillPopScope(
          onWillPop: () async {
            if (_wallHasChanges) {
              final shouldLeave = await _showUnsavedChangesDialog();
              return shouldLeave ?? false;
            }
            return true;
          },
          child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildProfilePicture(),
                const SizedBox(height: 20),
                const SizedBox(height: 20),
                // Campo de Nome de Exibição
                TextField(
                  controller: _displayNameController,
                  decoration: InputDecoration(
                    labelText: 'Nome de Exibição',
                    labelStyle: TextStyle(color: Colors.pink[700]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.pink[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.pink[400]!, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.pink[50],
                  ),
                  style: TextStyle(color: Colors.pink[900]),
                ),
                const SizedBox(height: 20),
                // Seção de Molduras
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.pink[50]!.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Escolha uma moldura:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.pink[700],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _availableFrames.map((framePath) {
                          return GestureDetector(
                            onTap: () => _selectFrame(framePath),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _selectedFrame == framePath 
                                      ? Colors.pink[400]! 
                                      : Colors.transparent,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.pink.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  framePath,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                // Mural
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.pink[50]!.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mural do Perfil',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.pink[700],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _isLoadingWall
                          ? const Center(child: CircularProgressIndicator())
                          : GridView.count(
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
                                
                                return GestureDetector(
                                  onTap: () {
                                    if (slot.isEmpty) {
                                      _showPhotocardSelector(index);
                                    } else {
                                      _showPhotocardOptions(index, slot);
                                    }
                                  },
                                  child: Container(
                                    height: double.infinity, // Garante proporção correta
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.pink.withOpacity(0.15),
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
                                                color: Colors.grey[50],
                                                child: Center(
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(
                                                        Icons.add_circle_outline,
                                                        color: Colors.pink[300],
                                                        size: 36,
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        'Adicionar',
                                                        style: TextStyle(
                                                          color: Colors.pink[600],
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
                                            if (!slot.isEmpty)
                                              Positioned(
                                                top: 6,
                                                right: 6,
                                                child: Container(
                                                  padding: const EdgeInsets.all(3),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withOpacity(0.7),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.more_vert,
                                                    color: Colors.white,
                                                    size: 18,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          "✧.*Seu mural pessoal*.✧",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.pink[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                // Botão Salvar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink[300],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 3,
                    ),
                    child: const Text(
                      'Salvar Alterações',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      ),
    );
    
    // Add back button
    stackChildren.add(
      Positioned(
        top: 60,
        left: 10,
        child: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.pink,
            size: 30,
          ),
          onPressed: () async {
          if (_wallHasChanges) {
            final shouldLeave = await _showUnsavedChangesDialog();
            if (shouldLeave == true) {
              Navigator.pop(context);
            }
          } else {
            Navigator.pop(context);
          }
        },
        ),
      ),
    );

    // Add background upload button (no final para ficar por cima)
    stackChildren.add(
      Positioned(
        top: 60,
        right: 10,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              Icons.wallpaper,
              color: Colors.pink[600],
              size: 24,
            ),
            onPressed: _uploadProfileBackground,
            tooltip: 'Alterar fundo do perfil',
          ),
        ),
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Stack(
        children: stackChildren,
      ),
    );
  }
  
  Future<bool?> _showUnsavedChangesDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alterações não salvas'),
        content: const Text('Você fez alterações no mural que não foram salvas. Deseja sair sem salvar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair sem salvar'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadProfileBackground() async {
    // Teste imediato para verificar se o clique funciona
    debugPrint('🔘 BOTÃO CLICADO!');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Botão clicado! Abrindo galeria...'),
          backgroundColor: Colors.purple,
          duration: Duration(seconds: 1),
        ),
      );
    }
    
    try {
      debugPrint('🖼️ Iniciando upload de fundo de perfil...');
      
      // Teste simples: abrir a galeria primeiro
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) {
        debugPrint('❌ Nenhuma imagem selecionada');
        return;
      }

      debugPrint('✅ Imagem selecionada: ${image.path}');
      
      // Mostrar mensagem imediata para confirmar que o botão funciona
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imagem selecionada! Processando upload...'),
            backgroundColor: Colors.blue,
          ),
        );
      }
      
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('❌ Usuário não autenticado');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Usuário não autenticado'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      debugPrint('👤 Usuário ID: $userId');

      // Tentar upload com tratamento de erro detalhado
      try {
        final fileBytes = await image.readAsBytes();
        
        // Gerar nome único como no avatar
        final fileExtension = image.path.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
        final fullPath = '$userId/$fileName';
        
        debugPrint('📤 Fazendo upload para: $fullPath');
        debugPrint('📊 Tamanho do arquivo: ${fileBytes.length} bytes');
        
        final storageResponse = await _supabase.storage
            .from('profile-backgrounds')
            .uploadBinary(
              fullPath, 
              fileBytes,
              fileOptions: supabase.FileOptions(upsert: true),
            );

        debugPrint('📦 Resposta do storage: $storageResponse');

        if (storageResponse != null) {
          final publicUrl = _supabase.storage
              .from('profile-backgrounds')
              .getPublicUrl(fullPath) + '?t=${DateTime.now().millisecondsSinceEpoch}';

          debugPrint('🔗 URL pública: $publicUrl');

          // Remover fundo anterior (se houver)
          if (_profileBackgroundUrl != null) {
            try {
              final oldPath = Uri.decodeFull(Uri.parse(_profileBackgroundUrl!).pathSegments
                  .skipWhile((s) => s != 'profile-backgrounds')
                  .skip(1)
                  .join('/'));
              await _supabase.storage.from('profile-backgrounds').remove([oldPath]);
              debugPrint('🗑️ Fundo antigo removido: $oldPath');
            } catch (e) {
              debugPrint('❌ Erro ao remover fundo antigo: $e');
            }
          }

          setState(() {
            _profileBackgroundUrl = publicUrl;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Fundo de perfil atualizado com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          debugPrint('❌ Falha no upload - resposta nula');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Falha ao fazer upload - verifique as permissões do bucket'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } catch (storageError) {
        debugPrint('❌ Erro específico do storage: $storageError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro no storage: $storageError'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Erro geral ao fazer upload do fundo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao fazer upload do fundo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
