import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultx/core/services/clipboard_security_service.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/widgets/gliding_category_bar.dart';
import 'package:vaultx/core/widgets/physical_card_widget.dart';
import 'package:vaultx/features/wallet/domain/wallet_card_entry.dart';
import 'package:vaultx/features/wallet/presentation/providers/wallet_cards_provider.dart';
import 'package:vaultx/features/wallet/presentation/add_card_screen.dart';

/// Screen 6: Digital Wallet Screen
///
/// Displays physical realistic payment cards with EMV chip, network filter pills,
/// search, card unmasking, inspection details sheet, and add card action.
class DigitalWalletScreen extends ConsumerStatefulWidget {
  const DigitalWalletScreen({super.key});

  @override
  ConsumerState<DigitalWalletScreen> createState() => _DigitalWalletScreenState();
}

class _DigitalWalletScreenState extends ConsumerState<DigitalWalletScreen> {
  final _searchController = TextEditingController();

  static const List<String> _networks = [
    'All',
    'Visa',
    'Mastercard',
    'Amex',
    'Plexee',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToAddCard({
    String? initialTitle,
    String? initialNumber,
    String? initialExpiry,
    String? initialHolder,
    String? initialNetwork,
  }) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddCardScreen(
          initialTitle: initialTitle,
          initialNumber: initialNumber,
          initialExpiry: initialExpiry,
          initialHolder: initialHolder,
          initialNetwork: initialNetwork,
        ),
      ),
    );
  }

  void _showCardDetails(WalletCardEntry card) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CardDetailsSheet(card: card),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final walletState = ref.watch(walletCardsProvider);
    final cards = walletState.filteredCards;

    final inputBg = isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            CustomScrollView(
              physics: cards.isEmpty
                  ? const NeverScrollableScrollPhysics()
                  : const AlwaysScrollableScrollPhysics(),
              slivers: [
            // Top Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Wallet',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    IconButton.filled(
                      onPressed: () => _navigateToAddCard(),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 22),
                      tooltip: 'Add Card',
                    ),
                  ],
                ),
              ),
            ),

            // Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    ref.read(walletCardsProvider.notifier).setSearchQuery(val);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search cards...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(walletCardsProvider.notifier).setSearchQuery('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderCol),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderCol),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),

            // Network Filters (Apple HIG & OriginOS Gliding Magnetic Bar)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: GlidingCategoryBar(
                  items: _networks.map((network) {
                    final isAll = network.toLowerCase() == 'all';
                    final int count = isAll
                        ? walletState.activeCards.length
                        : walletState.activeCards
                            .where((c) => c.network.toLowerCase() == network.toLowerCase())
                            .length;

                    return GlidingCategoryItem(
                      id: network,
                      label: network,
                      count: count > 0 ? count : null,
                    );
                  }).toList(),
                  selectedId: walletState.selectedNetwork,
                  onSelected: (network) {
                    ref.read(walletCardsProvider.notifier).setSelectedNetwork(network);
                  },
                ),
              ),
            ),

            if (cards.isNotEmpty) ...[
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  110 + MediaQuery.of(context).viewInsets.bottom,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final card = cards[index];
                      return PhysicalCardWidget(
                        card: card,
                        onTap: () => _showCardDetails(card),
                      );
                    },
                    childCount: cards.length,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (cards.isEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.credit_card_off_rounded,
                      size: 48,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No cards found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  ),
);
  }
}

class _CardDetailsSheet extends StatelessWidget {
  final WalletCardEntry card;

  const _CardDetailsSheet({required this.card});

  void _copyToClipboard(BuildContext context, String text, String label) {
    HapticFeedback.lightImpact();
    ClipboardSecurityService.copySecure(
      context: context,
      ref: null,
      text: text,
      label: label,
      isSensitive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final inputBg = isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Consumer(
      builder: (context, ref, _) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: borderCol, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    card.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      card.network,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Inset Grouped Card Information
              Container(
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderCol),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card Number Row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Card Number',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  card.formattedNumber,
                                  style: const TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            tooltip: 'Copy card number',
                            onPressed: () => _copyToClipboard(context, card.cardNumber, 'Card number'),
                          ),
                        ],
                      ),
                    ),

                    // Cardholder Name Row (if provided)
                    if (card.cardholderName.isNotEmpty) ...[
                      Divider(height: 1, indent: 16, endIndent: 16, color: borderCol.withAlpha(80)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cardholder Name',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    card.cardholderName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              tooltip: 'Copy cardholder name',
                              onPressed: () => _copyToClipboard(context, card.cardholderName, 'Cardholder'),
                            ),
                          ],
                        ),
                      ),
                    ],

                    Divider(height: 1, indent: 16, endIndent: 16, color: borderCol.withAlpha(80)),

                    // Expiry & CVV Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Expires',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  card.expiry,
                                  style: const TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 28,
                            color: borderCol.withAlpha(80),
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'CVV',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        card.cvv,
                                        style: const TextStyle(
                                          fontFamily: 'JetBrains Mono',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 18),
                                  tooltip: 'Copy CVV',
                                  onPressed: () => _copyToClipboard(context, card.cvv, 'CVV'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Delete Card
              Material(
                color: isDark
                    ? AppColors.rose950.withAlpha(80)
                    : AppColors.rose500.withAlpha(24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: AppColors.rose500.withAlpha(isDark ? 80 : 160),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: const Text(
                          'Delete Card?',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        content: Text(
                          'This will permanently remove "${card.title}" from your wallet.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.rose500,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              ref.read(walletCardsProvider.notifier).deleteCard(card.id);
                              HapticFeedback.heavyImpact();
                              Navigator.of(ctx).pop();
                              Navigator.of(context).pop();
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: isDark ? AppColors.rose400 : const Color(0xFFBE123C),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Delete Card',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.rose400 : const Color(0xFFBE123C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
