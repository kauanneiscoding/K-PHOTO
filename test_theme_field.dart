import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // Inicialize o Supabase
  await Supabase.initialize(
    url: 'SUA_SUPABASE_URL',
    anonKey: 'SUA_SUPABASE_ANON_KEY',
  );

  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;

  if (userId != null) {
    try {
      // Tentar buscar o campo theme
      final response = await client
          .from('user_profile')
          .select('theme')
          .eq('user_id', userId)
          .maybeSingle();

      print('Resposta do campo theme: $response');
      
      if (response != null && response['theme'] != null) {
        print('Tema encontrado: ${response['theme']}');
      } else {
        print('Campo theme não encontrado ou é nulo');
      }
    } catch (e) {
      print('Erro ao verificar campo theme: $e');
    }
  } else {
    print('Usuário não está logado');
  }
}
