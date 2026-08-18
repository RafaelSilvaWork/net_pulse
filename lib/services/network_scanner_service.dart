import 'dart:io';

class HostScanResult {
  final String ip;

  const HostScanResult({required this.ip});
}

class NetworkScannerService {
  /// Probe ports used to decide if a host is up. A host only needs to
  /// answer on one of these for it to be reported as reachable.
  static const List<int> defaultProbePorts = [80, 443, 22, 445];

  /// Sweeps `[subnetPrefix].startHost` through `[subnetPrefix].endHost`
  /// in parallel batches of [concurrency], invoking [onHostFound] only for
  /// hosts that actually answer a connection attempt — no host is ever
  /// reported as active without a real, successful probe. [onProgress]
  /// fires after every host is checked (found or not) so callers can show
  /// how much of the sweep is done.
  static Future<void> scanSubnet({
    required String subnetPrefix,
    required void Function(HostScanResult result) onHostFound,
    required bool Function() isCancelled,
    void Function(int completed, int total)? onProgress,
    int startHost = 1,
    int endHost = 254,
    List<int> probePorts = defaultProbePorts,
    Duration timeout = const Duration(milliseconds: 300),
    int concurrency = 32,
  }) async {
    final total = endHost - startHost + 1;
    var completed = 0;
    for (var base = startHost; base <= endHost; base += concurrency) {
      if (isCancelled()) return;
      final batchEnd = (base + concurrency - 1).clamp(startHost, endHost);
      final hosts = [
        for (var i = base; i <= batchEnd; i++) '$subnetPrefix.$i',
      ];
      await Future.wait(hosts.map((ip) async {
        final reachable = await _isHostReachable(ip, probePorts, timeout);
        completed++;
        if (isCancelled()) return;
        onProgress?.call(completed, total);
        if (reachable) {
          onHostFound(HostScanResult(ip: ip));
        }
      }));
    }
  }

  static Future<bool> _isHostReachable(
    String ip,
    List<int> ports,
    Duration timeout,
  ) async {
    for (final port in ports) {
      try {
        final socket = await Socket.connect(ip, port, timeout: timeout);
        socket.destroy();
        return true;
      } catch (_) {
        // Try the next probe port before giving up on this host.
      }
    }
    return false;
  }

  /// Best-effort reverse DNS lookup for a host's name (e.g. the hostname a
  /// router registers for its DHCP clients). Not every router publishes
  /// this, so a null result — just no name available — is expected and
  /// callers should fall back to showing the IP.
  static Future<String?> resolveHostname(
    String ip, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    try {
      final result = await InternetAddress(ip).reverse().timeout(timeout);
      if (result.host.isNotEmpty && result.host != ip) {
        return result.host;
      }
    } catch (_) {
      // No PTR record / name available for this IP.
    }
    return null;
  }
}
