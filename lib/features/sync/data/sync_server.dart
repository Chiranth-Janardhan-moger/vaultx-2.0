import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:vaultx/features/sync/domain/sync_crypto_service.dart';
import 'package:vaultx/features/sync/domain/sync_protocol_models.dart';

enum SyncServerState {
  idle,
  listening,
  clientConnected,
  codeVerification,
  syncing,
  completed,
  error,
  expired,
}

/// Local WebSocket server handling incoming pairing and sync sessions (§6.2.2).
class SyncServer {
  final SyncCryptoService _cryptoService;
  final String deviceName;

  HttpServer? _server;
  WebSocket? _socket;
  Timer? _sessionExpiryTimer;

  SimpleKeyPair? _ephemeralKeyPair;
  SecretKey? _sessionKey;
  String? _verificationCode;
  String? _sessionId;

  final _stateController = StreamController<SyncServerState>.broadcast();
  SyncServerState _currentState = SyncServerState.idle;

  SyncServer({
    required this.deviceName,
    SyncCryptoService? cryptoService,
  }) : _cryptoService = cryptoService ?? SyncCryptoService();

  Stream<SyncServerState> get stateStream => _stateController.stream;
  SyncServerState get state => _currentState;
  int? get boundPort => _server?.port;
  String? get verificationCode => _verificationCode;
  String? get sessionId => _sessionId;

  Completer<bool> _localUserConfirmation = Completer<bool>();
  Completer<bool> _remoteUserConfirmation = Completer<bool>();
  Completer<SyncVaultBundle> _incomingBundleCompleter = Completer<SyncVaultBundle>();

  void _setState(SyncServerState s) {
    _currentState = s;
    if (!_stateController.isClosed) {
      _stateController.add(s);
    }
  }

  /// Starts listening for an incoming peer connection on an available local port.
  Future<int> start({int port = 0}) async {
    await stop();

    _sessionId = 'sid-${DateTime.now().millisecondsSinceEpoch}';
    _ephemeralKeyPair = await _cryptoService.generateEphemeralKeyPair();

    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _setState(SyncServerState.listening);

    // 60-second session hygiene timer per §6.2.7
    _sessionExpiryTimer = Timer(const Duration(seconds: 60), () {
      if (_currentState != SyncServerState.completed) {
        _setState(SyncServerState.expired);
        stop();
      }
    });

    _server!.listen(_handleHttpRequest);
    return _server!.port;
  }

  void _handleHttpRequest(HttpRequest request) async {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      try {
        _socket = await WebSocketTransformer.upgrade(request);
        _setState(SyncServerState.clientConnected);
        _listenToSocket();
      } catch (e) {
        _setState(SyncServerState.error);
      }
    } else {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..write('WebSocket connections only');
      await request.response.close();
    }
  }

  void _listenToSocket() async {
    try {
      // Step 1: Send host HandshakeInitMessage with ephemeral public key
      final hostPubKeyBytes = await _cryptoService.extractPublicKeyBytes(_ephemeralKeyPair!);
      final initMsg = HandshakeInitMessage(
        sessionId: _sessionId!,
        publicKeyBase64: base64Encode(hostPubKeyBytes),
        deviceName: deviceName,
      );
      _socket!.add(initMsg.toJsonString());

      // Step 2: Receive client HandshakeInitMessage
      await for (final rawMsg in _socket!) {
        final rawStr = rawMsg.toString();

        if (_sessionKey == null) {
          // Handshake phase
          final clientInit = HandshakeInitMessage.fromJsonString(rawStr);
          final clientPubKeyBytes = base64Decode(clientInit.publicKeyBase64);

          // Derive shared secret via ECDH
          final sharedSecret = await _cryptoService.deriveSharedSecret(
            localKeyPair: _ephemeralKeyPair!,
            remotePublicKeyBytes: clientPubKeyBytes,
          );

          // Derive 6-digit verification code (§6.2.4)
          _verificationCode = await _cryptoService.deriveVerificationCode(
            localPublicKeyBytes: hostPubKeyBytes,
            remotePublicKeyBytes: clientPubKeyBytes,
            sharedSecret: sharedSecret,
          );

          // Derive symmetric AES-256-GCM session key
          _sessionKey = await _cryptoService.deriveSessionKey(
            localPublicKeyBytes: hostPubKeyBytes,
            remotePublicKeyBytes: clientPubKeyBytes,
            sharedSecret: sharedSecret,
          );

          _setState(SyncServerState.codeVerification);
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
      _setState(SyncServerState.error);
    }
  }

  /// Called when the local user confirms that the displayed 6-digit code matches.
  Future<void> confirmVerificationCode() async {
    if (_currentState != SyncServerState.codeVerification || _sessionKey == null) return;
    if (!_localUserConfirmation.isCompleted) {
      _localUserConfirmation.complete(true);
    }

    // Send encrypted confirmation frame to client
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

  /// Sends local vault data (encrypted) and awaits incoming remote vault bundle.
  Future<SyncVaultBundle> exchangeVaultBundle(SyncVaultBundle outgoingBundle) async {
    _setState(SyncServerState.syncing);

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

    // Wait for client vault bundle
    final incomingBundle = await _incomingBundleCompleter.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('Remote vault bundle transfer timed out.'),
    );

    _setState(SyncServerState.completed);
    return incomingBundle;
  }

  /// Stops server, terminates socket, and clears ephemeral keys.
  Future<void> stop() async {
    _sessionExpiryTimer?.cancel();
    _sessionExpiryTimer = null;
    await _socket?.close();
    _socket = null;
    await _server?.close(force: true);
    _server = null;
    _ephemeralKeyPair = null;
    _sessionKey = null;
    _verificationCode = null;
    _localUserConfirmation = Completer<bool>();
    _remoteUserConfirmation = Completer<bool>();
    _incomingBundleCompleter = Completer<SyncVaultBundle>();
  }

  void dispose() {
    stop();
    _stateController.close();
  }
}
