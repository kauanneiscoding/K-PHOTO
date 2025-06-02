import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // Para CustomClipper
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  }

  Future<void> _loadUserProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final response = await _supabase
        .from('user_profile')
        .select('display_name, avatar_url, selected_frame')
        .eq('user_id', userId)
        .maybeSingle();

    if (response != null) {
      setState(() {
        _displayNameController.text = response['display_name'] ?? '';
        _avatarUrl = response['avatar_url'];
        _selectedFrame = response['selected_frame'] ?? 'assets/frame_none.png';
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
    };

    try {
      await _supabase.from('user_profile').update(updates).eq('user_id', userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil atualizado com sucesso')),
        );
      }
      // Retorna 'updated' para a ProfilePage recarregar os dados
      Navigator.pop(context, 'updated');
    } catch (e) {
      debugPrint('❌ Erro ao salvar perfil: $e');
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
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
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
            // Botão de voltar
            Positioned(
              top: 10,
              left: 10,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.pink,
                  size: 30,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
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
