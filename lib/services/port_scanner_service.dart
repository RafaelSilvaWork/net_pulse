import 'dart:io';

class PortScanResult {
  final int port;
  final String service;
  final bool isOpen;

  const PortScanResult({
    required this.port,
    required this.service,
    required this.isOpen,
  });
}

class PortScannerService {
  static const Map<int, String> commonPorts = {
    21: 'FTP',
    22: 'SSH',
    23: 'Telnet',
    25: 'SMTP',
    53: 'DNS',
    80: 'HTTP',
    443: 'HTTPS',
    3306: 'MySQL',
    3389: 'RDP',
    8080: 'HTTP-Proxy',
  };

  /// Default cap applied by [parsePorts] so a typo like "1-65535" can't turn
  /// into an unbounded scan.
  static const int maxParsedPorts = 500;

  /// Parses a user-entered port list such as `"22,80,443"` or a mix with
  /// ranges like `"20-25,80,8000-8010"` into a port -> service-name map,
  /// reusing [commonPorts] names where known. Invalid tokens are skipped.
  /// The result is capped at [maxPorts] ports (ascending) to keep a typo'd
  /// range from triggering a huge scan.
  static Map<int, String> parsePorts(
    String input, {
    int maxPorts = maxParsedPorts,
  }) {
    final ports = <int>{};
    for (final rawToken in input.split(',')) {
      final token = rawToken.trim();
      if (token.isEmpty) continue;
      if (token.contains('-')) {
        final bounds = token.split('-');
        if (bounds.length != 2) continue;
        final a = int.tryParse(bounds[0].trim());
        final b = int.tryParse(bounds[1].trim());
        if (a == null || b == null) continue;
        final lo = a < b ? a : b;
        final hi = a < b ? b : a;
        for (var port = lo; port <= hi; port++) {
          if (port >= 1 && port <= 65535) ports.add(port);
        }
      } else {
        final port = int.tryParse(token);
        if (port != null && port >= 1 && port <= 65535) ports.add(port);
      }
    }
    final sorted = ports.toList()..sort();
    return {
      for (final port in sorted.take(maxPorts))
        port: commonPorts[port] ?? 'Customizada',
    };
  }

  /// Scans [ports] on [host] in parallel batches of [concurrency], invoking
  /// [onResult] as each result arrives. Checks [isCancelled] between batches
  /// and before delivering a result, so a cancelled scan stops promptly.
  static Future<void> scan({
    required String host,
    required void Function(PortScanResult result) onResult,
    required bool Function() isCancelled,
    Map<int, String> ports = commonPorts,
    Duration timeout = const Duration(milliseconds: 500),
    int concurrency = 10,
  }) async {
    final entries = ports.entries.toList();
    for (var i = 0; i < entries.length; i += concurrency) {
      if (isCancelled()) return;
      final batch = entries.skip(i).take(concurrency);
      await Future.wait(
        batch.map((entry) async {
          final isOpen = await _isPortOpen(host, entry.key, timeout);
          if (!isCancelled()) {
            onResult(
              PortScanResult(
                port: entry.key,
                service: entry.value,
                isOpen: isOpen,
              ),
            );
          }
        }),
      );
    }
  }

  static Future<bool> _isPortOpen(
    String host,
    int port,
    Duration timeout,
  ) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}
