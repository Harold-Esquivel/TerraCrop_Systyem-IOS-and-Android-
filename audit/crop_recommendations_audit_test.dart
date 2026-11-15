// Read-only acceptance audit of the currently rendered recommendations.
// Outside test/ so known product gaps do not masquerade as passing regression
// tests. Run explicitly; failures document missing requested behavior.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:terracrop/app/app_theme.dart';
import 'package:terracrop/app/ui.dart';
import 'package:terracrop/data/models.dart';
import 'package:terracrop/data/terra_store.dart';
import 'package:terracrop/screens/crops_screen.dart';

class AdviceSnapshot {
  const AdviceSnapshot(this.notice, this.details);
  final String notice;
  final String details;
  String get combined => '$notice $details';
}

Future<AdviceSnapshot> inspectAdvice(
  WidgetTester tester,
  Parcel parcel,
  String scenario,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  final store = TerraStore()..parcels = [parcel];
  final original = parcel.toJson();
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: store,
      child: MaterialApp(
        theme: appTheme,
        home: const Scaffold(body: SafeArea(child: CropsScreen())),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  var notice = '';
  final tip = find.byIcon(Icons.tips_and_updates_outlined);
  if (tip.evaluate().isNotEmpty) {
    Element? alert;
    tester.element(tip).visitAncestorElements((element) {
      if (element.widget is Container) {
        alert = element;
        return false;
      }
      return true;
    });
    expect(alert, isNotNull);
    notice = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byWidget(alert!.widget),
            matching: find.byType(Text),
          ),
        )
        .map((w) => w.data ?? '')
        .join(' ');
  }
  final expand = find.text('Ver recomendaciones');
  await tester.scrollUntilVisible(
    expand,
    160,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(expand);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  final texts = tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(SurfaceCard),
          matching: find.byType(Text),
        ),
      )
      .map((w) => w.data ?? '')
      .toList();
  final heading = texts.indexWhere(
    (t) =>
        t == 'Acciones recomendadas' || t == 'Cultivos alternativos sugeridos',
  );
  expect(
    heading,
    greaterThanOrEqualTo(0),
    reason: 'La auditoría debe poder leer el panel expandido',
  );
  final details = texts[heading + 1];
  expect(tester.takeException(), isNull);
  expect(
    store.parcels.single.toJson(),
    original,
    reason: 'Consultar recomendaciones no debe modificar la parcela',
  );
  // Machine-readable evidence is captured by --reporter json.
  // ignore: avoid_print
  print(
    'RECOMMENDATION_AUDIT ${jsonEncode({'scenario': scenario, 'crop': parcel.crop, 'ph': parcel.ph, 'moisture': parcel.moisture, 'nitrogen': parcel.nitrogen, 'phosphorus': parcel.phosphorus, 'potassium': parcel.potassium, 'warning': parcel.warning, 'critical': parcel.critical, 'notice': notice, 'details': details})}',
  );
  return AdviceSnapshot(notice, details);
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  final healthy = demoParcels().first.copyWith(
    ph: 6.5,
    moisture: 68,
    nitrogen: 70,
    phosphorus: 70,
    potassium: 70,
  );

  testWidgets('pH bajo: informa el problema', (tester) async {
    final advice = await inspectAdvice(
      tester,
      healthy.copyWith(ph: 5.3),
      'pH bajo',
    );
    expect(advice.notice.toLowerCase(), contains('ph está muy bajo'));
  });
  testWidgets('pH alto: informa el problema', (tester) async {
    final advice = await inspectAdvice(
      tester,
      healthy.copyWith(ph: 8),
      'pH alto',
    );
    expect(advice.notice.toLowerCase(), contains('ph está alto'));
  });
  testWidgets('humedad baja: informa el problema', (tester) async {
    final advice = await inspectAdvice(
      tester,
      healthy.copyWith(moisture: 35),
      'humedad baja',
    );
    expect(advice.notice.toLowerCase(), contains('humedad es baja'));
  });
  testWidgets('suelo saludable: no inventa un déficit', (tester) async {
    final advice = await inspectAdvice(
      tester,
      healthy,
      'condiciones saludables',
    );
    expect(advice.notice, isEmpty);
    expect(advice.details, isNotEmpty);
  });
  for (final ph in [5.8, 7.5]) {
    testWidgets('pH $ph con NPK normal: no diagnostica nutrientes bajos', (
      tester,
    ) async {
      final advice = await inspectAdvice(
        tester,
        healthy.copyWith(ph: ph),
        'pH $ph, nutrientes normales',
      );
      expect(
        advice.notice.toLowerCase(),
        isNot(contains('nutrientes están bajos')),
        reason:
            'N, P y K están en 70; un aviso de pH no debe atribuirse a nutrientes bajos',
      );
    });
  }
  for (final nutrient in ['nitrógeno', 'fósforo', 'potasio']) {
    testWidgets('déficit de $nutrient: identifica el elemento que falta', (
      tester,
    ) async {
      final parcel = switch (nutrient) {
        'nitrógeno' => healthy.copyWith(nitrogen: 20),
        'fósforo' => healthy.copyWith(phosphorus: 20),
        _ => healthy.copyWith(potassium: 20),
      };
      final advice = await inspectAdvice(
        tester,
        parcel,
        'déficit de $nutrient',
      );
      expect(
        advice.combined.toLowerCase(),
        contains(nutrient),
        reason:
            'La recomendación debe identificar el nutriente deficiente, no solo el promedio NPK',
      );
    });
  }
  testWidgets('déficits combinados: informa pH, agua y cada nutriente', (
    tester,
  ) async {
    final advice = await inspectAdvice(
      tester,
      healthy.copyWith(
        ph: 5.3,
        moisture: 20,
        nitrogen: 20,
        phosphorus: 20,
        potassium: 20,
      ),
      'déficits combinados',
    );
    expect(
      advice.combined.toLowerCase(),
      allOf(
        contains('ph'),
        contains('humedad'),
        contains('nitrógeno'),
        contains('fósforo'),
        contains('potasio'),
      ),
      reason: 'Un problema de pH no debe ocultar los otros cuatro problemas',
    );
  });
  testWidgets('pH normal y N bajo: no ordena corregir el pH', (tester) async {
    final advice = await inspectAdvice(
      tester,
      healthy.copyWith(nitrogen: 20),
      'N bajo con pH normal',
    );
    expect(
      advice.details.toLowerCase(),
      isNot(contains('corrige el ph')),
      reason: 'El pH 6.5 es normal según las reglas de la propia app',
    );
  });
  testWidgets('rotación desde Papa: no propone el mismo cultivo', (
    tester,
  ) async {
    await inspectAdvice(
      tester,
      healthy.copyWith(crop: 'Maíz', nitrogen: 20),
      'rotación desde Maíz',
    );
    final potato = await inspectAdvice(
      tester,
      healthy.copyWith(crop: 'Papa', nitrogen: 20),
      'rotación desde Papa',
    );
    expect(
      potato.details,
      isNot(
        matches(RegExp(r'\bconsidera\s+[^,.]*\bpapa\b', caseSensitive: false)),
      ),
      reason:
          'No debe incluir Papa en la propuesta de siguientes cultivos cuando el cultivo actual ya es Papa',
    );
  });
}
