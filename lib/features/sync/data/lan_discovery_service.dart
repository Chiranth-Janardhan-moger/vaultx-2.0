import 'dart:async';
import 'dart:io';
import 'package:bonsoir/bonsoir.dart';

/// Discovered peer on the local area network.
class DiscoveredPeer {
  final String id;
  final String name;
  final String host;
  final int port;

  const DiscoveredPeer({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
  });
}

/// Service handling mDNS LAN discovery and service advertisement per §6.2.1.
class LanDiscoveryService {
  static const String serviceType = '_vaultx-sync._tcp';

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _discoverySub;

  final _peersController = StreamController<List<DiscoveredPeer>>.broadcast();
  final Map<String, DiscoveredPeer> _discoveredPeers = {};

  Stream<List<DiscoveredPeer>> get discoveredPeersStream => _peersController.stream;
  List<DiscoveredPeer> get discoveredPeers => _discoveredPeers.values.toList();

  /// Retrieves non-loopback IPv4 network interface addresses on this device.
  static Future<List<String>> getLocalIpAddresses() async {
    final ips = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) {
            ips.add(addr.address);
          }
        }
      }
    } catch (_) {}
    if (ips.isEmpty) {
      ips.add('127.0.0.1');
    }
    return ips;
  }

  /// Advertises this device as an available sync host on the local network.
  Future<void> startAdvertising({
    required String deviceName,
    required int port,
    Map<String, String>? attributes,
  }) async {
    try {
      final service = BonsoirService(
        name: deviceName,
        type: serviceType,
        port: port,
        attributes: attributes ?? {},
      );

      _broadcast = BonsoirBroadcast(service: service);
      await _broadcast!.initialize();
      await _broadcast!.start();
    } catch (_) {
      // Graceful fallback on platforms without mDNS daemon (e.g. CI / restricted environments)
    }
  }

  /// Stops advertising this device.
  Future<void> stopAdvertising() async {
    try {
      await _broadcast?.stop();
    } catch (_) {}
    _broadcast = null;
  }

  /// Starts discovery browsing for nearby VaultX sync peers.
  Future<void> startDiscovery() async {
    try {
      _discoveredPeers.clear();
      _discovery = BonsoirDiscovery(type: serviceType);
      await _discovery!.initialize();

      _discoverySub = _discovery!.eventStream?.listen((event) {
        if (event is BonsoirDiscoveryServiceResolvedEvent) {
          final s = event.service;
          final host = s.hostAddress ?? s.hostname;
          if (host != null) {
            final peer = DiscoveredPeer(
              id: s.name,
              name: s.name,
              host: host,
              port: s.port,
            );
            _discoveredPeers[peer.id] = peer;
            _peersController.add(_discoveredPeers.values.toList());
          }
        } else if (event is BonsoirDiscoveryServiceLostEvent) {
          final s = event.service;
          _discoveredPeers.remove(s.name);
          _peersController.add(_discoveredPeers.values.toList());
        }
      });

      await _discovery!.start();
    } catch (_) {
      // Graceful fallback for restricted network environments
    }
  }

  /// Stops browsing for peers.
  Future<void> stopDiscovery() async {
    await _discoverySub?.cancel();
    _discoverySub = null;
    try {
      await _discovery?.stop();
    } catch (_) {}
    _discovery = null;
    _discoveredPeers.clear();
  }

  void dispose() {
    stopAdvertising();
    stopDiscovery();
    _peersController.close();
  }
}
