import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:net_pulse/services/network_scanner_service.dart';

void main() {
  group('NetworkScannerService.scanSubnet', () {
    test('only reports hosts that actually answer a probe', () async {
      // 127.0.0.0/8 all route to loopback, but a server bound specifically
      // to 127.0.0.1 won't answer on 127.0.0.2-5 — that's what lets this
      // test tell a real "host up" from a fabricated one.
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((socket) => socket.destroy());

      final found = <String>[];
      await NetworkScannerService.scanSubnet(
        subnetPrefix: '127.0.0',
        startHost: 1,
        endHost: 5,
        probePorts: [server.port],
        timeout: const Duration(milliseconds: 300),
        isCancelled: () => false,
        onHostFound: (result) => found.add(result.ip),
      );

      expect(found, ['127.0.0.1']);
    });

    test('reports progress for every host checked, found or not', () async {
      final progressUpdates = <int>[];

      await NetworkScannerService.scanSubnet(
        subnetPrefix: '127.0.0',
        startHost: 1,
        endHost: 5,
        probePorts: const [1], // nothing listens on 127.0.0.x:1
        timeout: const Duration(milliseconds: 200),
        isCancelled: () => false,
        onProgress: (completed, total) => progressUpdates.add(completed),
        onHostFound: (_) {},
      );

      expect(progressUpdates.last, 5);
    });

    test('stops early once cancelled', () async {
      var cancelled = false;
      final found = <String>[];

      await NetworkScannerService.scanSubnet(
        subnetPrefix: '127.0.0',
        startHost: 1,
        endHost: 10,
        concurrency: 1,
        probePorts: const [1],
        timeout: const Duration(milliseconds: 100),
        isCancelled: () => cancelled,
        onProgress: (completed, total) {
          if (completed == 2) cancelled = true;
        },
        onHostFound: (result) => found.add(result.ip),
      );

      expect(found, isEmpty);
    });
  });
}
