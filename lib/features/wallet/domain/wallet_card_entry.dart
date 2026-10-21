import 'dart:convert';

/// Domain model representing a payment or identity card in the VaultX digital wallet.
class WalletCardEntry {
  final String id;
  final String title;
  final String cardholderName;
  final String cardNumber; // Full 16-digit or 15-digit number
  final String expiry; // MM/YY
  final String cvv; // 3 or 4 digit CVV/CVC
  final String network; // 'Visa', 'Mastercard', 'Amex', 'Plexee'
  final String cardTheme; // 'chase_sapphire', 'apple_titanium', 'plexee_sovereign', 'standard'
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  const WalletCardEntry({
    required this.id,
    required this.title,
    required this.cardholderName,
    required this.cardNumber,
    required this.expiry,
    required this.cvv,
    required this.network,
    this.cardTheme = 'standard',
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  /// Returns the masked version of the card number (e.g., •••• •••• •••• 7890)
  String get maskedNumber {
    final clean = cardNumber.replaceAll(RegExp(r'\s+'), '');
    if (clean.length < 4) return clean;
    final last4 = clean.substring(clean.length - 4);
    if (clean.length == 15) {
      return '•••• •••••• •$last4';
    }
    return '•••• •••• •••• $last4';
  }

  /// Returns the formatted card number with spaces every 4 digits
  String get formattedNumber {
    final clean = cardNumber.replaceAll(RegExp(r'\s+'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(clean[i]);
    }
    return buffer.toString();
  }

  WalletCardEntry copyWith({
    String? id,
    String? title,
    String? cardholderName,
    String? cardNumber,
    String? expiry,
    String? cvv,
    String? network,
    String? cardTheme,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return WalletCardEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      cardholderName: cardholderName ?? this.cardholderName,
      cardNumber: cardNumber ?? this.cardNumber,
      expiry: expiry ?? this.expiry,
      cvv: cvv ?? this.cvv,
      network: network ?? this.network,
      cardTheme: cardTheme ?? this.cardTheme,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'cardholderName': cardholderName,
      'cardNumber': cardNumber,
      'expiry': expiry,
      'cvv': cvv,
      'network': network,
      'cardTheme': cardTheme,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isDeleted': isDeleted,
    };
  }

  factory WalletCardEntry.fromMap(Map<String, dynamic> map) {
    return WalletCardEntry(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      cardholderName: map['cardholderName'] as String? ?? '',
      cardNumber: map['cardNumber'] as String? ?? '',
      expiry: map['expiry'] as String? ?? '',
      cvv: map['cvv'] as String? ?? '',
      network: map['network'] as String? ?? 'Visa',
      cardTheme: map['cardTheme'] as String? ?? 'standard',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isDeleted: map['isDeleted'] as bool? ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory WalletCardEntry.fromJson(String source) =>
      WalletCardEntry.fromMap(json.decode(source) as Map<String, dynamic>);
}
