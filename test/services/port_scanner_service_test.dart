import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:net_pulse/services/port_scanner_service.dart';

void main() {
  group('PortScannerService.parsePorts', () {
    test('parses a comma separated list with known service names', () {
      final ports = PortScannerService.parsePorts('80,22,443');
      expect(ports.keys.toList(), [22, 80, 443]);
      expect(ports[22], 'SSH');
      expect(ports[80], 'HTTP');
    });

    test('parses ranges and labels unknown ports as Customizada', () {
      final ports = PortScannerService.parsePorts('8000-8002');
      expect(ports.keys.toList(), [8000, 8001, 8002]);
      expect(ports.values, everyElement('Customizada'));
    });

    test('deduplicates overlapping single ports and ranges', () {
      final ports = PortScannerService.parsePorts('80,80-81,81');
      expect(ports.keys.toList(), [80, 81]);
    });

    test('ignores invalid or out-of-range tokens', () {
      final ports = PortScannerService.parsePorts('abc,80,,99999,-5');
      expect(ports.keys.toList(), [80]);
    });

    test('caps the result at maxPorts, ascending', () {
      final ports = PortScannerService.parsePorts('1-100', maxPorts: 10);
      expect(ports.length, 10);
      expect(ports.keys.first, 1);
      expect(ports.keys.last, 10);
    });

    test('returns an empty map for blank input', () {
      expect(PortScannerService.parsePorts('   '), isEmpty);
    });
  });

  group('PortScannerService.scan', () {
    test('reports open and closed ports correctly', () async {
      final openServer = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(openServer.close);
      openServer.listen((socket) => socket.destroy());
      final openPort = openServer.port;

      // Bind then immediately release a port so we have one we know
      // nothing is listening on, without hardcoding a port number.
      final closedServer = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final closedPort = closedServer.port;
      await closedServer.close();

      final results = <PortScanResult>[];
      await PortScannerService.scan(
        host: '127.0.0.1',
        ports: {openPort: 'open-test', closedPort: 'closed-test'},
        isCancelled: () => false,
        timeout: const Duration(milliseconds: 500),
        onResult: results.add,
      );

      expect(results, hasLength(2));
      final open = results.firstWhere((r) => r.port == openPort);
      final closed = results.firstWhere((r) => r.port == closedPort);
      expect(open.isOpen, isTrue);
      expect(closed.isOpen, isFalse);
    });

    test('stops delivering results once cancelled', () async {
      var cancelled = false;
      final results = <PortScanResult>[];

      await PortScannerService.scan(
        host: '127.0.0.1',
        ports: const {1: 'a', 2: 'b', 3: 'c', 4: 'd'},
        concurrency: 1,
        timeout: const Duration(milliseconds: 200),
        isCancelled: () => cancelled,
        onResult: (result) {
          results.add(result);
          cancelled = true;
        },
      );

      expect(results, hasLength(1));
    });
  });
}
