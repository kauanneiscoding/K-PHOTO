import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UsernameDialog extends StatefulWidget {
  final String userId;

  const UsernameDialog({Key? key, required this.userId}) : super(key: key);

  @override
  _UsernameDialogState createState() => _UsernameDialogState();
}

class _UsernameDialogState extends State<UsernameDialog> {
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isChecking = false;
  String? _errorText;

  Future<void> _submit() async {
    final username = _usernameController.text.trim().toLowerCase();
    final displayName = _displayNameController.text.trim();

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isChecking = true;
      _errorText = null;
    });

    try {
      final exists = await Supabase.instance.client
          .from('user_profile')
          .select('user_id')
          .eq('username', username)
          .maybeSingle();

      if (exists != null) {
        setState(() {
          _errorText = 'Este username já está em uso.';
          _isChecking = false;
        });
        return;
      }

      await Supabase.instance.client.from('user_profile').upsert({
        'user_id': widget.userId,
        'username': username,
        'display_name': displayName.isNotEmpty ? displayName : null,
      });

      Navigator.of(context).pop(); // Fecha o pop-up
    } catch (e) {
      setState(() {
        _errorText = 'Erro ao salvar username';
        _isChecking = false;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Crie seu nome de usuário'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username (único e fixo)',
                prefixText: '@',
                errorText: _errorText,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe um username';
                }
                if (!RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(value)) {
                  return 'Use apenas letras, números e _ (3–20 caracteres)';
                }
                return null;
              },
            ),
            SizedBox(height: 12),
            TextFormField(
              controller: _displayNameController,
              decoration: InputDecoration(
                labelText: 'Apelido (opcional, pode mudar)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isChecking ? null : _submit,
          child: _isChecking
              ? CircularProgressIndicator()
              : Text('Confirmar'),
        ),
      ],
    );
  }
}
