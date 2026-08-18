import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum ScanType { ports, network }

class ScanHistoryEntry {
  final ScanType type;
  final String target;
  final DateTime timestamp;
  final List<String> summaryLines;
  final int matchCount;

  const ScanHistoryEntry({
    required this.type,
    required this.target,
    required this.timestamp,
    required this.summaryLines,
    required this.matchCount,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'target': target,
    'timestamp': timestamp.toIso8601String(),
    'summaryLines': summaryLines,
    'matchCount': matchCount,
  };

  factory ScanHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ScanHistoryEntry(
      type: ScanType.values.firstWhere((t) => t.name == json['type']),
      target: json['target'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      summaryLines: (json['summaryLines'] as List).cast<String>(),
      matchCount: json['matchCount'] as int,
    );
  }
}

/// Persists a rolling window of recent scan results (both port scans and
/// network sweeps) with `shared_preferences`, so the user can look back at
/// what a previous scan found without re-running it.
class ScanHistoryService {
  static const String _key = 'scan_history_v1';
  static const int maxEntries = 30;

  static Future<List<ScanHistoryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    return raw.map((entry) {
      final json = jsonDecode(entry) as Map<String, dynamic>;
      return ScanHistoryEntry.fromJson(json);
    }).toList();
  }

  static Future<void> add(ScanHistoryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    final updated = [jsonEncode(entry.toJson()), ...raw];
    if (updated.length > maxEntries) {
      updated.removeRange(maxEntries, updated.length);
    }
    await prefs.setStringList(_key, updated);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
