import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:net_pulse/main.dart';

void main() {
  // Pre-acknowledge the responsible-use disclaimer so it doesn't pop up and
  // block taps on the underlying screen during these navigation tests.
  setUp(() {
    SharedPreferences.setMockInitialValues({'responsible_use_ack': true});
  });

  testWidgets('NetPulseApp shows both scanner tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NetPulseApp());

    expect(find.text('Scanner de Portas'), findsWidgets);
    expect(find.text('Dispositivos na Rede'), findsWidgets);
    expect(find.text('Redes WiFi'), findsWidgets);
    expect(find.text('Histórico'), findsWidgets);
    expect(find.text('Endereço IP Alvo'), findsOneWidget);
  });

  testWidgets('Switching tabs shows the network devices screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NetPulseApp());

    await tester.tap(find.byIcon(Icons.devices));
    await tester.pumpAndSettle();

    expect(find.text('Varrer Rede Local'), findsOneWidget);
  });

  testWidgets('Switching tabs shows the WiFi networks screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NetPulseApp());

    await tester.tap(find.text('Redes WiFi'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Escanear Redes WiFi'),
      Platform.isAndroid || Platform.isWindows ? findsOneWidget : findsNothing,
    );
  });
}
