import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/features/sync/domain/sync_protocol_models.dart';
import 'package:vaultx/features/sync/presentation/providers/sync_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Screen for device-to-device synchronization pairing (§6.2).
///
/// Implements:
/// - Host mode with QR rendezvous code generation.
/// - Client mode with QR camera scanner and manual address entry fallback.
/// - Cryptographic 6-digit safety number confirmation card (§6.2.4).
/// - Progress and merge completion report.
class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _manualAddressController = TextEditingController();
  bool _isScannerActive = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        if (_tabController.index == 0) {
          // Switch to Host Mode
          ref.read(syncOrchestratorProvider.notifier).startHostMode(deviceName: 'VaultX Device');
        } else {
          // Switch to Receive / Scan Mode
          ref.read(syncOrchestratorProvider.notifier).cancel();
        }
      }
    });

    // Default start in host mode if currently idle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(syncOrchestratorProvider).status == SyncStatus.idle) {
        ref.read(syncOrchestratorProvider.notifier).startHostMode(deviceName: 'VaultX Device');
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _manualAddressController.dispose();
    super.dispose();
  }

  void _onQrDetected(BarcodeCapture capture) {
    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        try {
          final payload = SyncRendezvousPayload.fromJsonString(barcode.rawValue!);
          HapticFeedback.mediumImpact();
          setState(() => _isScannerActive = false);
          ref.read(syncOrchestratorProvider.notifier).startClientMode(
                rendezvous: payload,
                deviceName: 'VaultX Client',
              );
          break;
        } catch (_) {
          // Not a valid VaultX rendezvous payload
        }
      }
    }
  }

  void _submitManualAddress() {
    final text = _manualAddressController.text.trim();
    if (text.isEmpty) return;

    try {
      SyncRendezvousPayload payload;
      if (text.startsWith('{')) {
        payload = SyncRendezvousPayload.fromJsonString(text);
      } else {
        // Assume format: "192.168.1.50:45678" or "192.168.1.50:45678#sessionId"
        final parts = text.split(':');
        final ip = parts[0];
        final portAndSid = parts.length > 1 ? parts[1].split('#') : ['45678'];
        final port = int.tryParse(portAndSid[0]) ?? 45678;
        final sid = portAndSid.length > 1 ? portAndSid[1] : 'manual-session';

        payload = SyncRendezvousPayload(
          sessionId: sid,
          deviceName: 'Manual Peer',
          ipAddresses: [ip],
          port: port,
        );
      }

      ref.read(syncOrchestratorProvider.notifier).startClientMode(
            rendezvous: payload,
            deviceName: 'VaultX Client',
          );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid rendezvous format: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final syncState = ref.watch(syncOrchestratorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Device Sync',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () {
              ref.read(syncOrchestratorProvider.notifier).cancel();
              Navigator.of(context).pop();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryBlue,
          labelColor: AppColors.primaryBlue,
          unselectedLabelColor: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_rounded), text: 'Share Vault'),
            Tab(icon: Icon(Icons.qr_code_scanner_rounded), text: 'Join / Receive'),
          ],
        ),
      ),
      body: SafeArea(
        child: syncState.status == SyncStatus.codeVerification
            ? _buildCodeVerificationView(syncState, cardBg, borderCol, isDark)
            : syncState.status == SyncStatus.syncing
                ? _buildSyncingView(cardBg)
                : syncState.status == SyncStatus.completed
                    ? _buildCompletedView(syncState, cardBg, isDark)
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildHostTabView(syncState, cardBg, borderCol, isDark),
                          _buildClientTabView(cardBg, borderCol, isDark),
                        ],
                      ),
      ),
    );
  }

  Widget _buildHostTabView(
    SyncOrchestrationState syncState,
    Color cardBg,
    Color borderCol,
    bool isDark,
  ) {
    final rendezvous = syncState.rendezvous;
    final qrData = rendezvous?.toJsonString() ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          const Text(
            'Scan to Pair',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Point the other device\'s camera at this QR code to establish an encrypted direct LAN session.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 24),

          // QR Code Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 60 : 15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: qrData.isNotEmpty
                ? QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 220,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF0F172A),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF0F172A),
                    ),
                  )
                : const SizedBox(
                    width: 220,
                    height: 220,
                    child: Center(child: CircularProgressIndicator()),
                  ),
          ),
          const SizedBox(height: 24),

          // Listening status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.emerald500.withAlpha(25),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.emerald500.withAlpha(60)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.emerald500,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  rendezvous != null
                      ? 'Listening on ${rendezvous.ipAddresses.firstOrNull ?? "127.0.0.1"}:${rendezvous.port}'
                      : 'Starting local listener...',
                  style: const TextStyle(
                    color: AppColors.emerald400,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientTabView(Color cardBg, Color borderCol, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          const Text(
            'Scan Host QR Code',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Align the QR code shown on the offering device within the frame.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 20),

          // Camera Scanner Box
          Container(
            height: 240,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderCol),
            ),
            child: _isScannerActive
                ? MobileScanner(
                    onDetect: _onQrDetected,
                    errorBuilder: (context, error) {
                      return Center(
                        child: Text(
                          'Camera unavailable in this environment.\nUse manual entry below.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      );
                    },
                  )
                : const Center(
                    child: CircularProgressIndicator(),
                  ),
          ),
          const SizedBox(height: 24),

          // Manual Address Entry Fallback
          TextField(
            controller: _manualAddressController,
            decoration: InputDecoration(
              hintText: 'Or enter IP:Port (e.g. 192.168.1.50:45678)',
              prefixIcon: const Icon(Icons.lan_rounded, size: 20),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward_rounded),
                onPressed: _submitManualAddress,
              ),
              filled: true,
              fillColor: isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderCol),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeVerificationView(
    SyncOrchestrationState syncState,
    Color cardBg,
    Color borderCol,
    bool isDark,
  ) {
    final code = syncState.verificationCode ?? '------';
    final formattedCode = code.length == 6
        ? '${code.substring(0, 3)}  ${code.substring(3)}'
        : code;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: AppColors.primaryBlue,
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Verify Pairing Code',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                'Confirm this exact safety code appears on both device screens. This code was derived from ephemeral cryptographic keys (§6.2.4) to protect against MITM.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              // 6-Digit Code Display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 22),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderCol, width: 1.5),
                ),
                child: Text(
                  formattedCode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Confirm CTA
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  ref.read(syncOrchestratorProvider.notifier).confirmVerificationCode();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.check_rounded, size: 20),
                label: const Text(
                  'Codes Match — Trust & Sync',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),

              TextButton(
                onPressed: () {
                  ref.read(syncOrchestratorProvider.notifier).cancel();
                },
                child: const Text(
                  'Cancel (Code Mismatch)',
                  style: TextStyle(color: AppColors.rose400, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncingView(Color cardBg) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(strokeWidth: 3),
          SizedBox(height: 24),
          Text(
            'Transferring & Encrypting Vault Data...',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            'Authenticating AES-256-GCM transport frames',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedView(
    SyncOrchestrationState syncState,
    Color cardBg,
    bool isDark,
  ) {
    final report = syncState.mergeReport;
    final changes = report?.totalChangesApplied ?? 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.emerald500,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sync Completed!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              'Successfully merged $changes entries seamlessly without clobbering newer edits.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                ref.read(syncOrchestratorProvider.notifier).cancel();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              ),
              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
