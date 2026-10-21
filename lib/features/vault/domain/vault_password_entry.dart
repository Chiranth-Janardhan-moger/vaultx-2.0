import 'dart:convert';

/// Domain model representing an encrypted credential entry in the VaultX vault.
/// Supports Standard Logins, TOTP 2FA Authenticator tokens, and Secure Notes.
class VaultPasswordEntry {
  final String id;
  final String title;
  final String username;
  final String email;
  final String password;
  final String category;
  final String websiteUrl;
  final String notes;
  final String totpSecret;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final bool isFavorite;

  const VaultPasswordEntry({
    required this.id,
    required this.title,
    required this.username,
    this.email = '',
    required this.password,
    this.category = 'All',
    this.websiteUrl = '',
    this.notes = '',
    this.totpSecret = '',
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isFavorite = false,
  });

  bool get isSecureNote =>
      category.toLowerCase() == 'notes' ||
      category.toLowerCase() == 'secure note' ||
      category.toLowerCase() == 'note' ||
      (password.isEmpty && notes.isNotEmpty && username.isEmpty);

  bool get hasTotp => totpSecret.trim().isNotEmpty;

  VaultPasswordEntry copyWith({
    String? id,
    String? title,
    String? username,
    String? email,
    String? password,
    String? category,
    String? websiteUrl,
    String? notes,
    String? totpSecret,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? isFavorite,
  }) {
    return VaultPasswordEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      category: category ?? this.category,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      notes: notes ?? this.notes,
      totpSecret: totpSecret ?? this.totpSecret,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'username': username,
      'email': email,
      'password': password,
      'category': category,
      'websiteUrl': websiteUrl,
      'notes': notes,
      'totpSecret': totpSecret,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isDeleted': isDeleted,
      'isFavorite': isFavorite,
    };
  }

  factory VaultPasswordEntry.fromMap(Map<String, dynamic> map) {
    return VaultPasswordEntry(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      username: map['username'] as String? ?? '',
      email: map['email'] as String? ?? '',
      password: map['password'] as String? ?? '',
      category: map['category'] as String? ?? 'All',
      websiteUrl: map['websiteUrl'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      totpSecret: map['totpSecret'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isDeleted: map['isDeleted'] as bool? ?? false,
      isFavorite: map['isFavorite'] as bool? ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory VaultPasswordEntry.fromJson(String source) =>
      VaultPasswordEntry.fromMap(json.decode(source) as Map<String, dynamic>);
}
