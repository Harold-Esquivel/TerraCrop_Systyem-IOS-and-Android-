import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:terracrop/data/agronomy_catalog.dart';
import 'package:terracrop/data/models.dart';
import 'package:terracrop/data/terra_store.dart';
import 'package:terracrop/main.dart';
import 'package:terracrop/screens/smart_cycle_screen.dart';

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    240,
    scrollable: find.byType(Scrollable).last,
    maxScrolls: 60,
  );
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(finder), alignment: .25);
  await tester.pumpAndSettle();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'informe multiparcela, cuidados y guardado PDF real',
    (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      await AgronomyCatalog.load();
      final fixtures = demoParcels();
      final store = TerraStore();
      await store.load();
      store.parcels = [
        fixtures[0].copyWith(
          soilAnalysis: const SoilAnalysis(
            organicMatter: 1.2,
            nitrogen: NutrientLevel.low,
          ),
        ),
        fixtures[1].copyWith(
          soilAnalysis: const SoilAnalysis(moistureLow: true, sandySoil: true),
        ),
        fixtures[2],
      ];
      final before = store.parcels.map((p) => p.toJson()).toList();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(value: store, child: const TerraCropApp()),
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.byKey(const Key('entry-login-button')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-tab-1')));
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      final all = find.byKey(const Key('cycle-select-all'));
      await reveal(tester, all);
      await tester.tap(all);
      await tester.pumpAndSettle();
      expect(find.text('3 de 3 seleccionadas'), findsOneWidget);
      await binding.takeScreenshot('01-todas-las-parcelas');
      final third = find.byKey(const Key('cycle-select-demo-3'));
      await reveal(tester, third);
      await tester.tap(third);
      await tester.pumpAndSettle();
      expect(find.text('2 de 3 seleccionadas'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cycle-show-results')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SmartCycleResultsScreen>(
              find.byType(SmartCycleResultsScreen),
            )
            .scenarios
            .length,
        2,
      );
      expect(find.text('2 parcelas simuladas'), findsOneWidget);
      expect(find.textContaining('Cómo se calcula'), findsNothing);
      await binding.takeScreenshot('02-informe-resultados');
      final organic = find.byKey(const Key('cycle-care-demo-1-S007'));
      await reveal(tester, organic);
      expect(find.textContaining('estiércol bien curado'), findsOneWidget);
      await binding.takeScreenshot('03-cuidados-por-parcela');
      await reveal(tester, find.byKey(const Key('cycle-care-demo-2-S011')));
      expect(find.byKey(const Key('cycle-result-demo-3')), findsNothing);
      await binding.takeScreenshot('04-segunda-parcela');
      await tester.tap(find.byKey(const Key('cycle-save-report')));
      await tester.pump();
      // The Android companion script completes the native Save dialog. Flutter
      // cannot tap system UI; the resulting PDF is pulled and checked separately.
      final deadline = DateTime.now().add(const Duration(seconds: 75));
      while (find.byKey(const Key('cycle-save-success')).evaluate().isEmpty &&
          DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.byKey(const Key('cycle-save-success')), findsOneWidget);
      await binding.takeScreenshot('05-pdf-guardado');
      expect(store.parcels.map((p) => p.toJson()).toList(), before);
      expect(tester.takeException(), isNull);
      binding.reportData ??= {};
      binding.reportData!['checks'] = {
        'selection': 'Todas: 3; elegidas para el informe: 2',
        'advice':
            'Materia orgánica y nitrógeno en la primera; riego en la segunda',
        'export': 'PDF guardado mediante el selector nativo de Android',
        'data': 'Parcelas originales conservadas',
      };
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
