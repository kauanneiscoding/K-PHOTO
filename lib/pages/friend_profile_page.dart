import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // Para CustomClipper
import 'dart:ui'; // Para ImageFilter
import 'package:k_photo/models/profile_theme.dart';
import 'package:k_photo/models/profile_wall.dart';
import 'package:k_photo/services/social_service.dart';
import 'package:k_photo/widgets/avatar_with_frame.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:k_photo/pages/chat_page.dart';
import 'package:k_photo/services/supabase_service.dart';

class FriendProfilePage extends StatefulWidget {
  final String friendUserId;
  final String friendUsername;

  const FriendProfilePage({
    Key? key,
    required this.friendUserId,
    required this.friendUsername,
  }) : super(key: key);

  @override
  State<FriendProfilePage> createState() => _FriendProfilePageState();
}

class _FriendProfilePageState extends State<FriendProfilePage> {
  final SocialService _socialService = SocialService();
  final SupabaseService _supabaseService = SupabaseService();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Dados do perfil do amigo
  String? _displayName;
  String? _avatarUrl;
  String? _selectedFrame;
  String? _bio;
  String? _profileBackgroundUrl;
  bool _profileBackgroundBlur = false;
  double _profileBackgroundOpacity = 0.2;
  ProfileTheme _profileTheme = ProfileTheme.pink;
  List<ProfileWallSlot> _profileWallSlots = [];
  
  // Controles de estado
  bool _isLoading = true;
  bool _isLoadingWall = false;
  int _muralLikesCount = 0;
  bool _isMuralLiked = false;
  bool _isTogglingMuralLike = false;
  bool _isFriend = false;
  bool _isCheckingFriendship = true;

  @override
  void initState() {
    super.initState();
    _loadFriendProfile();
    _loadProfileWall();
    _loadMuralLikes();
    _checkFriendshipStatus();
  }

  Future<void> _loadFriendProfile() async {
    try {
      final response = await _supabase
          .from('user_profile')
          .select('display_name, avatar_url, selected_frame, bio, profile_background_url, profile_background_blur, profile_background_opacity, theme')
          .eq('user_id', widget.friendUserId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _displayName = response['display_name'];
          _avatarUrl = response['avatar_url'];
          _selectedFrame = response['selected_frame'] ?? 'assets/frame_none.png';
          _bio = response['bio'];
          _profileBackgroundUrl = response['profile_background_url'];
          _profileBackgroundBlur = response['profile_background_blur'] ?? false;
          _profileBackgroundOpacity = (response['profile_background_opacity'] as num?)?.toDouble() ?? 0.2;
          
          // Carregar tema
          final themeString = response['theme'] as String?;
          if (themeString != null) {
            _profileTheme = ProfileTheme.fromString(themeString);
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar perfil do amigo: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadProfileWall() async {
    setState(() => _isLoadingWall = true);
    try {
      final wallSlots = await _socialService.getProfileWall(widget.friendUserId);
      if (mounted) {
        setState(() {
          // Garante que sempre tenha 3 posições (0, 1, 2)
          _profileWallSlots = List.generate(3, (index) {
            final existingSlot = wallSlots.firstWhere(
              (s) => s.position == index,
              orElse: () => ProfileWallSlot(position: index),
            );
            return existingSlot;
          });
          _isLoadingWall = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingWall = false);
      }
      debugPrint('❌ Erro ao carregar mural do amigo: $e');
    }
  }

  Future<void> _loadMuralLikes() async {
    try {
      final result = await _socialService.getProfileWallLikes(widget.friendUserId);
      if (mounted) {
        setState(() {
          _muralLikesCount = (result['likes_count'] as int?) ?? 0;
          _isMuralLiked = (result['is_liked'] as bool?) ?? false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar likes do mural: $e');
    }
  }

  Future<void> _toggleMuralLike() async {
    if (_isTogglingMuralLike) return;

    final previousIsLiked = _isMuralLiked;
    final previousCount = _muralLikesCount;

    setState(() {
      _isTogglingMuralLike = true;
      _isMuralLiked = !_isMuralLiked;
      _muralLikesCount += _isMuralLiked ? 1 : -1;
    });

    try {
      await _socialService.toggleProfileWallLike(widget.friendUserId);
    } catch (e) {
      // Reverte em caso de erro
      if (mounted) {
        setState(() {
          _isMuralLiked = previousIsLiked;
          _muralLikesCount = previousCount;
        });
      }
      debugPrint('❌ Erro ao alternar like no mural: $e');
    } finally {
      if (mounted) {
        setState(() => _isTogglingMuralLike = false);
      }
    }
  }

  Future<void> _checkFriendshipStatus() async {
    try {
      final isFriend = await _supabaseService.isFriend(widget.friendUserId);
      if (mounted) {
        setState(() {
          _isFriend = isFriend;
          _isCheckingFriendship = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao verificar status da amizade: $e');
      if (mounted) {
        setState(() => _isCheckingFriendship = false);
      }
    }
  }

  Future<void> _addFriend() async {
    try {
      // Primeiro, tentar aceitar solicitação pendente existente
      await _supabaseService.acceptPendingFriendRequest(widget.friendUserId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.favorite, color: Colors.white),
                const SizedBox(width: 8),
                Text('Agora vocês são amigos!'),
              ],
            ),
            backgroundColor: Colors.green[400],
          ),
        );
        
        // Atualiza o status para mostrar que agora são amigos
        setState(() => _isFriend = true);
      }
    } catch (e) {
      // Se não houver solicitação pendente, enviar nova solicitação
      try {
        await _supabaseService.sendFriendRequest(widget.friendUserId);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.favorite, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Solicitação de amizade enviada!'),
                ],
              ),
              backgroundColor: Colors.pink[400],
            ),
          );
          
          // Atualiza o status para mostrar que a solicitação foi enviada
          setState(() => _isFriend = true);
        }
      } catch (sendError) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Erro ao enviar solicitação: $sendError'),
                ],
              ),
              backgroundColor: Colors.red[400],
            ),
          );
        }
      }
    }
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          friendUserId: widget.friendUserId,
          friendUsername: widget.friendUsername,
          friendDisplayName: _displayName,
          friendAvatarUrl: _avatarUrl,
          friendSelectedFrame: _selectedFrame,
        ),
      ),
    );
  }

  Future<void> _unfriendUser() async {
    // Mostra diálogo de confirmação bonito e fofo
    final bool? confirmUnfriend = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Impede fechar clicando fora
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.pink.shade50,
                  Colors.purple.shade50,
                  Colors.blue.shade50,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ícone animado
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade300, Colors.red.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.shade300.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.favorite_border_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                // Título
                Text(
                  'Desfazer Amizade? 💔',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.pink.shade700,
                    fontFamily: 'Nunito',
                  ),
                ),
                const SizedBox(height: 12),
                // Mensagem
                Text(
                  'Tem certeza que deseja desfazer a amizade com ${_displayName?.isNotEmpty == true ? _displayName! : widget.friendUsername}?\n\nVocê poderá se tornar amigo novamente no futuro. 💕',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade700,
                    height: 1.4,
                    fontFamily: 'Nunito',
                  ),
                ),
                const SizedBox(height: 24),
                // Botões
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Botão Cancelar
                    Expanded(
                      child: Container(
                        height: 45,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.grey.shade200, Colors.grey.shade300],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade300.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(
                            'Cancelar',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              fontFamily: 'Nunito',
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Botão Desfazer
                    Expanded(
                      child: Container(
                        height: 45,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red.shade400, Colors.pink.shade500],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.shade400.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(
                            'Desfazer 💔',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              fontFamily: 'Nunito',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmUnfriend == true) {
      try {
        await _supabaseService.unfriendUser(widget.friendUserId);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.person_remove_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('Amizade desfeita'),
                ],
              ),
              backgroundColor: Colors.red[400],
              duration: const Duration(seconds: 3),
            ),
          );
          
          // Retorna para a página anterior
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Erro ao desfazer amizade: $e'),
                ],
              ),
              backgroundColor: Colors.red[600],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenBottom = MediaQuery.of(context).padding.bottom;
    
    List<Widget> stackChildren = [];
    
    // Add background if exists
    if (_profileBackgroundUrl != null) {
      stackChildren.add(
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: screenHeight + screenBottom,
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
        child: SafeArea(
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : Padding(
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
                            _displayName?.isNotEmpty ?? false ? _displayName! : widget.friendUsername,
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
                          '@${widget.friendUsername}',
                          style: TextStyle(
                            fontSize: 18,
                            color: _profileTheme.usernameColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Botões de ação
                        Column(
                          children: [
                            // Primeira linha: Enviar Mensagem
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.pink.shade300,
                                    Colors.pink.shade500,
                                    Colors.purple.shade400,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.pink.shade300.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: _openChat,
                                icon: Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                label: Text(
                                  'Enviar Mensagem 💬',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito',
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shadowColor: Colors.transparent,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Segunda linha: Adicionar/Desfazer Amizade
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: _isCheckingFriendship
                                    ? LinearGradient(
                                        colors: [Colors.grey.shade300, Colors.grey.shade500],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : _isFriend
                                        ? LinearGradient(
                                            colors: [
                                              Colors.red.shade300,
                                              Colors.red.shade500,
                                              Colors.orange.shade400,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : LinearGradient(
                                            colors: [
                                              Colors.green.shade300,
                                              Colors.green.shade500,
                                              Colors.teal.shade400,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_isCheckingFriendship
                                            ? Colors.grey.shade300
                                            : _isFriend
                                                ? Colors.red.shade300
                                                : Colors.green.shade300)
                                        .withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: _isCheckingFriendship ? null : (_isFriend ? _unfriendUser : _addFriend),
                                icon: Icon(
                                  _isCheckingFriendship
                                      ? Icons.hourglass_empty
                                      : _isFriend
                                          ? Icons.person_remove_rounded
                                          : Icons.favorite_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                label: Text(
                                  _isCheckingFriendship
                                      ? 'Verificando... ✨'
                                      : _isFriend
                                          ? 'Desfazer Amizade'
                                          : 'Adicionar Amigo 💕',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito',
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shadowColor: Colors.transparent,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 34),
                        // Mural
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
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
                                        color: _profileTheme.textColor,
                                        fontFamily: 'Nunito',
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(14),
                                        onTap: _isTogglingMuralLike ? null : _toggleMuralLike,
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
                                            mainAxisAlignment: MainAxisAlignment.center,
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
                                  _bio?.isNotEmpty == true 
                                    ? _bio!
                                    : "✧.*Mural do perfil*.✧",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _profileTheme.textColor,
                                    fontStyle: _bio?.isNotEmpty == true ? FontStyle.normal : FontStyle.italic,
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
        ),
      ),
    );

    // Add back button
    stackChildren.add(
      Positioned(
        left: 16,
        top: MediaQuery.of(context).padding.top + 16,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/home',
                (Route<dynamic> route) => false,
              );
            },
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Stack(children: stackChildren),
    );
  }

  Widget _buildProfilePicture() {
    return Container(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_selectedFrame == 'assets/frame_none.png' || _selectedFrame?.isEmpty == true)
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: _avatarUrl != null && _avatarUrl!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(_avatarUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: (_avatarUrl == null || _avatarUrl!.isEmpty) 
                    ? Colors.grey[200] 
                    : null,
              ),
              child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                  ? Icon(Icons.person, color: Colors.pink[300], size: 60)
                  : null,
            )
          else
            Stack(
              alignment: Alignment.center,
              children: [
                ClipPath(
                  clipper: MolduraClipper(_selectedFrame!),
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: _avatarUrl != null && _avatarUrl!.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(_avatarUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color: (_avatarUrl == null || _avatarUrl!.isEmpty) 
                          ? Colors.grey[200] 
                          : null,
                    ),
                    child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                        ? Icon(Icons.person, color: Colors.pink[300], size: 60)
                        : null,
                  ),
                ),
                Image.asset(
                  _selectedFrame!,
                  width: 140,
                  height: 140,
                  fit: BoxFit.contain,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// Classe auxiliar para moldura (copiada da edit_profile_page)
class MolduraClipper extends CustomClipper<Path> {
  final String framePath;
  
  MolduraClipper(this.framePath);

  @override
  Path getClip(Size size) {
    return Path()
      ..addOval(Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: (size.width - 20) / 2, // Margem ajustada para o novo tamanho
      ));
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
