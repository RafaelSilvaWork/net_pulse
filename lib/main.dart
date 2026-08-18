import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/rede_local_screen.dart';
import 'screens/scanner_portas_screen.dart';

void main() {
  runApp(const NetPulseApp());
}

class NetPulseApp extends StatelessWidget {
  const NetPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NetPulse',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const NetPulseHome(),
    );
  }
}

class NetPulseHome extends StatefulWidget {
  const NetPulseHome({super.key});

  @override
  State<NetPulseHome> createState() => _NetPulseHomeState();
}

class _NetPulseHomeState extends State<NetPulseHome> {
  // Screen width above which we switch from a bottom NavigationBar (mobile)
  // to a side NavigationRail (desktop/tablet), matching Material guidance.
  static const double _wideLayoutBreakpoint = 700;
  static const String _disclaimerAckKey = 'responsible_use_ack';

  int _currentIndex = 0;

  final List<Widget> _telas = [
    const ScannerPortasScreen(),
    const RedeLocalScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeShowDisclaimer(),
    );
  }

  Future<void> _maybeShowDisclaimer() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (prefs.getBool(_disclaimerAckKey) ?? false) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Uso responsável'),
        content: const Text(
          'O NetPulse escaneia portas e dispositivos na rede local. Use '
          'apenas em redes e equipamentos que você tem autorização para '
          'testar — escanear redes de terceiros sem permissão pode violar '
          'leis locais.',
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              await prefs.setBool(_disclaimerAckKey, true);
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  void _onDestinationSelected(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= _wideLayoutBreakpoint;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.radar),
                  label: Text('Scanner de Portas'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.devices),
                  label: Text('Dispositivos na Rede'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _telas[_currentIndex]),
          ],
        ),
      );
    }

    return Scaffold(
      body: _telas[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.radar),
            label: 'Scanner de Portas',
          ),
          NavigationDestination(
            icon: Icon(Icons.devices),
            label: 'Dispositivos na Rede',
          ),
        ],
      ),
    );
  }
}
