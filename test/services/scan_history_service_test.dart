import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:net_pulse/services/scan_history_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ScanHistoryService', () {
    test('starts empty', () async {
      expect(await ScanHistoryService.load(), isEmpty);
    });

    test('adds entries newest-first and round-trips fields', () async {
      await ScanHistoryService.add(
        ScanHistoryEntry(
          type: ScanType.ports,
          target: '192.168.1.1',
          timestamp: DateTime(2026, 1, 1, 10),
          summaryLines: const ['Porta 80 (HTTP)'],
          matchCount: 1,
        ),
      );
      await ScanHistoryService.add(
        ScanHistoryEntry(
          type: ScanType.network,
          target: '192.168.1.0/24',
          timestamp: DateTime(2026, 1, 1, 11),
          summaryLines: const ['192.168.1.5', '192.168.1.6'],
          matchCount: 2,
        ),
      );

      final entries = await ScanHistoryService.load();
      expect(entries, hasLength(2));
      expect(entries.first.type, ScanType.network);
      expect(entries.first.target, '192.168.1.0/24');
      expect(entries.first.summaryLines, ['192.168.1.5', '192.168.1.6']);
      expect(entries.last.type, ScanType.ports);
      expect(entries.last.matchCount, 1);
    });

    test('caps stored history at maxEntries', () async {
      for (var i = 0; i < ScanHistoryService.maxEntries + 5; i++) {
        await ScanHistoryService.add(
          ScanHistoryEntry(
            type: ScanType.ports,
            target: '10.0.0.$i',
            timestamp: DateTime(2026, 1, 1),
            summaryLines: const [],
            matchCount: 0,
          ),
        );
      }

      final entries = await ScanHistoryService.load();
      expect(entries.length, ScanHistoryService.maxEntries);
      // Most recent add should still be first.
      final lastIp = '10.0.0.${ScanHistoryService.maxEntries + 4}';
      expect(entries.first.target, lastIp);
    });

    test('clear removes all entries', () async {
      await ScanHistoryService.add(
        ScanHistoryEntry(
          type: ScanType.ports,
          target: '1.2.3.4',
          timestamp: DateTime(2026, 1, 1),
          summaryLines: const [],
          matchCount: 0,
        ),
      );
      await ScanHistoryService.clear();
      expect(await ScanHistoryService.load(), isEmpty);
    });
  });
}
