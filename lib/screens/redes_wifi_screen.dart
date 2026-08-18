import 'package:flutter/material.dart';

import '../services/wifi_network_scanner_service.dart';

class RedesWifiScreen extends StatefulWidget {
  const RedesWifiScreen({super.key});

  @override
  State<RedesWifiScreen> createState() => _RedesWifiScreenState();
}

class _RedesWifiScreenState extends State<RedesWifiScreen> {
  List<WifiNetwork> _redes = const [];
  bool _isScanning = false;
  String? _errorText;

  Future<void> _escanearRedes() async {
    setState(() {
      _isScanning = true;
      _errorText = null;
    });

    try {
      final redes = await WifiNetworkScannerService.scan();
      if (!mounted) return;
      setState(() => _redes = redes);
    } on WifiScanException catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorText = 'Não foi possível escanear redes WiFi.');
    }

    if (!mounted) return;
    setState(() => _isScanning = false);
  }

  IconData _signalIcon(int? percent) {
    if (percent == null) return Icons.wifi;
    if (percent >= 66) return Icons.wifi;
    if (percent >= 33) return Icons.wifi_2_bar;
    return Icons.wifi_1_bar;
  }

  @override
  Widget build(BuildContext context) {
    final supported = WifiNetworkScannerService.isSupported;

    return Scaffold(
      appBar: AppBar(
        title: const Text('NetPulse - Redes WiFi'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: !supported
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Varredura de redes WiFi não é suportada nesta '
                    'plataforma (disponível em Android e Windows).',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isScanning ? null : _escanearRedes,
                      icon: _isScanning
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.wifi_find),
                      label: Text(
                        _isScanning
                            ? 'Escaneando Redes...'
                            : 'Escanear Redes WiFi',
                      ),
                    ),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Redes Encontradas:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _redes.length,
                      itemBuilder: (context, index) {
                        final rede = _redes[index];
                        return Card(
                          child: ListTile(
                            leading: Icon(_signalIcon(rede.signalPercent)),
                            title: Text(rede.ssid),
                            trailing: rede.signalPercent != null
                                ? Text('${rede.signalPercent}%')
                                : null,
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
