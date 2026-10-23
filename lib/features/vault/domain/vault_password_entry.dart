import 'dart:convert';

/// Domain model representing a custom key-value field attached to a credential.
///
/// Supports banking credentials, debit card security grids, memorable words,
/// customer IDs, and security question/answer pairs.
class VaultCustomField {
  final String id;
  final String label;
  final String value;
  final bool isConcealed;

  const VaultCustomField({
    required this.id,
    required this.label,
    required this.value,
    this.isConcealed = true,
  });

  VaultCustomField copyWith({
    String? id,
    String? label,
    String? value,
    bool? isConcealed,
  }) {
    return VaultCustomField(
      id: id ?? this.id,
      label: label ?? this.label,
      value: value ?? this.value,
      isConcealed: isConcealed ?? this.isConcealed,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'label': label,
      'value': value,
      'isConcealed': isConcealed,
    };
  }

  factory VaultCustomField.fromMap(Map<String, dynamic> map) {
    return VaultCustomField(
      id: map['id']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      value: map['value']?.toString() ?? '',
      isConcealed: map['isConcealed'] as bool? ?? (map['isSensitive'] as bool? ?? true),
    );
  }

  String toJson() => json.encode(toMap());

  factory VaultCustomField.fromJson(String source) =>
      VaultCustomField.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VaultCustomField &&
        other.id == id &&
        other.label == label &&
        other.value == value &&
        other.isConcealed == isConcealed;
  }

  @override
  int get hashCode => Object.hash(id, label, value, isConcealed);
}

/// Domain model representing an encrypted credential entry in the VaultX vault.
/// Supports Standard Logins, TOTP 2FA Authenticator tokens, Bank PINs (numeric & alphanumeric),
/// Custom Banking Fields, and Secure Notes.
class VaultPasswordEntry {
  final String id;
  final String title;
  final String username;
  final String email;
  final String password;
  final String pin;
  final String transactionPin;
  final List<VaultCustomField> customFields;
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
    this.password = '',
    this.pin = '',
    this.transactionPin = '',
    this.customFields = const [],
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
      (password.isEmpty && !hasPin && !hasCustomFields && notes.isNotEmpty && username.isEmpty);

  bool get hasTotp => totpSecret.trim().isNotEmpty;

  bool get hasPin => pin.isNotEmpty || transactionPin.isNotEmpty;

  bool get hasCustomFields => customFields.isNotEmpty;

  bool get isPinOnly =>
      (password.isEmpty && (hasPin || hasCustomFields)) ||
      category.toLowerCase() == 'pins' ||
      category.toLowerCase() == 'pin';

  bool get isPinAlphanumeric => RegExp(r'[^0-9]').hasMatch(pin);

  bool get isTransactionPinAlphanumeric => RegExp(r'[^0-9]').hasMatch(transactionPin);

  VaultPasswordEntry copyWith({
    String? id,
    String? title,
    String? username,
    String? email,
    String? password,
    String? pin,
    String? transactionPin,
    List<VaultCustomField>? customFields,
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
      pin: pin ?? this.pin,
      transactionPin: transactionPin ?? this.transactionPin,
      customFields: customFields ?? this.customFields,
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
      'pin': pin,
      'transactionPin': transactionPin,
      'customFields': customFields.map((f) => f.toMap()).toList(),
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
      pin: map['pin'] as String? ?? '',
      transactionPin: map['transactionPin'] as String? ?? '',
      customFields: (map['customFields'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(VaultCustomField.fromMap)
              .toList() ??
          const [],
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
