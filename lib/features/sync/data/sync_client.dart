import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:vaultx/features/sync/domain/sync_crypto_service.dart';
import 'package:vaultx/features/sync/domain/sync_protocol_models.dart';

enum SyncClientState {
  idle,
  connecting,
  connected,
  codeVerification,
  syncing,
  completed,
  error,
  expired,
}

/// Client connecting to a peer host either over direct LAN WebSocket or fallback relay (§6.2).
class SyncClient {
  final SyncCryptoService _cryptoService;
  final String deviceName;

  WebSocket? _socket;
  Timer? _sessionExpiryTimer;

  SimpleKeyPair? _ephemeralKeyPair;
  SecretKey? _sessionKey;
  String? _verificationCode;

  final _stateController = StreamController<SyncClientState>.broadcast();
  SyncClientState _currentState = SyncClientState.idle;

  Completer<SyncVaultBundle> _incomingBundleCompleter = Completer<SyncVaultBundle>();
  final Completer<bool> _handshakeCompleteCompleter = Completer<bool>();
  Completer<bool> _localUserConfirmation = Completer<bool>();
  Completer<bool> _remoteUserConfirmation = Completer<bool>();

  SyncClient({
    required this.deviceName,
    SyncCryptoService? cryptoService,
  }) : _cryptoService = cryptoService ?? SyncCryptoService();

  Stream<SyncClientState> get stateStream => _stateController.stream;
  SyncClientState get state => _currentState;
  String? get verificationCode => _verificationCode;

  void _setState(SyncClientState s) {
    _currentState = s;
    if (!_stateController.isClosed) {
      _stateController.add(s);
    }
  }

  /// Connects to the host using rendezvous information.
  ///
  /// Tries direct LAN addresses first; if unreachable, falls back to relay URL if provided.
  Future<void> connect(SyncRendezvousPayload rendezvous) async {
    _setState(SyncClientState.connecting);

    // 60-second session hygiene timer per §6.2.7
    _sessionExpiryTimer = Timer(const Duration(seconds: 60), () {
      if (_currentState != SyncClientState.completed) {
        _setState(SyncClientState.expired);
        disconnect();
      }
    });

    _ephemeralKeyPair = await _cryptoService.generateEphemeralKeyPair();

    // Try direct LAN addresses
    bool connected = false;
    for (final ip in rendezvous.ipAddresses) {
      try {
        final uri = Uri.parse('ws://$ip:${rendezvous.port}');
        _socket = await WebSocket.connect(uri.toString()).timeout(const Duration(seconds: 3));
        connected = true;
        break;
      } catch (_) {
        // Try next IP
      }
    }

    // Fallback: If direct LAN fails and relayUrl is provided, connect to WSS relay
    if (!connected && rendezvous.relayUrl != null) {
      try {
        final relayUri = Uri.parse('${rendezvous.relayUrl}/session/${rendezvous.sessionId}');
        _socket = await WebSocket.connect(relayUri.toString()).timeout(const Duration(seconds: 5));
        connected = true;
      } catch (_) {}
    }

    if (!connected || _socket == null) {
      _setState(SyncClientState.error);
      throw const SocketException('Failed to connect to host across both direct LAN and relay endpoints.');
    }

    _setState(SyncClientState.connected);
    _listenToSocket(rendezvous.sessionId);
    await _handshakeCompleteCompleter.future;
  }

  void _listenToSocket(String sessionId) async {
    try {
      final clientPubKeyBytes = await _cryptoService.extractPublicKeyBytes(_ephemeralKeyPair!);

      await for (final rawMsg in _socket!) {
        final rawStr = rawMsg.toString();

        if (_sessionKey == null) {
          // Handshake phase: Host sent HandshakeInitMessage
          final hostInit = HandshakeInitMessage.fromJsonString(rawStr);
          final hostPubKeyBytes = base64Decode(hostInit.publicKeyBase64);

          // Send client HandshakeInitMessage back to host
          final clientInit = HandshakeInitMessage(
            sessionId: sessionId,
            publicKeyBase64: base64Encode(clientPubKeyBytes),
            deviceName: deviceName,
          );
          _socket!.add(clientInit.toJsonString());

          // Derive shared secret via ECDH
          final sharedSecret = await _cryptoService.deriveSharedSecret(
            localKeyPair: _ephemeralKeyPair!,
            remotePublicKeyBytes: hostPubKeyBytes,
          );

          // Derive 6-digit verification code (§6.2.4)
          _verificationCode = await _cryptoService.deriveVerificationCode(
            localPublicKeyBytes: clientPubKeyBytes,
            remotePublicKeyBytes: hostPubKeyBytes,
            sharedSecret: sharedSecret,
          );

          // Derive symmetric AES-256-GCM session key
          _sessionKey = await _cryptoService.deriveSessionKey(
            localPublicKeyBytes: clientPubKeyBytes,
            remotePublicKeyBytes: hostPubKeyBytes,
            sharedSecret: sharedSecret,
          );

          _setState(SyncClientState.codeVerification);
          if (!_handshakeCompleteCompleter.isCompleted) {
            _handshakeCompleteCompleter.complete(true);
          }
        } else {
          // Encrypted transport frame phase
          final frame = SyncTransportFrame.fromJsonString(rawStr);
          final record = frame.toEncryptedRecord();
          final decryptedJson = await _cryptoService.decryptMessage(
            record: record,
            sessionKey: _sessionKey!,
          );

          if (frame.messageType == 'confirm') {
            if (!_remoteUserConfirmation.isCompleted) {
              _remoteUserConfirmation.complete(true);
            }
          } else if (frame.messageType == 'data') {
            final bundle = SyncVaultBundle.fromJsonString(decryptedJson);
            if (!_incomingBundleCompleter.isCompleted) {
              _incomingBundleCompleter.complete(bundle);
            }
          }
        }
      }
    } catch (e) {
      _setState(SyncClientState.error);
    }
  }

  /// Called when the client user confirms that the displayed 6-digit code matches.
  Future<void> confirmVerificationCode() async {
    if (_currentState != SyncClientState.codeVerification || _sessionKey == null) return;
    if (!_localUserConfirmation.isCompleted) {
      _localUserConfirmation.complete(true);
    }

    // Send encrypted confirmation frame
    final record = await _cryptoService.encryptMessage(
      cleartextJson: jsonEncode({'confirmed': true}),
      sessionKey: _sessionKey!,
    );
    final frame = SyncTransportFrame.fromEncryptedRecord(
      messageType: 'confirm',
      record: record,
    );
    _socket?.add(frame.toJsonString());
  }

  /// Exchanges vault bundle with host over authenticated encrypted channel.
  Future<SyncVaultBundle> exchangeVaultBundle(SyncVaultBundle outgoingBundle) async {
    _setState(SyncClientState.syncing);

    // Ensure both parties have confirmed the verification code (§6.2.5)
    await Future.wait([
      _localUserConfirmation.future,
      _remoteUserConfirmation.future,
    ]).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('Pairing verification code confirmation timed out.'),
    );

    // Send encrypted vault bundle
    final record = await _cryptoService.encryptMessage(
      cleartextJson: outgoingBundle.toJsonString(),
      sessionKey: _sessionKey!,
    );
    final frame = SyncTransportFrame.fromEncryptedRecord(
      messageType: 'data',
      record: record,
    );
    _socket?.add(frame.toJsonString());

    // Await host bundle
    final incomingBundle = await _incomingBundleCompleter.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('Remote vault bundle transfer timed out.'),
    );

    _setState(SyncClientState.completed);
    return incomingBundle;
  }

  Future<void> disconnect() async {
    _sessionExpiryTimer?.cancel();
    _sessionExpiryTimer = null;
    await _socket?.close();
    _socket = null;
    _ephemeralKeyPair = null;
    _sessionKey = null;
    _verificationCode = null;
    _localUserConfirmation = Completer<bool>();
    _remoteUserConfirmation = Completer<bool>();
    _incomingBundleCompleter = Completer<SyncVaultBundle>();
  }

  void dispose() {
    disconnect();
    _stateController.close();
  }
}
