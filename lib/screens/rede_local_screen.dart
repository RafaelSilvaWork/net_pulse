import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/local_network_info.dart';
import '../services/network_scanner_service.dart';
import '../services/scan_history_service.dart';

class RedeLocalScreen extends StatefulWidget {
  const RedeLocalScreen({super.key});

  @override
  State<RedeLocalScreen> createState() => _RedeLocalScreenState();
}

class _RedeLocalScreenState extends State<RedeLocalScreen> {
  final List<HostScanResult> _dispositivosAtivos = [];
  bool _isSearching = false;
  bool _cancelRequested = false;
  String? _statusMessage;
  String? _localIp;
  bool _loadingLocalIp = true;
  int _progressCompleted = 0;
  int _progressTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadLocalIp();
  }

  Future<void> _loadLocalIp() async {
    final ip = await LocalNetworkInfo.getLocalIp();
    if (!mounted) return;
    setState(() {
      _localIp = ip;
      _loadingLocalIp = false;
    });
  }

  Future<void> _buscarDispositivos() async {
    setState(() {
      _dispositivosAtivos.clear();
      _isSearching = true;
      _cancelRequested = false;
      _statusMessage = 'Detectando rede local...';
      _progressCompleted = 0;
      _progressTotal = 0;
    });

    final deviceIp = _localIp ?? await LocalNetworkInfo.getLocalIp();
    final subnetPrefix = LocalNetworkInfo.subnetPrefixFrom(deviceIp);

    if (!mounted) return;

    setState(() {
      _localIp = deviceIp;
      _loadingLocalIp = false;
    });

    if (subnetPrefix == null) {
      setState(() {
        _isSearching = false;
        _statusMessage =
            'Não foi possível detectar sua rede WiFi. Conecte-se a uma '
            'rede WiFi e tente novamente.';
      });
      return;
    }

    setState(() {
      _statusMessage = 'Varrendo $subnetPrefix.1 - $subnetPrefix.254...';
    });

    await NetworkScannerService.scanSubnet(
      subnetPrefix: subnetPrefix,
      isCancelled: () => _cancelRequested,
      onProgress: (completed, total) {
        if (!mounted) return;
        setState(() {
          _progressCompleted = completed;
          _progressTotal = total;
        });
      },
      onHostFound: (result) {
        if (!mounted) return;
        setState(() => _dispositivosAtivos.add(result));
      },
    );

    if (!_cancelRequested) {
      await ScanHistoryService.add(
        ScanHistoryEntry(
          type: ScanType.network,
          target: '$subnetPrefix.0/24',
          timestamp: DateTime.now(),
          summaryLines: [for (final h in _dispositivosAtivos) h.ip],
          matchCount: _dispositivosAtivos.length,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _isSearching = false;
      _statusMessage = _cancelRequested ? 'Varredura cancelada.' : null;
    });
  }

  void _cancelarScan() {
    setState(() => _cancelRequested = true);
  }

  void _compartilharResultados() {
    final buffer = StringBuffer(
      'NetPulse — dispositivos encontrados na rede local\n\n',
    );
    if (_dispositivosAtivos.isEmpty) {
      buffer.writeln('Nenhum dispositivo encontrado.');
    } else {
      for (final host in _dispositivosAtivos) {
        buffer.writeln(host.ip);
      }
    }
    Share.share(buffer.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NetPulse - Dispositivos na Rede'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.smartphone),
                title: const Text('Seu IP'),
                subtitle: Text(
                  _loadingLocalIp
                      ? 'Detectando...'
                      : (_localIp ?? 'Não foi possível detectar'),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadingLocalIp
                      ? null
                      : () {
                          setState(() => _loadingLocalIp = true);
                          _loadLocalIp();
                        },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSearching ? null : _buscarDispositivos,
                      icon: _isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.wifi_find),
                      label: Text(
                        _isSearching
                            ? 'Procurando Dispositivos...'
                            : 'Varrer Rede Local',
                      ),
                    ),
                  ),
                ),
                if (_isSearching) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _cancelRequested ? null : _cancelarScan,
                      child: const Text('Cancelar'),
                    ),
                  ),
                ],
              ],
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _statusMessage!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (_isSearching && _progressTotal > 0) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _progressCompleted / _progressTotal,
              ),
              const SizedBox(height: 4),
              Text(
                '$_progressCompleted/$_progressTotal hosts verificados',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Dispositivos Encontrados:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!_isSearching && _dispositivosAtivos.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.share),
                    tooltip: 'Compartilhar resultados',
                    onPressed: _compartilharResultados,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _dispositivosAtivos.length,
                itemBuilder: (context, index) {
                  final host = _dispositivosAtivos[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.devices_other,
                        color: Colors.blueAccent,
                      ),
                      title: Text(host.ip),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
