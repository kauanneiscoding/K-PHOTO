import 'package:flutter/material.dart';
import 'package:k_photo/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FriendPage extends StatefulWidget {
  const FriendPage({Key? key}) : super(key: key);

  @override
  State<FriendPage> createState() => _FriendPageState();
}

class _FriendPageState extends State<FriendPage> {
  late final SupabaseService _supabaseService;
  final _usernameController = TextEditingController();
  final _searchController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _supabaseService = SupabaseService();
    _loadFriendsAndRequests();
  }

  Future<void> _loadFriendsAndRequests() async {
    final friends = await _supabaseService.getFriendsDetails();
    final requests = await _supabaseService.getPendingFriendRequests();

    setState(() {
      _friends = friends;
      _requests = requests;
    });
  }

  void _showAddFriendDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícone e título
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.pink[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite_border_rounded,
                  color: Colors.pink[400],
                  size: 32,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Fazer Nova Amizade',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink[700],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Digite o username do seu futuro amigo',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              // Campo de texto
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  hintText: '@username',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.person_outline, color: Colors.pink[300]),
                  filled: true,
                  fillColor: Colors.pink[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.pink[200]!),
                  ),
                ),
                style: TextStyle(fontFamily: 'Nunito'),
              ),
              SizedBox(height: 24),
              // Botões
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Botão Cancelar
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        color: Colors.grey[600],
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                  // Botão Enviar
                  ElevatedButton(
                    onPressed: () async {
                      final username = _usernameController.text.trim();
                      if (username.isEmpty) return;

                      try {
                        final user = await _supabaseService.findUserByUsername(username);
                        if (user == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Usuário não encontrado'),
                              backgroundColor: Colors.red[400],
                            ),
                          );
                          return;
                        }
                        
                        await _supabaseService.sendFriendRequest(user['id']);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.favorite, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Solicitação enviada!'),
                              ],
                            ),
                            backgroundColor: Colors.pink[400],
                          ),
                        );
                        _loadFriendsAndRequests();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Erro ao enviar solicitação: $e'),
                            backgroundColor: Colors.red[400],
                          ),
                        );
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.send_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Enviar',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink[400],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.pink[400]),
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop(); // Fecha o popup da FeedPage
          },
        ),
        title: Row(
          children: [
            Icon(Icons.favorite, color: Colors.pink[400], size: 24),
            SizedBox(width: 8),
            Text(
              'Amizades',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.pink[400],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFriendsAndRequests,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListView(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.pink[100]!, Colors.pink[50]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pink[100]!.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(16),
                      child: _buildAddFriendSection(),
                    ),
                    SizedBox(height: 24),

                    _buildFriendRequests(),
                    SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.people_alt_outlined, color: Colors.blue[400]),
                          SizedBox(width: 8),
                          Text(
                            'Meus Amigos',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                              fontFamily: 'Nunito',
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildFriendList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFriendList() {
    if (_friends.isEmpty) {
      return Center(
        child: Text(
          'Nenhum amigo encontrado',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _friends.map((friend) {
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: friend['avatar_url'] != null
                ? NetworkImage(friend['avatar_url'])
                : AssetImage('assets/default_profile.png') as ImageProvider,
          ),
          title: Text('@${friend['username']}'),
          subtitle: Text('Visto há ${friend['last_seen']} minutos'),
        );
      }).toList(),
    );
  }

  Widget _buildFriendRequests() {
    if (_requests.isEmpty) return SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.pink[50],
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.mail_outline_rounded, color: Colors.pink[400]),
              SizedBox(width: 8),
              Text(
                'Solicitações pendentes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink[700],
                  fontFamily: 'Nunito',
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        ..._requests.map((req) {
          return Card(
            margin: EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.pink[100],
                child: Icon(Icons.person, color: Colors.pink[400]),
              ),
              title: Text(
                '@${req['username']}',
                style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Quer ser seu amigo!',
                style: TextStyle(color: Colors.pink[300], fontFamily: 'Nunito'),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.check_circle_outline, color: Colors.green[400]),
                      onPressed: () async {
                        await _supabaseService.acceptFriendRequest(req['id'], req['sender_id']);
                        _loadFriendsAndRequests();
                      },
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.close_rounded, color: Colors.red[400]),
                      onPressed: () async {
                        await _supabaseService.declineFriendRequest(req['id']);
                        _loadFriendsAndRequests();
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildAddFriendSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          style: TextStyle(fontFamily: 'Nunito'),
          decoration: InputDecoration(
            labelText: 'Buscar por username',
            labelStyle: TextStyle(color: Colors.pink[400], fontFamily: 'Nunito'),
            hintText: '@username',
            hintStyle: TextStyle(color: Colors.grey[400], fontFamily: 'Nunito'),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.pink[100]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.pink[100]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.pink[400]!, width: 2),
            ),
            suffixIcon: Container(
              margin: EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.pink[400]!, Colors.pink[300]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(Icons.person_add, color: Colors.white),
                onPressed: () async {
                  final user = await _supabaseService.findUserByUsername(_searchController.text.trim());
                  if (user != null) {
                    await _supabaseService.sendFriendRequest(user['id']);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.favorite, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Solicitação enviada!'),
                          ],
                        ),
                        backgroundColor: Colors.pink[400],
                      ),
                    );
                    _searchController.clear();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Usuário não encontrado'),
                          ],
                        ),
                        backgroundColor: Colors.red[400],
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
