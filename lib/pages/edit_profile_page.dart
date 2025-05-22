import 'dart:io';
import 'package:flutter/material.dart';
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

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final file = File(image.path);
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final fileName = 'avatar_$userId.jpg';
      await _supabase.storage.from('avatars').upload(fileName, file, fileOptions: const FileOptions(upsert: true));
      final imageUrl = _supabase.storage.from('avatars').getPublicUrl(fileName);

      setState(() {
        _avatarUrl = imageUrl;
      });
    } catch (e) {
      debugPrint('❌ Erro ao fazer upload do avatar: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        backgroundColor: Colors.pink[100],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 55,
                    backgroundImage: _avatarUrl != null
                        ? NetworkImage(_avatarUrl!)
                        : const AssetImage('assets/default_profile.png') as ImageProvider,
                  ),
                  if (_selectedFrame != 'assets/frame_none.png')
                    Image.asset(_selectedFrame, width: 120, height: 120),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
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
            const SizedBox(height: 20),
            TextField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Nome de exibição',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Escolha uma moldura:'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: _availableFrames.map((framePath) {
                return GestureDetector(
                  onTap: () => _selectFrame(framePath),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _selectedFrame == framePath ? Colors.pink : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset(framePath, width: 60, height: 60),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink[300],
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              ),
              child: const Text('Salvar Alterações'),
            ),
          ],
        ),
      ),
    );
  }
}
