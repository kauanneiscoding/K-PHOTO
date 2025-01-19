import 'dart:io';

void main() async {
  try {
    // Executar pub get
    final pubGet = await Process.run('dart', ['pub', 'get'], 
        workingDirectory: 'c:/Users/ADMIN/k_photo/scripts');

    if (pubGet.exitCode == 0) {
      print('✅ Dependências instaladas com sucesso!');
    } else {
      print('❌ Erro ao instalar dependências:');
      print(pubGet.stderr);
    }
  } catch (e) {
    print('❌ Erro fatal: $e');
    exit(1);
  }
}
