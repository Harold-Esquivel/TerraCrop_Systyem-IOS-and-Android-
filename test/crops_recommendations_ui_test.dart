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

Widget cropsWith(TerraStore store, {bool dark = false}) =>
    ChangeNotifierProvider.value(
      value: store,
      child: MaterialApp(
        theme: dark ? appDarkTheme : appTheme,
        home: const Scaffold(body: SafeArea(child: CropsScreen())),
      ),
    );

Future<void> reveal(
  WidgetTester tester,
  Finder finder, {
  bool sheet = false,
}) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: sheet
        ? find.byType(Scrollable).last
        : find.byType(Scrollable).first,
    maxScrolls: 80,
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => AgronomyCatalog.load());
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  testWidgets(
    'tres cuidados prioritarios y el resto bajo demanda, sin referencias al Excel',
    (tester) async {
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
      expect(find.text('5 acciones para esta parcela'), findsOneWidget);
      expect(find.byKey(const Key('crop-issue-demo-1-S006')), findsOneWidget);
      expect(
        find.byKey(const Key('crop-issue-demo-1-demo-moisture')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('crop-issue-demo-1-S009')), findsOneWidget);
      expect(find.byKey(const Key('crop-issue-demo-1-S008')), findsNothing);
      expect(find.byKey(const Key('crop-issue-demo-1-S010')), findsNothing);
      expect(
        find.textContaining(
          RegExp('Excel|Base agronómica', caseSensitive: false),
        ),
        findsNothing,
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
    },
  );

  testWidgets(
    'análisis parcial no hereda nutrientes de demostración ni recomienda estiércol',
    (tester) async {
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
      expect(find.text('Datos de ejemplo'), findsNothing);
      for (final id in ['S007', 'S009', 'S008', 'S010']) {
        expect(find.byKey(Key('crop-issue-demo-1-$id')), findsNothing);
      }
      expect(
        find.text('Completa los datos para afinar tus cuidados'),
        findsOneWidget,
      );
      expect(find.textContaining('estiércol'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rotación aparte excluye Papa y otras solanáceas', (
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
    final rotations = find.byKey(const Key('crop-rotations-demo-1'));
    await reveal(tester, rotations);
    await tester.tap(rotations);
    await tester.pumpAndSettle();
    expect(find.text('Próxima siembra'), findsOneWidget);
    for (final id in ['C002', 'C006', 'C012']) {
      expect(find.byKey(Key('rotation-demo-1-$id')), findsNothing);
    }
    await reveal(
      tester,
      find.byKey(const Key('rotation-demo-1-C008')),
      sheet: true,
    );
    expect(find.byKey(const Key('rotation-demo-1-C008')), findsOneWidget);
    expect(find.textContaining('Excel'), findsNothing);
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

  testWidgets('cada parcela muestra su propio cuidado sin modificar otras', (
    tester,
  ) async {
    final first = demoParcels().first.copyWith(
      soilAnalysis: const SoilAnalysis(organicMatter: 1.2),
    );
    final second = demoParcels()[1].copyWith(
      soilAnalysis: const SoilAnalysis(moistureLow: true, sandySoil: true),
    );
    final store = TerraStore()..parcels = [first, second];
    final before = store.parcels.map((p) => p.toJson()).toList();
    await tester.pumpWidget(cropsWith(store));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(ValueKey(first.id)),
        matching: find.text('Refuerza la materia orgánica'),
      ),
      findsOneWidget,
    );
    await reveal(tester, find.byKey(ValueKey(second.id)));
    expect(
      find.descendant(
        of: find.byKey(ValueKey(second.id)),
        matching: find.text('Ajusta el riego'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(ValueKey(second.id)),
        matching: find.text('Refuerza la materia orgánica'),
      ),
      findsNothing,
    );
    expect(store.parcels.map((p) => p.toJson()).toList(), before);
  });

  testWidgets(
    'actualizar la materia orgánica retira el cuidado y guarda el dato',
    (tester) async {
      final parcel = demoParcels().first.copyWith(
        soilAnalysis: const SoilAnalysis(organicMatter: 1.2),
      );
      final store = TerraStore()..parcels = [parcel];
      await tester.pumpWidget(cropsWith(store));
      await tester.pumpAndSettle();
      expect(find.text('Refuerza la materia orgánica'), findsOneWidget);
      final edit = find.byKey(const Key('crop-analysis-demo-1'));
      await reveal(tester, edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('analysis-organic-matter')),
        '3.0',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const Key('analysis-save')));
      await tester.tap(find.byKey(const Key('analysis-save')));
      await tester.pumpAndSettle();
      expect(find.text('Refuerza la materia orgánica'), findsNothing);
      final reloaded = TerraStore();
      await reloaded.load();
      expect(reloaded.parcels.single.soilAnalysis?.organicMatter, 3);
      expect(reloaded.parcels.single.crop, parcel.crop);
      expect(reloaded.parcels.single.points, parcel.points);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'cuidados y rotación caben a 320 píxeles en modo ${dark ? 'oscuro' : 'claro'}',
      (tester) async {
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
        await tester.pumpWidget(
          cropsWith(TerraStore()..parcels = [parcel], dark: dark),
        );
        await tester.pumpAndSettle();
        final toggle = find.byKey(const Key('crop-recommendations-demo-1'));
        await reveal(tester, toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        final rotations = find.byKey(const Key('crop-rotations-demo-1'));
        await reveal(tester, rotations);
        await tester.tap(rotations);
        await tester.pumpAndSettle();
        expect(find.text('Próxima siembra'), findsOneWidget);
        expect(find.textContaining('Excel'), findsNothing);
      },
    );
  }
}
