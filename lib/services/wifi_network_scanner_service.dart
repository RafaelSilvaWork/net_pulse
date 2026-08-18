import 'dart:io';

import 'package:flutter_wifi_scan/flutter_wifi_scan.dart' as fws;

class WifiNetwork {
  final String ssid;
  final int? signalPercent;

  const WifiNetwork({required this.ssid, this.signalPercent});
}

class WifiScanException implements Exception {
  final String message;
  const WifiScanException(this.message);

  @override
  String toString() => message;
}

/// Lists nearby WiFi networks (SSIDs). Unlike the rest of the app's
/// scanning, this is heavily platform-restricted: Android exposes it
/// through the OS (behind a location permission, an Android quirk for this
/// specific kind of data), Windows is covered here via `netsh` since there
/// is no well-maintained plugin for it, and iOS/macOS/Linux/web are not
/// supported at all — iOS in particular requires a special Apple
/// entitlement that isn't available to regular apps.
class WifiNetworkScannerService {
  static bool get isSupported => Platform.isAndroid || Platform.isWindows;

  static Future<List<WifiNetwork>> scan() async {
    if (Platform.isAndroid) return _scanAndroid();
    if (Platform.isWindows) return _scanWindows();
    throw const WifiScanException(
      'Varredura de redes WiFi não é suportada nesta plataforma.',
    );
  }

  static Future<List<WifiNetwork>> _scanAndroid() async {
    final canStart = await fws.WiFiScan.instance.canStartScan();
    if (canStart != fws.CanStartScan.yes) {
      throw WifiScanException(_canStartMessage(canStart));
    }

    final canGet = await fws.WiFiScan.instance.canGetScannedResults();
    if (canGet != fws.CanGetScannedResults.yes) {
      throw WifiScanException(_canGetMessage(canGet));
    }

    final resultsFuture = fws.WiFiScan.instance.onScannedResultsAvailable
        .first;
    await fws.WiFiScan.instance.startScan();
    final accessPoints = await resultsFuture.timeout(
      const Duration(seconds: 8),
      onTimeout: fws.WiFiScan.instance.getScannedResults,
    );

    final byBssid = <String, fws.WiFiAccessPoint>{};
    for (final ap in accessPoints) {
      byBssid[ap.bssid] = ap;
    }

    final seenSsids = <String>{};
    final networks = <WifiNetwork>[];
    for (final ap in byBssid.values) {
      if (ap.ssid.isEmpty || !seenSsids.add(ap.ssid)) continue;
      networks.add(
        WifiNetwork(ssid: ap.ssid, signalPercent: _dbmToPercent(ap.level)),
      );
    }
    networks.sort(
      (a, b) => (b.signalPercent ?? 0).compareTo(a.signalPercent ?? 0),
    );
    return networks;
  }

  static int _dbmToPercent(int dbm) {
    if (dbm <= -100) return 0;
    if (dbm >= -50) return 100;
    return 2 * (dbm + 100);
  }

  static String _canStartMessage(fws.CanStartScan can) {
    switch (can) {
      case fws.CanStartScan.noLocationPermissionDenied:
        return 'Permissão de localização negada. Ative-a nas configurações '
            'do app para escanear redes WiFi.';
      case fws.CanStartScan.noLocationPermissionRequired:
        return 'É necessário conceder permissão de localização para '
            'escanear redes WiFi.';
      case fws.CanStartScan.noLocationPermissionUpgradeAccuracy:
        return 'A precisão de localização precisa estar como "Exata" nas '
            'configurações do sistema.';
      case fws.CanStartScan.noLocationServiceDisabled:
        return 'Ative o serviço de localização do aparelho para escanear '
            'redes WiFi.';
      case fws.CanStartScan.notSupported:
        return 'Este aparelho não suporta varredura de redes WiFi.';
      case fws.CanStartScan.failed:
      case fws.CanStartScan.yes:
        return 'Não foi possível iniciar a varredura de redes WiFi.';
    }
  }

  static String _canGetMessage(fws.CanGetScannedResults can) {
    switch (can) {
      case fws.CanGetScannedResults.noLocationPermissionDenied:
        return 'Permissão de localização negada. Ative-a nas configurações '
            'do app.';
      case fws.CanGetScannedResults.noLocationPermissionRequired:
        return 'É necessário conceder permissão de localização.';
      case fws.CanGetScannedResults.noLocationPermissionUpgradeAccuracy:
        return 'A precisão de localização precisa estar como "Exata" nas '
            'configurações do sistema.';
      case fws.CanGetScannedResults.noLocationServiceDisabled:
        return 'Ative o serviço de localização do aparelho.';
      case fws.CanGetScannedResults.notSupported:
        return 'Este aparelho não suporta leitura de redes WiFi.';
      case fws.CanGetScannedResults.yes:
        return 'Não foi possível ler os resultados da varredura.';
    }
  }

  // Matches lines like "SSID 1 : MinhaRede" — the "SSID" keyword itself is
  // kept untranslated by netsh across locales (it's a technical acronym),
  // which is what makes this reliable regardless of the system's language.
  // Whitespace here is deliberately [ \t] rather than \s, which also
  // matches newlines — with \s, an empty SSID line ("SSID 1 :" with
  // nothing after it) would swallow the line break and capture the next
  // line's content as the "name" instead of an empty string.
  static final RegExp _ssidLine = RegExp(
    r'^[ \t]*SSID[ \t]+\d+[ \t]*:[ \t]*(.*)$',
    multiLine: true,
  );

  // A bare "NN%" is used for signal strength in every locale's netsh
  // output — we key off the symbol rather than the (translated) label.
  static final RegExp _signalPercent = RegExp(r'(\d{1,3})[ \t]*%');

  static Future<List<WifiNetwork>> _scanWindows() async {
    final ProcessResult result;
    try {
      result = await Process.run('netsh', [
        'wlan',
        'show',
        'networks',
        'mode=bssid',
      ]);
    } catch (_) {
      throw const WifiScanException(
        'Não foi possível executar o comando netsh para escanear redes '
        'WiFi. Verifique se há um adaptador WiFi disponível.',
      );
    }

    if (result.exitCode != 0) {
      throw const WifiScanException(
        'O netsh não conseguiu listar as redes. O adaptador WiFi pode '
        'estar desligado.',
      );
    }

    return parseNetshOutput(result.stdout.toString());
  }

  /// Parses `netsh wlan show networks mode=bssid` output into a network
  /// list. Pulled out of [_scanWindows] so it can be unit tested against
  /// sample output without actually running netsh.
  static List<WifiNetwork> parseNetshOutput(String output) {
    final matches = _ssidLine.allMatches(output).toList();
    final networks = <WifiNetwork>[];
    for (var i = 0; i < matches.length; i++) {
      final name = matches[i].group(1)?.trim() ?? '';
      if (name.isEmpty) continue;
      final blockEnd = i + 1 < matches.length
          ? matches[i + 1].start
          : output.length;
      final block = output.substring(matches[i].end, blockEnd);
      final signalMatch = _signalPercent.firstMatch(block);
      networks.add(
        WifiNetwork(
          ssid: name,
          signalPercent: signalMatch != null
              ? int.tryParse(signalMatch.group(1)!)
              : null,
        ),
      );
    }
    networks.sort(
      (a, b) => (b.signalPercent ?? 0).compareTo(a.signalPercent ?? 0),
    );
    return networks;
  }
}
