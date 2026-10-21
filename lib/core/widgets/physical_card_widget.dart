import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vaultx/features/wallet/domain/wallet_card_entry.dart';

/// Renders a realistic physical payment card with tactile gradients,
/// golden EMV microchip, contactless wave icon, and masked credentials.
class PhysicalCardWidget extends StatefulWidget {
  final WalletCardEntry card;
  final VoidCallback? onTap;

  const PhysicalCardWidget({
    super.key,
    required this.card,
    this.onTap,
  });

  @override
  State<PhysicalCardWidget> createState() => _PhysicalCardWidgetState();
}

class _PhysicalCardWidgetState extends State<PhysicalCardWidget> {
  bool _isUnmasked = false;

  LinearGradient _getCardGradient() {
    switch (widget.card.cardTheme.toLowerCase()) {
      case 'chase_sapphire':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF070E26),
            Color(0xFF0F1E4A),
            Color(0xFF1E3A8A),
          ],
        );
      case 'apple_titanium':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF282A36),
            Color(0xFF44475A),
            Color(0xFF6272A4),
          ],
        );
      case 'plexee_sovereign':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2E190E),
            Color(0xFF663B18),
            Color(0xFF9A5B23),
          ],
        );
      default:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF191C1E),
            Color(0xFF272A2C),
            Color(0xFF33383B),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.586, // Standard ISO/IEC 7810 ID-1 card ratio
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: _getCardGradient(),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withAlpha(40),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(100),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Radial highlight for metallic sheen
              Positioned(
                top: -30,
                left: -30,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withAlpha(35),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Row: Network & Card Title + Contactless Icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.card.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.contactless_rounded,
                              color: Colors.white70,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            _NetworkBadge(network: widget.card.network),
                          ],
                        ),
                      ],
                    ),

                    // Middle Row: Realistic Golden EMV Chip
                    Row(
                      children: [
                        const _EmvChipWidget(),
                        const SizedBox(width: 12),
                        IconButton(
                          iconSize: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                          tooltip: _isUnmasked ? 'Mask card number' : 'Reveal card number',
                          icon: Icon(
                            _isUnmasked
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: Colors.white70,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _isUnmasked = !_isUnmasked;
                            });
                          },
                        ),
                      ],
                    ),

                    // Bottom: Number & Cardholder & Expiry
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isUnmasked
                              ? widget.card.formattedNumber
                              : widget.card.maskedNumber,
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              widget.card.cardholderName.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                                letterSpacing: 1.0,
                              ),
                            ),
                            Row(
                              children: [
                                const Text(
                                  'EXP ',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white54,
                                  ),
                                ),
                                Text(
                                  widget.card.expiry,
                                  style: const TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmvChipWidget extends StatelessWidget {
  const _EmvChipWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFFD4AF37), // Metallic Gold
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFFB8860B),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Inner microchip circuit lines
          Center(
            child: Container(
              width: 32,
              height: 20,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF996515), width: 0.8),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Positioned(
            left: 10,
            top: 0,
            bottom: 0,
            child: Container(width: 1, color: const Color(0xFF996515)),
          ),
          Positioned(
            right: 10,
            top: 0,
            bottom: 0,
            child: Container(width: 1, color: const Color(0xFF996515)),
          ),
        ],
      ),
    );
  }
}

class _NetworkBadge extends StatelessWidget {
  final String network;

  const _NetworkBadge({required this.network});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(40),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        network.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
