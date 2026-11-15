import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:terracrop/app/app_theme.dart';
import 'package:terracrop/data/agronomy_catalog.dart';
import 'package:terracrop/data/models.dart';
import 'package:terracrop/data/terra_store.dart';
import 'package:terracrop/screens/crops_screen.dart';
import 'package:terracrop/screens/soil_analysis_editor.dart';

Widget cropsWith(TerraStore store) => ChangeNotifierProvider.value(
  value: store,
  child: MaterialApp(
    theme: appTheme,
    home: const Scaffold(body: SafeArea(child: CropsScreen())),
  ),
);

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 80,
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await AgronomyCatalog.load();
  });
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('muestra juntos pH, agua, N, P y K sin cambiar la parcela', (
    tester,
  ) async {
    final parcel = demoParcels().first.copyWith(
      ph: 5.3,
      moisture: 20,
      nitrogen: 20,
      phosphorus: 20,
      potassium: 20,
    );
    final original = parcel.toJson();
    final store = TerraStore()..parcels = [parcel];
    await tester.pumpWidget(cropsWith(store));
    await tester.pumpAndSettle();
    final summary = tester
        .widget<Text>(find.byKey(const Key('crop-issue-summary-demo-1')))
        .data!;
    expect(
      summary.toLowerCase(),
      allOf(
        contains('ph'),
        contains('humedad'),
        contains('nitrógeno'),
        contains('fósforo'),
        contains('potasio'),
      ),
    );
    final toggle = find.byKey(const Key('crop-recommendations-demo-1'));
    await reveal(tester, toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    for (final id in ['S006', 'demo-moisture', 'S009', 'S008', 'S010']) {
      expect(find.byKey(Key('crop-issue-demo-1-$id')), findsOneWidget);
    }
    expect(store.parcels.single.toJson(), original);
    expect(tester.takeException(), isNull);
  });

  testWidgets('análisis parcial no hereda los índices NPK de demostración', (
    tester,
  ) async {
    final parcel = demoParcels().first.copyWith(
      nitrogen: 0,
      phosphorus: 0,
      potassium: 0,
      soilAnalysis: const SoilAnalysis(ph: 6.5),
    );
    final store = TerraStore()..parcels = [parcel];
    await tester.pumpWidget(cropsWith(store));
    await tester.pumpAndSettle();
    expect(find.text('Análisis ingresado'), findsOneWidget);
    expect(find.text('0/100 · demo'), findsNothing);
    final toggle = find.byKey(const Key('crop-recommendations-demo-1'));
    await reveal(tester, toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    for (final id in ['S009', 'S008', 'S010']) {
      expect(find.byKey(Key('crop-issue-demo-1-$id')), findsNothing);
    }
    expect(
      find.textContaining('Falta diagnóstico de nitrógeno'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('rotación desde Papa no ofrece Papa ni otra solanácea', (
    tester,
  ) async {
    final parcel = demoParcels().first.copyWith(
      crop: 'Papa',
      ph: 6.5,
      nitrogen: 20,
    );
    final store = TerraStore()..parcels = [parcel];
    await tester.pumpWidget(cropsWith(store));
    await tester.pumpAndSettle();
    final toggle = find.byKey(const Key('crop-recommendations-demo-1'));
    await reveal(tester, toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    for (final id in ['C002', 'C006', 'C012']) {
      expect(find.byKey(Key('rotation-demo-1-$id')), findsNothing);
    }
    expect(find.byKey(const Key('rotation-demo-1-C008')), findsOneWidget);
    expect(
      find.textContaining('No hay campañas anteriores registradas.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor rechaza pH inválido y guarda un análisis parcial', (
    tester,
  ) async {
    final store = TerraStore()..parcels = [demoParcels().first];
    await tester.pumpWidget(cropsWith(store));
    await tester.pumpAndSettle();
    final edit = find.byKey(const Key('crop-analysis-demo-1'));
    await reveal(tester, edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(find.byType(SoilAnalysisEditor), findsOneWidget);
    await tester.enterText(find.byKey(const Key('analysis-ph')), '15');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const Key('analysis-save')));
    await tester.tap(find.byKey(const Key('analysis-save')));
    await tester.pumpAndSettle();
    expect(store.parcels.single.soilAnalysis, isNull);
    expect(find.text('Ingresa un valor entre 0.0 y 14.0'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('analysis-ph')));
    await tester.enterText(find.byKey(const Key('analysis-ph')), '6,5');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const Key('analysis-save')));
    await tester.tap(find.byKey(const Key('analysis-save')));
    await tester.pumpAndSettle();
    expect(store.parcels.single.soilAnalysis?.ph, 6.5);
    expect(store.parcels.single.soilAnalysis?.nitrogen, NutrientLevel.unknown);
    expect(store.parcels.single.soilAnalysis?.ec, isNull);
    expect(find.text('Análisis ingresado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recomendaciones y biblioteca caben a 320 píxeles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final parcel = demoParcels().first.copyWith(
      crop: 'Papa',
      soilAnalysis: const SoilAnalysis(
        ph: 8.6,
        ec: 4.5,
        organicMatter: 1.2,
        nitrogen: NutrientLevel.low,
        phosphorus: NutrientLevel.low,
        potassium: NutrientLevel.low,
        moistureLow: true,
        sandySoil: true,
        waterlogged: true,
        soilDiseaseHistory: true,
      ),
    );
    final store = TerraStore()..parcels = [parcel];
    await tester.pumpWidget(cropsWith(store));
    await tester.pumpAndSettle();
    final toggle = find.byKey(const Key('crop-recommendations-demo-1'));
    await reveal(tester, toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await reveal(tester, find.text('¿Qué cultivar después?'));
    expect(tester.takeException(), isNull);
    await reveal(tester, find.text('Ficha del cultivo en el Excel'));
    await tester.tap(find.text('Ficha del cultivo en el Excel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await reveal(tester, find.text('Base agronómica del Excel'));
    await tester.tap(find.text('Secuencias de rotación de referencia'));
    await tester.pumpAndSettle();
    expect(find.textContaining('S00 ·'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
