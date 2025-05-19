import 'package:flutter/material.dart';
import 'package:k_photo/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FriendPage extends StatefulWidget {
  const FriendPage({Key? key}) : super(key: key);

  @override
  State<FriendPage> createState() => _FriendPageState();
}

class _FriendPageState extends State<FriendPage> {
  final _supabaseService = SupabaseService();
  final _usernameController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _friends = [];

  @override
  void initState() {
    super.initState();
    _loadFriendData();
  }

  Future<void> _loadFriendData() async {
    setState(() => _isLoading = true);
    try {
      final requests = await _supabaseService.getPendingFriendRequests();
      final friends = await _supabaseService.getFriendsDetails();
      
      setState(() {
        _pendingRequests = requests;
        _friends = friends;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar dados: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
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
                        _loadFriendData();
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
              onRefresh: _loadFriendData,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListView(
                  children: [
                    // Botão de adicionar amizade
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
                      child: ElevatedButton.icon(
                        onPressed: _showAddFriendDialog,
                        icon: Icon(Icons.favorite_border_rounded, size: 24),
                        label: Text(
                          'Fazer Nova Amizade',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.pink[700],
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 24),

                    if (_pendingRequests.isNotEmpty) ...[                      
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
                              'Solicitações Pendentes',
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
                      ..._pendingRequests.map((request) => Card(
                        margin: EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.pink[100],
                                child: Icon(Icons.person, color: Colors.pink[400]),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.pink[50],
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: Icon(Icons.favorite, size: 12, color: Colors.pink[400]),
                                ),
                              ),
                            ],
                          ),
                          title: Text(
                            request['sender_id'],
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
                                    await _supabaseService.acceptFriendRequest(
                                      request['id'],
                                      request['sender_id'],
                                    );
                                    _loadFriendData();
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
                                    await _supabaseService.declineFriendRequest(
                                      request['id'],
                                    );
                                    _loadFriendData();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      )).toList(),
                      SizedBox(height: 24),
                    ],

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
                    if (_friends.isEmpty)
                      Center(
                        child: Text(
                          'Nenhum amigo ainda',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ..._friends.map((friend) => Card(
                        margin: EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.blue[100],
                                child: Icon(Icons.person, color: Colors.blue[400]),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: friend['last_seen'] != null ? Colors.green[100] : Colors.grey[100],
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: Icon(
                                    friend['last_seen'] != null ? Icons.check_circle : Icons.access_time,
                                    size: 12,
                                    color: friend['last_seen'] != null ? Colors.green[700] : Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          title: Text(
                            friend['username'] ?? 'Sem nome',
                            style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            friend['last_seen'] != null
                                ? 'Online'
                                : 'Offline',
                            style: TextStyle(
                              color: friend['last_seen'] != null ? Colors.green[700] : Colors.grey[600],
                              fontFamily: 'Nunito',
                            ),
                          ),
                          trailing: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: IconButton(
                              icon: Icon(Icons.chat_rounded, color: Colors.blue[400]),
                              onPressed: () {
                                // TODO: Implementar navegação para o chat
                              },
                            ),
                          ),
                        ),
                      )).toList(),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }
}
