class AdminClient {
  const AdminClient({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.role,
    this.createdAt,
    this.isLocalRegistration = false,
    this.isActive = true,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String role;
  final String? createdAt;
  final bool isLocalRegistration;
  final bool isActive;

  AdminClient copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    bool? isActive,
  }) {
    return AdminClient(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role,
      createdAt: createdAt,
      isLocalRegistration: isLocalRegistration,
      isActive: isActive ?? this.isActive,
    );
  }

  String get fullName {
    final name = '$firstName $lastName'.trim();
    if (name.isNotEmpty) return name;
    if (email.isNotEmpty) return email;
    return 'Client #$id';
  }

  factory AdminClient.fromJson(Map<String, dynamic> json) {
    return AdminClient(
      id: json['id']?.toString().trim() ?? '',
      firstName: json['firstName']?.toString().trim() ?? '',
      lastName: json['lastName']?.toString().trim() ?? '',
      email: json['email']?.toString().trim() ?? '',
      phone: json['phone']?.toString().trim() ?? '',
      role: _normalizeRole(json['role']?.toString() ?? ''),
      createdAt: json['createdAt']?.toString(),
      isActive: json['isActive'] != false,
    );
  }

  /// Reads the existing offline format without retaining its password field.
  static AdminClient? tryParseLocalRegistration(String userData) {
    final parts = userData.split('|');
    if (parts.length < 4) return null;

    final role = _normalizeRole(parts[3]);
    if (role == 'admin') return null;

    final email = parts[0].trim();
    final phone = parts[1].trim();
    if (email.isEmpty && phone.isEmpty) return null;

    return AdminClient(
      id: 'local',
      firstName: parts.length > 4 ? parts[4].trim() : '',
      lastName: parts.length > 5 ? parts[5].trim() : '',
      email: email,
      phone: phone,
      role: role,
      isLocalRegistration: true,
    );
  }
}

String _normalizeRole(String role) {
  final normalized = role.trim().toLowerCase();
  return normalized == 'user' ? 'client' : normalized;
}

/// Combines server records with local registrations, preferring server records
/// when the same account has already synchronized.
List<AdminClient> mergeAdminClients({
  required Iterable<AdminClient> serverClients,
  required Iterable<AdminClient> localClients,
}) {
  final merged = <AdminClient>[];
  final emails = <String>{};
  final phones = <String>{};

  void addIfNew(AdminClient client) {
    if (client.role == 'admin') return;

    final email = client.email.trim().toLowerCase();
    final phone = client.phone.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    if ((email.isNotEmpty && emails.contains(email)) ||
        (phone.isNotEmpty && phones.contains(phone))) {
      return;
    }

    merged.add(client);
    if (email.isNotEmpty) emails.add(email);
    if (phone.isNotEmpty) phones.add(phone);
  }

  for (final client in serverClients) {
    addIfNew(client);
  }
  for (final client in localClients) {
    addIfNew(client);
  }

  return List<AdminClient>.unmodifiable(merged);
}
