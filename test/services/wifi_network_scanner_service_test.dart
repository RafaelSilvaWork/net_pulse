import 'package:flutter_test/flutter_test.dart';

import 'package:net_pulse/services/wifi_network_scanner_service.dart';

void main() {
  group('WifiNetworkScannerService.parseNetshOutput', () {
    test('parses SSIDs and signal strength from English-locale output', () {
      const output = '''
Interface name : Wi-Fi
There are 2 networks currently visible.

SSID 1 : Casa da Familia
    Network type            : Infrastructure
    Authentication          : WPA2-Personal
    Encryption               : CCMP
    BSSID 1                  : aa:bb:cc:dd:ee:ff
         Signal              : 81%
         Radio type          : 802.11ac
         Channel             : 6

SSID 2 : Vizinho_5G
    Network type            : Infrastructure
    Authentication          : WPA2-Personal
    Encryption               : CCMP
    BSSID 1                  : 11:22:33:44:55:66
         Signal              : 42%
         Radio type          : 802.11ac
         Channel             : 149
''';

      final networks = WifiNetworkScannerService.parseNetshOutput(output);

      expect(networks, hasLength(2));
      // Sorted by signal strength, strongest first.
      expect(networks[0].ssid, 'Casa da Familia');
      expect(networks[0].signalPercent, 81);
      expect(networks[1].ssid, 'Vizinho_5G');
      expect(networks[1].signalPercent, 42);
    });

    test('parses correctly even with translated (pt-BR) labels', () {
      // "SSID" itself stays untranslated by netsh; the surrounding labels
      // ("Sinal", "Autenticação"...) do get localized. The parser only
      // depends on the untranslated "SSID N :" marker and a bare "NN%".
      const output = '''
Nome da interface : Wi-Fi
Há 1 rede atualmente visível.

SSID 1 : Roteador da Casa
    Tipo de rede             : Infraestrutura
    Autenticação             : WPA2-Pessoal
    Criptografia              : CCMP
    BSSID 1                   : 00:11:22:33:44:55
         Sinal                : 67%
         Tipo de rádio        : 802.11ac
         Canal                : 11
''';

      final networks = WifiNetworkScannerService.parseNetshOutput(output);

      expect(networks, hasLength(1));
      expect(networks.single.ssid, 'Roteador da Casa');
      expect(networks.single.signalPercent, 67);
    });

    test('skips SSID entries with an empty name (hidden networks)', () {
      const output = '''
SSID 1 :
    Network type            : Infrastructure

SSID 2 : Rede Visivel
    Network type            : Infrastructure
         Signal              : 55%
''';

      final networks = WifiNetworkScannerService.parseNetshOutput(output);

      expect(networks, hasLength(1));
      expect(networks.single.ssid, 'Rede Visivel');
    });

    test('returns an empty list when there are no networks', () {
      const output = '''
Interface name : Wi-Fi
There are 0 networks currently visible.
''';

      expect(WifiNetworkScannerService.parseNetshOutput(output), isEmpty);
    });
  });
}
