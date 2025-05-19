class Post {
  String? id;
  String autor;
  String conteudo;
  String? midia;
  int curtidas;
  int republicacoes;
  DateTime dataPublicacao;

  Post({
    this.id,
    required this.autor,
    required this.conteudo,
    this.midia,
    this.curtidas = 0,
    this.republicacoes = 0,
    DateTime? dataPublicacao,
  }) : dataPublicacao = dataPublicacao ?? DateTime.now();

  // Converter para Map para usar no SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'autor': autor,
      'conteudo': conteudo,
      'midia': midia,
      'curtidas': curtidas,
      'republicacoes': republicacoes,
      'dataPublicacao': dataPublicacao.toIso8601String(),
    };
  }

  // Criar Post a partir de um Map do SQLite
  factory Post.fromMap(Map<String, dynamic> map) {
    final createdAt = map['created_at'] ?? map['dataPublicacao'];
    return Post(
      id: map['id']?.toString(),
      autor: map['username'] ?? map['autor'] ?? 'Usuário Anônimo',  // Provide default for required field
      conteudo: map['content'] ?? map['conteudo'] ?? '',  // Provide default for required field
      midia: map['midia_url'] ?? map['midia'],
      curtidas: map['likes_count'] ?? map['curtidas'] ?? 0,
      republicacoes: map['reposts_count'] ?? map['republicacoes'] ?? 0,
      dataPublicacao: createdAt != null ? DateTime.parse(createdAt) : DateTime.now()
    );
  }
}

class Comentario {
  String? id;
  String postId;
  String autor;
  String texto;
  DateTime dataCriacao;

  Comentario({
    this.id,
    required this.postId,
    required this.autor,
    required this.texto,
    DateTime? dataCriacao,
  }) : dataCriacao = dataCriacao ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'postId': postId,
      'autor': autor,
      'texto': texto,
      'dataCriacao': dataCriacao.toIso8601String(),
    };
  }

  factory Comentario.fromMap(Map<String, dynamic> map) {
    return Comentario(
      id: map['id'],
      postId: map['postId'],
      autor: map['autor'],
      texto: map['texto'],
      dataCriacao: DateTime.parse(map['dataCriacao']),
    );
  }
}
