import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/local_network_info.dart';
import '../services/port_scanner_service.dart';
import '../services/scan_history_service.dart';

class ScannerPortasScreen extends StatefulWidget {
  const ScannerPortasScreen({super.key});

  @override
  State<ScannerPortasScreen> createState() => _ScannerPortasScreenState();
}

class _ScannerPortasScreenState extends State<ScannerPortasScreen> {
  static final RegExp _ipv4Pattern = RegExp(
    r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$',
  );

  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portsController = TextEditingController(
    text: '21,22,23,25,53,80,443,3306,3389,8080',
  );
  final List<PortScanResult> _resultados = [];
  bool _isScanning = false;
  bool _cancelRequested = false;
  String? _errorText;
  String? _portsErrorText;
  int _totalPorts = 0;

  @override
  void dispose() {
    _ipController.dispose();
    _portsController.dispose();
    super.dispose();
  }

  bool _isValidIpv4(String value) {
    final match = _ipv4Pattern.firstMatch(value);
    if (match == null) return false;
    for (var i = 1; i <= 4; i++) {
      final octet = int.parse(match.group(i)!);
      if (octet > 255) return false;
    }
    return true;
  }

  Future<void> _escanearPortas() async {
    final ip = _ipController.text.trim();
    if (!_isValidIpv4(ip)) {
      setState(() => _errorText = 'Informe um endereço IPv4 válido');
      return;
    }

    final ports = PortScannerService.parsePorts(_portsController.text);
    if (ports.isEmpty) {
      setState(
        () => _portsErrorText = 'Informe ao menos uma porta válida (1-65535)',
      );
      return;
    }

    setState(() {
      _errorText = null;
      _portsErrorText = null;
      _resultados.clear();
      _isScanning = true;
      _cancelRequested = false;
      _totalPorts = ports.length;
    });

    await PortScannerService.scan(
      host: ip,
      ports: ports,
      isCancelled: () => _cancelRequested,
      onResult: (result) {
        if (!mounted) return;
        setState(() => _resultados.add(result));
      },
    );

    if (!_cancelRequested) {
      final abertas = _resultados.where((r) => r.isOpen).toList();
      await ScanHistoryService.add(
        ScanHistoryEntry(
          type: ScanType.ports,
          target: ip,
          timestamp: DateTime.now(),
          summaryLines: [
            for (final r in abertas) 'Porta ${r.port} (${r.service})',
          ],
          matchCount: abertas.length,
        ),
      );
    }

    if (!mounted) return;
    setState(() => _isScanning = false);
  }

  void _cancelarScan() {
    setState(() => _cancelRequested = true);
  }

  void _compartilharResultados() {
    final ip = _ipController.text.trim();
    final abertas = _resultados.where((r) => r.isOpen).toList();
    final buffer = StringBuffer('NetPulse — varredura de portas em $ip\n\n');
    if (abertas.isEmpty) {
      buffer.writeln('Nenhuma porta aberta encontrada.');
    } else {
      for (final r in abertas) {
        buffer.writeln('Porta ${r.port} (${r.service}): ABERTA');
      }
    }
    Share.share(buffer.toString());
  }

  Future<void> _usarMeuIp() async {
    final ip = await LocalNetworkInfo.getLocalIp();
    if (!mounted) return;
    if (ip == null) {
      setState(() => _errorText = 'Não foi possível detectar seu IP');
      return;
    }
    setState(() {
      _ipController.text = ip;
      _errorText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NetPulse - Scanner de Portas'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _ipController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Endereço IP Alvo',
                hintText: 'Ex: 192.168.1.1',
                border: const OutlineInputBorder(),
                errorText: _errorText,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.my_location),
                  tooltip: 'Usar meu IP',
                  onPressed: _isScanning ? null : _usarMeuIp,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _portsController,
              decoration: InputDecoration(
                labelText: 'Portas (ex: 22,80,443 ou 8000-8010)',
                border: const OutlineInputBorder(),
                errorText: _portsErrorText,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isScanning ? null : _escanearPortas,
                      icon: _isScanning
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.radar),
                      label: Text(
                        _isScanning
                            ? 'Escaneando Portas...'
                            : 'Iniciar Varredura',
                      ),
                    ),
                  ),
                ),
                if (_isScanning) ...[
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
            if (_isScanning && _totalPorts > 0) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _resultados.length / _totalPorts),
              const SizedBox(height: 4),
              Text(
                '${_resultados.length}/$_totalPorts portas verificadas',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Resultados:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!_isScanning && _resultados.isNotEmpty)
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
                itemCount: _resultados.length,
                itemBuilder: (context, index) {
                  final resultado = _resultados[index];
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        resultado.isOpen
                            ? Icons.lock_open
                            : Icons.lock_outline,
                        color: resultado.isOpen ? Colors.green : Colors.grey,
                      ),
                      title: Text(
                        'Porta ${resultado.port} (${resultado.service})',
                      ),
                      trailing: Text(
                        resultado.isOpen ? 'ABERTA' : 'Fechada',
                        style: TextStyle(
                          color: resultado.isOpen
                              ? Colors.green
                              : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
