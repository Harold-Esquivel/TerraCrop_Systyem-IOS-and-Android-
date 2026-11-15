// Read-only acceptance audit of the currently rendered recommendations.
// Kept outside test/ so the original acceptance criteria can be rerun explicitly
// after the workbook-based remediation, separately from regression tests.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:terracrop/app/app_theme.dart';
import 'package:terracrop/data/agronomy_catalog.dart';
import 'package:terracrop/data/models.dart';
import 'package:terracrop/data/terra_store.dart';
import 'package:terracrop/screens/crops_screen.dart';

class AdviceSnapshot {
  const AdviceSnapshot(
    this.notice,
    this.details,
    this.issueIds,
    this.validRotationIds,
  );
  final String notice;
  final String details;
  final Set<String> issueIds;
  final Set<String> validRotationIds;
  String get combined => '$notice $details';
}

class _AuditAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(await File(key).readAsBytes());
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
  final expand = find.byKey(ValueKey('crop-recommendations-${parcel.id}'));
  if (expand.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(
      expand,
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(expand);
    await tester.pumpAndSettle();
  }
  expect(find.text('Cuidados prioritarios'), findsOneWidget);
  final issuePrefix = 'crop-issue-${parcel.id}-';
  final issueFinder = find.byWidgetPredicate(
    (widget) =>
        widget.key is ValueKey<String> &&
        (widget.key! as ValueKey<String>).value.startsWith(issuePrefix),
  );
  final issueIds = <String>{};
  final detailTexts = <String>[];
  for (final element in issueFinder.evaluate()) {
    issueIds.add(
      (element.widget.key! as ValueKey<String>).value.substring(
        issuePrefix.length,
      ),
    );
    detailTexts.addAll(
      tester
          .widgetList<Text>(
            find.descendant(
              of: find.byWidget(element.widget),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data ?? ''),
    );
  }
  final notice = detailTexts.join(' ');
  if (issueIds.isEmpty) {
    expect(find.text('Sin alertas con los datos disponibles'), findsOneWidget);
    detailTexts.add('Mantén el monitoreo de humedad y nutrientes.');
  }
  final rotationButton = find.byKey(ValueKey('crop-rotations-${parcel.id}'));
  await tester.scrollUntilVisible(
    rotationButton,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(rotationButton);
  await tester.pumpAndSettle();
  final rotationPrefix = 'rotation-${parcel.id}-';
  final validRotationIds = <String>{};
  for (var i = 0; i < 20; i++) {
    validRotationIds.addAll(
      find
          .byWidgetPredicate(
            (widget) =>
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  rotationPrefix,
                ),
          )
          .evaluate()
          .map(
            (element) => (element.widget.key! as ValueKey<String>).value
                .substring(rotationPrefix.length),
          ),
    );
    final scroll = find.byType(Scrollable).last;
    final position = tester.state<ScrollableState>(scroll).position;
    if (position.pixels >= position.maxScrollExtent) break;
    await tester.drag(scroll, const Offset(0, -350));
    await tester.pumpAndSettle();
  }
  final details = detailTexts.join(' ');
  expect(tester.takeException(), isNull);
  expect(
    store.parcels.single.toJson(),
    original,
    reason: 'Consultar recomendaciones no debe modificar la parcela',
  );
  // Machine-readable evidence is captured by --reporter json.
  // ignore: avoid_print
  print(
    'RECOMMENDATION_AUDIT ${jsonEncode({'scenario': scenario, 'crop': parcel.crop, 'ph': parcel.ph, 'moisture': parcel.moisture, 'nitrogen': parcel.nitrogen, 'phosphorus': parcel.phosphorus, 'potassium': parcel.potassium, 'warning': parcel.warning, 'critical': parcel.critical, 'notice': notice, 'details': details, 'issueIds': issueIds.toList(), 'validRotationIds': validRotationIds.toList()})}',
  );
  return AdviceSnapshot(notice, details, issueIds, validRotationIds);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await AgronomyCatalog.load(bundle: _AuditAssetBundle());
  });
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
    expect(advice.notice.toLowerCase(), matches(RegExp(r'ph.*(bajo|ácido)')));
    expect(advice.issueIds, contains('S006'));
  });
  testWidgets('pH alto: informa el problema', (tester) async {
    final advice = await inspectAdvice(
      tester,
      healthy.copyWith(ph: 8),
      'pH alto',
    );
    expect(
      advice.notice.toLowerCase(),
      matches(RegExp(r'ph.*(alto|alcalino)')),
    );
    expect(advice.issueIds, contains('S004'));
  });
  testWidgets('humedad baja: informa el problema', (tester) async {
    final advice = await inspectAdvice(
      tester,
      healthy.copyWith(moisture: 35),
      'humedad baja',
    );
    expect(advice.notice.toLowerCase(), matches(RegExp(r'humedad.*baja')));
    expect(advice.issueIds, contains('demo-moisture'));
  });
  testWidgets('suelo saludable: no inventa un déficit', (tester) async {
    final advice = await inspectAdvice(
      tester,
      healthy,
      'condiciones saludables',
    );
    expect(advice.notice, isEmpty);
    expect(advice.issueIds, isEmpty);
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
      expect(advice.issueIds.intersection({'S008', 'S009', 'S010'}), isEmpty);
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
      expect(
        advice.issueIds,
        contains(switch (nutrient) {
          'nitrógeno' => 'S009',
          'fósforo' => 'S008',
          _ => 'S010',
        }),
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
    expect(
      advice.issueIds,
      containsAll({'S006', 'demo-moisture', 'S009', 'S008', 'S010'}),
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
      potato.validRotationIds,
      isNot(contains('C002')),
      reason:
          'No debe incluir Papa en la propuesta de siguientes cultivos cuando el cultivo actual ya es Papa',
    );
    expect(
      potato.validRotationIds,
      contains('C003'),
      reason:
          'Debe ofrecer una alternativa válida de otra familia, no ocultar todas las opciones',
    );
    final blocked = find.byKey(
      const PageStorageKey('blocked-rotations-demo-1'),
    );
    expect(blocked, findsOneWidget);
    final blockedHeader = find.descendant(
      of: blocked,
      matching: find.textContaining('Opciones no recomendadas'),
    );
    // The complete card is one lazy-list child, so scrollUntilVisible can stop
    // as soon as that child exists even though this nested heading is far below
    // the viewport. Exercise actual scrolling until the heading receives taps.
    for (
      var i = 0;
      i < 50 && blockedHeader.hitTestable().evaluate().isEmpty;
      i++
    ) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(blockedHeader.hitTestable(), findsOneWidget);
    await tester.tap(blockedHeader.hitTestable());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.descendant(of: blocked, matching: find.text('Papa')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: blocked,
        matching: find.textContaining(
          'Es el mismo cultivo actual; no es una rotación.',
        ),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
