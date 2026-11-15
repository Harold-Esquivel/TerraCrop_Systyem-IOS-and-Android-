import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:terracrop/data/agronomy_catalog.dart';
import 'package:terracrop/data/cloud_service.dart';
import 'package:terracrop/data/models.dart';
import 'package:terracrop/data/terra_store.dart';
import 'package:terracrop/main.dart';

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(finder, findsOneWidget);
}

/// Wait for native keyboard and viewport changes before relying on a tap.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  final scrollable = find.byType(Scrollable).last;
  await tester.scrollUntilVisible(
    finder,
    240,
    scrollable: scrollable,
    maxScrolls: 60,
  );
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(finder), alignment: .25);
  await tester.pumpAndSettle();
  for (
    var attempt = 0;
    attempt < 4 && finder.hitTestable().evaluate().isEmpty;
    attempt++
  ) {
    final target = tester.getCenter(finder);
    final viewport = tester.getRect(scrollable);
    await tester.drag(
      scrollable,
      Offset(0, target.dy > viewport.center.dy ? -140 : 140),
    );
    await tester.pumpAndSettle();
  }
  expect(
    finder.hitTestable(),
    findsOneWidget,
    reason: 'El control debe estar visible y recibir gestos',
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'cuidados puntuales, apariencia, análisis parcial y rotación en dispositivo',
    (tester) async {
      // Never initialise Firebase, notifications or the app's normal main(). All
      // preferences used by this test live only in this Dart process's memory.
      expect(CloudService.instance.connected, isFalse);
      final previousPreferences = SharedPreferencesAsyncPlatform.instance;
      final memoryPreferences = InMemorySharedPreferencesAsync.empty();
      SharedPreferencesAsyncPlatform.instance = memoryPreferences;
      addTearDown(() {
        if (previousPreferences != null) {
          SharedPreferencesAsyncPlatform.instance = previousPreferences;
        }
      });

      final catalog = await AgronomyCatalog.load();
      expect(catalog.crops.length, 13);
      expect(catalog.compatibility.length, 169);
      expect(
        catalog.compatibility
            .map((p) => '${p.previousId}:${p.nextId}')
            .toSet()
            .length,
        169,
      );
      expect(catalog.findCrop('Papa')?.family, 'Solanaceae');

      final store = TerraStore();
      await store.load();
      final fixture = Parcel(
        id: 'qa-agronomy',
        name: 'Parcela QA · Papa',
        crop: 'Papa',
        points: demoParcels().first.points,
        ph: 6.5,
        moisture: 20,
        nitrogen: 20,
        phosphorus: 20,
        potassium: 20,
        cropHistory: const ['Cebolla'],
        soilAnalysis: const SoilAnalysis(
          ph: 6.5,
          ec: 0.5,
          organicMatter: 1.2,
          nitrogen: NutrientLevel.low,
          phosphorus: NutrientLevel.low,
          potassium: NutrientLevel.low,
          moistureLow: true,
          sandySoil: true,
          waterlogged: false,
          soilDiseaseHistory: false,
        ),
      );
      store.parcels = [fixture];
      final original = fixture.toJson();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(value: store, child: const TerraCropApp()),
      );
      final login = find.byKey(const Key('entry-login-button'));
      await waitFor(tester, login);
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(login.hitTestable());
      await waitFor(tester, find.byKey(const Key('nav-tab-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-tab-2')).hitTestable());
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();

      // Only three actions appear initially; the remaining two are opt-in.
      expect(find.text('5 acciones para esta parcela'), findsOneWidget);
      for (final issue in ['S011', 'S007', 'S009']) {
        expect(
          find.byKey(Key('crop-issue-qa-agronomy-$issue')),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(const Key('crop-issue-qa-agronomy-S008')),
        findsNothing,
      );
      expect(find.textContaining('Excel'), findsNothing);
      await binding.takeScreenshot('care-01-cultivos-claro');
      final recommendations = find.byKey(
        const Key('crop-recommendations-qa-agronomy'),
      );
      await reveal(tester, recommendations);
      await tester.tap(recommendations.hitTestable());
      await tester.pumpAndSettle();
      for (final issue in ['S011', 'S007', 'S009', 'S008', 'S010']) {
        expect(
          find.byKey(Key('crop-issue-qa-agronomy-$issue')),
          findsOneWidget,
        );
      }
      await reveal(tester, find.text('Refuerza el fósforo'));
      await binding.takeScreenshot('care-02-cuidados-adicionales');
      expect(store.parcels.single.toJson(), original);

      // Check the same care cards in the persistent dark theme.
      await tester.tap(find.byKey(const Key('nav-tab-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile-theme-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-tab-2')));
      await tester.pumpAndSettle();
      await reveal(tester, recommendations);
      await tester.tap(recommendations.hitTestable());
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Cuidados prioritarios'));
      await binding.takeScreenshot('care-03-cultivos-oscuro');

      // A partial analysis replaces the old one, rather than inheriting its
      // organic matter, nutrient levels or demo indices.
      final analysisButton = find.byKey(const Key('crop-analysis-qa-agronomy'));
      // Use an empty in-memory analysis to exercise first-time data entry.
      await store.updateParcel(
        fixture.copyWith(soilAnalysis: const SoilAnalysis()),
      );
      await tester.pumpAndSettle();
      await reveal(tester, analysisButton);
      await tester.tap(analysisButton.hitTestable());
      await tester.pumpAndSettle();
      final ph = find.byKey(const Key('analysis-ph'));
      await reveal(tester, ph);
      await tester.enterText(ph, '6,5');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final save = find.byKey(const Key('analysis-save'));
      await reveal(tester, save);
      await tester.tap(save.hitTestable());
      await tester.pumpAndSettle();
      final updated = store.parcels.single;
      expect(updated.soilAnalysis?.ph, 6.5);
      expect(updated.soilAnalysis?.ec, isNull);
      expect(updated.soilAnalysis?.organicMatter, isNull);
      expect(updated.soilAnalysis?.nitrogen, NutrientLevel.unknown);
      expect(updated.soilAnalysis?.phosphorus, NutrientLevel.unknown);
      expect(updated.soilAnalysis?.potassium, NutrientLevel.unknown);
      expect(updated.cropHistory, fixture.cropHistory);
      expect(updated.points, fixture.points);
      expect(updated.crop, 'Papa');
      for (final issue in [
        'S007',
        'S009',
        'S008',
        'S010',
        'S011',
        'demo-moisture',
      ]) {
        expect(find.byKey(Key('crop-issue-qa-agronomy-$issue')), findsNothing);
      }
      await reveal(tester, find.text('Cuidados prioritarios'));
      await binding.takeScreenshot('care-04-datos-por-completar');

      final rotations = find.byKey(const Key('crop-rotations-qa-agronomy'));
      await reveal(tester, rotations);
      await tester.tap(rotations.hitTestable());
      await tester.pumpAndSettle();
      for (final crop in ['C002', 'C006', 'C012']) {
        expect(find.byKey(Key('rotation-qa-agronomy-$crop')), findsNothing);
      }
      expect(
        find.byKey(const Key('rotation-qa-agronomy-C003')),
        findsOneWidget,
      );
      expect(find.textContaining('Excel'), findsNothing);
      await binding.takeScreenshot('care-05-rotaciones');

      // Reload from the explicitly substituted, in-memory preferences to verify
      // persistence without touching any real Android app data.
      expect(
        identical(SharedPreferencesAsyncPlatform.instance, memoryPreferences),
        isTrue,
      );
      final reloaded = TerraStore();
      await reloaded.load();
      expect(reloaded.parcels.single.id, fixture.id);
      expect(reloaded.parcels.single.soilAnalysis?.ph, 6.5);
      expect(
        reloaded.parcels.single.soilAnalysis?.nitrogen,
        NutrientLevel.unknown,
      );
      expect(reloaded.parcels.single.cropHistory, fixture.cropHistory);
      expect(reloaded.parcels.single.points, fixture.points);
      expect(CloudService.instance.connected, isFalse);
      expect(tester.takeException(), isNull);
      binding.reportData ??= {};
      binding.reportData!['checks'] = {
        'catalog': '13 cultivos y 169 pares únicos',
        'combinedDeficits':
            'Tres cuidados prioritarios; otros dos disponibles al abrirlos',
        'presentation': 'Sin referencias al Excel; claro y oscuro comprobados',
        'partialAnalysis': 'pH 6,5; NPK y CE desconocidos, sin fallback demo',
        'rotation': 'excluye Papa y Solanaceae; opciones válidas presentes',
        'history': 'conservado sin cambios',
        'storage': 'SharedPreferencesAsync sustituido por memoria; sin nube',
      };
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
      reloaded.dispose();
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
