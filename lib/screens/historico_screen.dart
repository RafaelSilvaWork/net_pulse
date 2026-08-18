import 'package:flutter/material.dart';

import '../services/scan_history_service.dart';

class HistoricoScreen extends StatefulWidget {
  const HistoricoScreen({super.key});

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  List<ScanHistoryEntry> _entries = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await ScanHistoryService.load();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _limparHistorico() async {
    await ScanHistoryService.clear();
    if (!mounted) return;
    setState(() => _entries = const []);
  }

  String _formatTimestamp(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    final date = '${two(dt.day)}/${two(dt.month)}/${dt.year}';
    final time = '${two(dt.hour)}:${two(dt.minute)}';
    return '$date $time';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NetPulse - Histórico'),
        centerTitle: true,
        actions: [
          if (_entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Limpar histórico',
              onPressed: _limparHistorico,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhuma varredura salva ainda. Rode um scan de portas ou '
                  'de rede para ver o histórico aqui.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                final entry = _entries[index];
                final isPortScan = entry.type == ScanType.ports;
                final unit = isPortScan
                    ? 'porta(s) aberta(s)'
                    : 'dispositivo(s) encontrado(s)';
                return Card(
                  child: ExpansionTile(
                    leading: Icon(isPortScan ? Icons.radar : Icons.devices),
                    title: Text(entry.target),
                    subtitle: Text(
                      '${_formatTimestamp(entry.timestamp)} · '
                      '${entry.matchCount} $unit',
                    ),
                    children: entry.summaryLines.isEmpty
                        ? [
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Nenhum resultado encontrado.'),
                            ),
                          ]
                        : entry.summaryLines
                              .map(
                                (line) =>
                                    ListTile(dense: true, title: Text(line)),
                              )
                              .toList(),
                  ),
                );
              },
            ),
    );
  }
}
