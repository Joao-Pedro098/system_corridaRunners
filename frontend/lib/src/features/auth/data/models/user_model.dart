class UserModel {
  final String id;
  final String nome;
  final String email;
  final String tipo;
  final String? telefone;
  final String? cidade;
  final String? estado;
  final String? avatarUrl;
  final String? bio;
  final String? token;
  final Map<String, dynamic>? recordesPessoais;
  final Map<String, dynamic>? estatisticas;

  UserModel({
    required this.id,
    required this.nome,
    required this.email,
    required this.tipo,
    this.telefone,
    this.cidade,
    this.estado,
    this.avatarUrl,
    this.bio,
    this.token,
    this.recordesPessoais,
    this.estatisticas,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, {String? token}) {
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      nome: json['nome'] ?? '',
      email: json['email'] ?? '',
      tipo: json['tipo'] ?? 'atleta',
      telefone: json['telefone'],
      cidade: json['cidade'],
      estado: json['estado'],
      avatarUrl: json['avatarUrl'],
      bio: json['bio'],
      token: token ?? json['token'],
      recordesPessoais: json['recordesPessoais'] as Map<String, dynamic>?,
      estatisticas: json['estatisticas'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'nome': nome,
      'email': email,
      'tipo': tipo,
      'telefone': telefone,
      'cidade': cidade,
      'estado': estado,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'token': token,
      'recordesPessoais': recordesPessoais,
      'estatisticas': estatisticas,
    };
  }
}
