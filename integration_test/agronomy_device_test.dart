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
import 'package:terracrop/screens/soil_analysis_editor.dart';

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(finder, findsOneWidget);
}

/// Wait for native keyboard and viewport changes before relying on a tap.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  final scrollable = find.byType(Scrollable).first;
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
    'base Excel, déficits, análisis parcial y rotación en dispositivo',
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
        ph: 5.3,
        moisture: 20,
        nitrogen: 20,
        phosphorus: 20,
        potassium: 20,
        cropHistory: const ['Cebolla'],
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

      // The overview must name all five simultaneous problems, not just pH.
      final summary = find.byKey(const Key('crop-issue-summary-qa-agronomy'));
      await waitFor(tester, summary);
      expect(
        tester.widget<Text>(summary).data!.toLowerCase(),
        allOf(
          contains('ph'),
          contains('humedad'),
          contains('nitrógeno'),
          contains('fósforo'),
          contains('potasio'),
        ),
      );
      await binding.takeScreenshot('01-cultivos-base-excel');
      final recommendations = find.byKey(
        const Key('crop-recommendations-qa-agronomy'),
      );
      await reveal(tester, recommendations);
      await tester.tap(recommendations.hitTestable());
      await tester.pumpAndSettle();
      for (final issue in ['S006', 'demo-moisture', 'S009', 'S008', 'S010']) {
        expect(
          find.byKey(Key('crop-issue-qa-agronomy-$issue')),
          findsOneWidget,
        );
      }
      await reveal(tester, find.text('Diagnóstico y acciones'));
      await binding.takeScreenshot('02-deficits-combinados');
      expect(
        store.parcels.single.toJson(),
        original,
        reason: 'La consulta no debe modificar la parcela',
      );

      // Enter a partial analysis. Missing laboratory values must remain unknown,
      // even though the old demo indices still contain severe deficiencies.
      final analysisButton = find.byKey(const Key('crop-analysis-qa-agronomy'));
      await reveal(tester, analysisButton);
      await tester.tap(analysisButton.hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(SoilAnalysisEditor), findsOneWidget);
      final ph = find.byKey(const Key('analysis-ph'));
      await reveal(tester, ph);
      await tester.enterText(ph, '6,5');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('03-analisis-parcial');
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
      expect(
        updated.nitrogen,
        20,
        reason:
            'No convertir referencias kg/ha en índices ni modificar los datos originales',
      );
      expect(find.text('Análisis ingresado'), findsOneWidget);
      expect(find.text('Datos por completar'), findsWidgets);
      expect(find.text('20/100 · demo'), findsNothing);
      for (final issue in ['S009', 'S008', 'S010', 'demo-moisture']) {
        expect(find.byKey(Key('crop-issue-qa-agronomy-$issue')), findsNothing);
      }
      await reveal(tester, find.text('Análisis ingresado'));
      await binding.takeScreenshot('04-datos-por-completar');

      // Papa, tomato and pepper share the current family and must not be offered
      // as the next rotation; the allowed list must also be non-empty.
      for (final crop in ['C002', 'C006', 'C012']) {
        expect(find.byKey(Key('rotation-qa-agronomy-$crop')), findsNothing);
      }
      expect(
        find.byKey(const Key('rotation-qa-agronomy-C003')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('rotation-qa-agronomy-C008')),
        findsOneWidget,
      );
      await reveal(tester, find.text('¿Qué cultivar después?'));
      await binding.takeScreenshot('05-rotaciones-condicionadas');
      await reveal(tester, find.text('Ficha del cultivo en el Excel'));
      await tester.tap(
        find.text('Ficha del cultivo en el Excel').hitTestable(),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Referencias N / P₂O₅ / K₂O (kg/ha)'));
      await binding.takeScreenshot('06-ficha-unidades-y-fuentes');

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
        'combinedDeficits': 'pH, humedad, N, P y K visibles',
        'partialAnalysis': 'pH 6,5; NPK y CE desconocidos, sin fallback demo',
        'rotation': 'excluye Papa y Solanaceae; opciones válidas presentes',
        'history': 'conservado sin cambios',
        'storage': 'SharedPreferencesAsync sustituido por memoria; sin nube',
      };
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
      reloaded.dispose();
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
