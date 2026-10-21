import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vaultx/features/sync/data/lan_discovery_service.dart';
import 'package:vaultx/features/sync/data/sync_client.dart';
import 'package:vaultx/features/sync/data/sync_server.dart';
import 'package:vaultx/features/sync/domain/sync_protocol_models.dart';
import 'package:vaultx/features/sync/domain/vault_merge_engine.dart';
import 'package:vaultx/features/vault/presentation/providers/vault_passwords_provider.dart';
import 'package:vaultx/features/wallet/presentation/providers/wallet_cards_provider.dart';

enum SyncRole { none, host, client }

enum SyncStatus {
  idle,
  hosting,
  connecting,
  codeVerification,
  syncing,
  completed,
  error,
}

class SyncOrchestrationState {
  final SyncRole role;
  final SyncStatus status;
  final SyncRendezvousPayload? rendezvous;
  final String? verificationCode;
  final VaultMergeReport? mergeReport;
  final String? errorMessage;

  const SyncOrchestrationState({
    this.role = SyncRole.none,
    this.status = SyncStatus.idle,
    this.rendezvous,
    this.verificationCode,
    this.mergeReport,
    this.errorMessage,
  });

  SyncOrchestrationState copyWith({
    SyncRole? role,
    SyncStatus? status,
    SyncRendezvousPayload? rendezvous,
    String? verificationCode,
    VaultMergeReport? mergeReport,
    String? errorMessage,
  }) {
    return SyncOrchestrationState(
      role: role ?? this.role,
      status: status ?? this.status,
      rendezvous: rendezvous ?? this.rendezvous,
      verificationCode: verificationCode ?? this.verificationCode,
      mergeReport: mergeReport ?? this.mergeReport,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class SyncOrchestratorNotifier extends StateNotifier<SyncOrchestrationState> {
  final Ref _ref;
  final VaultMergeEngine _mergeEngine = VaultMergeEngine();
  final LanDiscoveryService _lanDiscovery = LanDiscoveryService();

  SyncServer? _server;
  SyncClient? _client;

  SyncOrchestratorNotifier(this._ref) : super(const SyncOrchestrationState());

  /// Starts Host / Share Mode: Binds local WebSocket, advertises mDNS, and generates QR rendezvous.
  Future<void> startHostMode({String deviceName = 'VaultX Device'}) async {
    try {
      await cancel();

      const relayUrl = 'wss://relay.vaultx.org:443';
      _server = SyncServer(deviceName: deviceName);
      final port = await _server!.start();
      final localIps = await LanDiscoveryService.getLocalIpAddresses();

      final rendezvous = SyncRendezvousPayload(
        sessionId: _server!.sessionId!,
        deviceName: deviceName,
        ipAddresses: localIps,
        port: port,
        relayUrl: relayUrl,
      );

      state = state.copyWith(
        role: SyncRole.host,
        status: SyncStatus.hosting,
        rendezvous: rendezvous,
      );

      // Start mDNS advertisement
      await _lanDiscovery.startAdvertising(
        deviceName: deviceName,
        port: port,
      );

      // Listen to server status
      _server!.stateStream.listen((serverState) {
        if (serverState == SyncServerState.codeVerification) {
          state = state.copyWith(
            status: SyncStatus.codeVerification,
            verificationCode: _server!.verificationCode,
          );
        } else if (serverState == SyncServerState.error || serverState == SyncServerState.expired) {
          state = state.copyWith(
            status: SyncStatus.error,
            errorMessage: serverState == SyncServerState.expired
                ? 'Pairing session timed out (60s hygiene limit).'
                : 'Connection handshake error.',
          );
        }
      });
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: 'Failed to start host server: $e',
      );
    }
  }

  /// Starts Client / Receive Mode: Connects to peer host via scanned rendezvous info.
  Future<void> startClientMode({
    required SyncRendezvousPayload rendezvous,
    String deviceName = 'VaultX Client',
  }) async {
    try {
      await cancel();

      _client = SyncClient(deviceName: deviceName);
      state = state.copyWith(
        role: SyncRole.client,
        status: SyncStatus.connecting,
        rendezvous: rendezvous,
      );

      _client!.stateStream.listen((clientState) {
        if (clientState == SyncClientState.codeVerification) {
          state = state.copyWith(
            status: SyncStatus.codeVerification,
            verificationCode: _client!.verificationCode,
          );
        } else if (clientState == SyncClientState.error || clientState == SyncClientState.expired) {
          state = state.copyWith(
            status: SyncStatus.error,
            errorMessage: clientState == SyncClientState.expired
                ? 'Pairing session timed out (60s hygiene limit).'
                : 'Sync connection failed.',
          );
        }
      });

      await _client!.connect(rendezvous);
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: 'Could not connect to peer: $e',
      );
    }
  }

  /// Confirms that the displayed 6-digit verification code matches on both devices.
  Future<void> confirmVerificationCode() async {
    try {
      state = state.copyWith(status: SyncStatus.syncing);

      final localPasswords = _ref.read(vaultPasswordsProvider).allEntries;
      final localCards = _ref.read(walletCardsProvider).allCards;

      final outgoingBundle = SyncVaultBundle(
        passwords: localPasswords,
        cards: localCards,
        exportedAtTimestamp: DateTime.now().millisecondsSinceEpoch,
        sourceDeviceId: state.rendezvous?.sessionId ?? 'local',
      );

      SyncVaultBundle incomingBundle;
      if (state.role == SyncRole.host && _server != null) {
        await _server!.confirmVerificationCode();
        incomingBundle = await _server!.exchangeVaultBundle(outgoingBundle);
      } else if (state.role == SyncRole.client && _client != null) {
        await _client!.confirmVerificationCode();
        incomingBundle = await _client!.exchangeVaultBundle(outgoingBundle);
      } else {
        throw StateError('Cannot sync without an active host or client session.');
      }

      // Execute LWW merge
      final mergeReport = _mergeEngine.merge(
        localPasswords: localPasswords,
        incomingPasswords: incomingBundle.passwords,
        localCards: localCards,
        incomingCards: incomingBundle.cards,
      );

      // Persist merged entries into StateNotifiers in batch
      _ref.read(vaultPasswordsProvider.notifier).saveAll(mergeReport.mergedPasswords);
      _ref.read(walletCardsProvider.notifier).saveAll(mergeReport.mergedCards);

      state = state.copyWith(
        status: SyncStatus.completed,
        mergeReport: mergeReport,
      );
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: 'Vault synchronization failed: $e',
      );
    }
  }

  /// Cancels any active session, stops network servers, and resets state.
  Future<void> cancel() async {
    await _lanDiscovery.stopAdvertising();
    await _lanDiscovery.stopDiscovery();
    await _server?.stop();
    await _client?.disconnect();
    _server = null;
    _client = null;
    if (mounted) {
      state = const SyncOrchestrationState();
    }
  }

  @override
  void dispose() {
    _server?.stop();
    _client?.disconnect();
    _lanDiscovery.dispose();
    super.dispose();
  }
}

final syncOrchestratorProvider =
    StateNotifierProvider<SyncOrchestratorNotifier, SyncOrchestrationState>((ref) {
  return SyncOrchestratorNotifier(ref);
});
