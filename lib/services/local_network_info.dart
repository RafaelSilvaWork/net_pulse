import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';

class LocalNetworkInfo {
  static final NetworkInfo _networkInfo = NetworkInfo();

  /// Returns the device's current local IPv4 address.
  ///
  /// Tries the WiFi-specific plugin API first (works on Android/iOS, even
  /// when the OS blocks direct interface enumeration). Falls back to reading
  /// the network interfaces directly, which is what makes this work on
  /// desktop platforms (Windows/macOS/Linux) where `network_info_plus`
  /// doesn't return a WiFi IP.
  static Future<String?> getLocalIp() async {
    try {
      final wifiIp = await _networkInfo.getWifiIP();
      if (wifiIp != null && wifiIp.isNotEmpty && wifiIp != '0.0.0.0') {
        return wifiIp;
      }
    } catch (_) {
      // Not available on this platform, or permission denied — fall through.
    }
    return _getIpFromInterfaces();
  }

  static Future<String?> _getIpFromInterfaces() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (_isPrivateIPv4(address.address)) {
            return address.address;
          }
        }
      }
    } catch (_) {
      // No usable network interface found.
    }
    return null;
  }

  /// Whether [ip] falls in one of the RFC1918 private ranges typically used
  /// by home/office LANs (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16).
  static bool _isPrivateIPv4(String ip) {
    final parts = ip.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((p) => p == null)) return false;
    final a = parts[0]!;
    final b = parts[1]!;
    if (a == 10) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    if (a == 192 && b == 168) return true;
    return false;
  }

  /// Derives the `a.b.c` subnet prefix from a full IPv4 address such as
  /// `192.168.1.42`, assuming a typical /24 local network.
  static String? subnetPrefixFrom(String? ip) {
    if (ip == null) return null;
    final parts = ip.split('.');
    if (parts.length != 4) return null;
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }
}
