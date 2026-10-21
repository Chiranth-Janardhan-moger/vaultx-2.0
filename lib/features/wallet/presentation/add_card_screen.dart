import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/theme/happy_feedback.dart';
import 'package:vaultx/features/wallet/domain/wallet_card_entry.dart';
import 'package:vaultx/features/wallet/presentation/providers/wallet_cards_provider.dart';

/// Screen 7: Add Card Screen
///
/// Features network picker (Visa, Mastercard, Amex, Plexee), formatted card number input,
/// expiry/CVV fields, theme style picker, and offline encryption assurance banner.
class AddCardScreen extends ConsumerStatefulWidget {
  final String? initialTitle;
  final String? initialNumber;
  final String? initialExpiry;
  final String? initialHolder;
  final String? initialNetwork;

  const AddCardScreen({
    super.key,
    this.initialTitle,
    this.initialNumber,
    this.initialExpiry,
    this.initialHolder,
    this.initialNetwork,
  });

  @override
  ConsumerState<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends ConsumerState<AddCardScreen> {
  final _titleController = TextEditingController();
  final _holderController = TextEditingController();
  final _numberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  String _selectedNetwork = 'Visa';
  String _selectedTheme = 'chase_sapphire';
  bool _obscureCvv = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }
    if (widget.initialNumber != null && widget.initialNumber!.isNotEmpty) {
      _formatCardNumber(widget.initialNumber!);
    }
    if (widget.initialExpiry != null) {
      _expiryController.text = widget.initialExpiry!;
    }
    if (widget.initialHolder != null) {
      _holderController.text = widget.initialHolder!;
    }
    if (widget.initialNetwork != null && widget.initialNetwork!.isNotEmpty) {
      _selectedNetwork = widget.initialNetwork!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _holderController.dispose();
    _numberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  void _formatCardNumber(String value) {
    final clean = value.replaceAll(RegExp(r'\s+'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(clean[i]);
    }
    final formatted = buffer.toString();
    if (formatted != value) {
      _numberController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  void _save() {
    final title = _titleController.text.trim();
    final holder = _holderController.text.trim();
    final number = _numberController.text.replaceAll(RegExp(r'\s+'), '');
    final expiry = _expiryController.text.trim();
    final cvv = _cvvController.text.trim();

    if (title.isEmpty || number.isEmpty || expiry.isEmpty || cvv.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.rose500,
          content: Text('Please fill in all required card fields.'),
        ),
      );
      return;
    }

    final newCard = WalletCardEntry(
      id: 'card-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      cardholderName: holder.isNotEmpty ? holder : 'CARDHOLDER',
      cardNumber: number,
      expiry: expiry,
      cvv: cvv,
      network: _selectedNetwork,
      cardTheme: _selectedTheme,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    ref.read(walletCardsProvider.notifier).addCard(newCard);
    HappyFeedback.vibrate();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final inputBg = isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface;

    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text(
            'Cancel',
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: AppColors.primaryBlue,
              fontSize: 16,
            ),
          ),
        ),
        leadingWidth: 84,
        title: const Text(
          'Add Card',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'Save',
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: AppColors.primaryBlue,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Network Picker Section
              Text(
                'CARD NETWORK',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _NetworkChoice(
                    name: 'Visa',
                    isSelected: _selectedNetwork == 'Visa',
                    onTap: () => setState(() => _selectedNetwork = 'Visa'),
                  ),
                  const SizedBox(width: 8),
                  _NetworkChoice(
                    name: 'Mastercard',
                    isSelected: _selectedNetwork == 'Mastercard',
                    onTap: () => setState(() => _selectedNetwork = 'Mastercard'),
                  ),
                  const SizedBox(width: 8),
                  _NetworkChoice(
                    name: 'Amex',
                    isSelected: _selectedNetwork == 'Amex',
                    onTap: () => setState(() => _selectedNetwork = 'Amex'),
                  ),
                  const SizedBox(width: 8),
                  _NetworkChoice(
                    name: 'Plexee',
                    isSelected: _selectedNetwork == 'Plexee',
                    onTap: () => setState(() => _selectedNetwork = 'Plexee'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Card Identity & Details Group
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderCol),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Card Label',
                        hintText: 'e.g. Personal Chase Visa',
                        prefixIcon: Icon(Icons.credit_card_rounded, size: 20),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    Divider(height: 1, color: borderCol),
                    TextField(
                      controller: _holderController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Cardholder Name',
                        hintText: 'e.g. ALEX MORGAN',
                        prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    Divider(height: 1, color: borderCol),
                    TextField(
                      controller: _numberController,
                      keyboardType: TextInputType.number,
                      onChanged: _formatCardNumber,
                      style: const TextStyle(fontFamily: 'JetBrains Mono'),
                      decoration: InputDecoration(
                        labelText: 'Card Number',
                        hintText: '0000 0000 0000 0000',
                        prefixIcon: const Icon(Icons.pin_outlined, size: 20),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.paste_rounded, size: 18),
                          tooltip: 'Paste from clipboard',
                          onPressed: () async {
                            final data = await Clipboard.getData('text/plain');
                            if (data?.text != null) {
                              _formatCardNumber(data!.text!);
                            }
                          },
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    Divider(height: 1, color: borderCol),

                    // Expiry & CVV Row
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _expiryController,
                            keyboardType: TextInputType.datetime,
                            style: const TextStyle(fontFamily: 'JetBrains Mono'),
                            decoration: const InputDecoration(
                              labelText: 'Expiry Date',
                              hintText: 'MM/YY',
                              prefixIcon: Icon(Icons.date_range_rounded, size: 20),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                        ),
                        Container(width: 1, height: 48, color: borderCol),
                        Expanded(
                          child: TextField(
                            controller: _cvvController,
                            keyboardType: TextInputType.number,
                            obscureText: _obscureCvv,
                            style: const TextStyle(fontFamily: 'JetBrains Mono'),
                            decoration: InputDecoration(
                              labelText: 'CVV / CVC',
                              hintText: '123',
                              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureCvv ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  size: 18,
                                ),
                                onPressed: () => setState(() => _obscureCvv = !_obscureCvv),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Visual Theme Style Selector
              Text(
                'PHYSICAL CARD STYLE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _ThemeChoice(
                    label: 'Sapphire',
                    themeKey: 'chase_sapphire',
                    gradientColors: const [Color(0xFF0F1E4A), Color(0xFF1E3A8A)],
                    isSelected: _selectedTheme == 'chase_sapphire',
                    onTap: () => setState(() => _selectedTheme = 'chase_sapphire'),
                  ),
                  const SizedBox(width: 10),
                  _ThemeChoice(
                    label: 'Titanium',
                    themeKey: 'apple_titanium',
                    gradientColors: const [Color(0xFF282A36), Color(0xFF6272A4)],
                    isSelected: _selectedTheme == 'apple_titanium',
                    onTap: () => setState(() => _selectedTheme = 'apple_titanium'),
                  ),
                  const SizedBox(width: 10),
                  _ThemeChoice(
                    label: 'Sovereign',
                    themeKey: 'plexee_sovereign',
                    gradientColors: const [Color(0xFF2E190E), Color(0xFF9A5B23)],
                    isSelected: _selectedTheme == 'plexee_sovereign',
                    onTap: () => setState(() => _selectedTheme = 'plexee_sovereign'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 100% Offline Vault Notice
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderCol),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.offline_bolt_rounded,
                      color: AppColors.emerald500,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '100% Offline Vault. Card data and PIN are encrypted on-device with AES-256 and never transmitted over any network.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Save CTA Button
              ElevatedButton.icon(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'Save to Wallet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetworkChoice extends StatelessWidget {
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _NetworkChoice({
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryBlue.withAlpha(35) : cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.primaryBlue : borderCol,
              width: isSelected ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              color: isSelected
                  ? AppColors.primaryBlue
                  : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  final String label;
  final String themeKey;
  final List<Color> gradientColors;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeChoice({
    required this.label,
    required this.themeKey,
    required this.gradientColors,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: gradientColors.last.withAlpha(120),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
