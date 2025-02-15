class Post {
  int? id;
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
    return Post(
      id: map['id'],
      autor: map['autor'],
      conteudo: map['conteudo'],
      midia: map['midia'],
      curtidas: map['curtidas'] ?? 0,
      republicacoes: map['republicacoes'] ?? 0,
      dataPublicacao: DateTime.parse(map['dataPublicacao']),
    );
  }
}

class Comentario {
  int? id;
  int postId;
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
