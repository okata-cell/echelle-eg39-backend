// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF




class Client {
  final String clientId;
  final String nom;
  final String telephone;

  Client({
    required this.clientId,
    required this.nom,
    required this.telephone,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      clientId: json['clientId'],
      nom: json['nom'],
      telephone: json['telephone'],
    );
  }
}