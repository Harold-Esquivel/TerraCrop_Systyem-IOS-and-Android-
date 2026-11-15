import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:terracrop/app/app_theme.dart';
import 'package:terracrop/data/models.dart';
import 'package:terracrop/data/agronomy_catalog.dart';
import 'package:terracrop/data/simulation_report.dart';
import 'package:terracrop/data/crop_simulation.dart';
import 'package:terracrop/data/terra_store.dart';
import 'package:terracrop/screens/smart_cycle_screen.dart';

Widget cycleWith(TerraStore store) => ChangeNotifierProvider.value(
  value: store,
  child: MaterialApp(
    theme: appTheme,
    home: const Scaffold(body: SafeArea(child: SmartCycleScreen())),
  ),
);

Future<void> openResults(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('cycle-show-results')));
  await tester.pump();
  await tester.pump(const Duration(seconds: 3));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> revealCycle(
  WidgetTester tester,
  Finder finder,
  double delta, {
  Finder? scrollable,
  int maxScrolls = 50,
}) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: scrollable,
    maxScrolls: maxScrolls,
  );
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(finder), alignment: .3);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => AgronomyCatalog.load());
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  testWidgets(
    'los eventos y condiciones simuladas no sobrescriben la parcela',
    (tester) async {
      final store = TerraStore()..parcels = demoParcels();
      final before = store.parcels.map((p) => p.toJson()).toList();
      await tester.pumpWidget(cycleWith(store));
      final drought = find.byKey(const Key('cycle-event-drought'));
      await revealCycle(
        tester,
        drought,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(drought);
      await tester.pump();
      expect(tester.widget<FilterChip>(drought).selected, isFalse);
      final irrigation = find.byKey(const Key('cycle-event-irrigation'));
      await tester.tap(irrigation);
      await tester.pump();
      expect(tester.widget<FilterChip>(irrigation).selected, isTrue);
      await openResults(tester);
      expect(find.byKey(const Key('cycle-window-result')), findsOneWidget);
      expect(find.byKey(const Key('cycle-result-events')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('cycle-result-events'))).data,
        'Riego',
      );
      expect(store.parcels.map((p) => p.toJson()).toList(), before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('resultados, gráfica y estadística caben en pantalla compacta', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = TerraStore()..parcels = demoParcels();
    await tester.pumpWidget(cycleWith(store));
    await openResults(tester);
    for (final label in [
      'Evolución de la condición',
      'Estadística por día',
      'Cambiar escenario',
    ]) {
      await revealCycle(
        tester,
        find.text(label),
        200,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 35,
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: label);
    }
  });

  testWidgets('sin parcelas pide crearlas antes de simular', (tester) async {
    await tester.pumpWidget(cycleWith(TerraStore()));
    expect(
      find.text('Crea una parcela en MAPA para comenzar la simulación.'),
      findsOneWidget,
    );
    expect(find.byType(Slider), findsNothing);
    expect(find.byKey(const Key('cycle-show-results')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'espera tres segundos con plantas antes de mostrar el resultado',
    (tester) async {
      final store = TerraStore()..parcels = demoParcels();
      await tester.pumpWidget(cycleWith(store));
      expect(find.byKey(const Key('cycle-window-result')), findsNothing);
      await tester.tap(find.byKey(const Key('cycle-show-results')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('cycle-loading')), findsOneWidget);
      expect(find.byKey(const Key('growing-plants')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2999));
      expect(find.byKey(const Key('cycle-loading')), findsOneWidget);
      expect(find.byKey(const Key('cycle-window-result')), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(const Key('cycle-loading')), findsNothing);
      expect(find.byKey(const Key('cycle-window-result')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'volver durante la carga cancela el resultado y permite otra simulación',
    (tester) async {
      final store = TerraStore()..parcels = demoParcels();
      await tester.pumpWidget(cycleWith(store));
      await tester.tap(find.byKey(const Key('cycle-show-results')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      expect(find.byKey(const Key('cycle-loading')), findsNothing);
      expect(find.byType(SmartCycleResultsScreen), findsNothing);
      expect(find.byKey(const Key('cycle-show-results')), findsOneWidget);
      await openResults(tester);
      expect(find.byKey(const Key('cycle-window-result')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'el resultado conserva el escenario elegido y volver permite cambiarlo',
    (tester) async {
      final store = TerraStore()..parcels = demoParcels();
      await tester.pumpWidget(cycleWith(store));
      final drought = find.byKey(const Key('cycle-event-drought'));
      await revealCycle(
        tester,
        drought,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(drought);
      await tester.pump();
      tester
          .widget<Slider>(find.byKey(const Key('cycle-intensity')))
          .onChanged!(.8);
      tester.widget<Slider>(find.byKey(const Key('cycle-days'))).onChanged!(12);
      await revealCycle(
        tester,
        find.byKey(const Key('cycle-harvest')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      tester.widget<Slider>(find.byKey(const Key('cycle-harvest'))).onChanged!(
        5,
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('cycle-show-results')));
      await tester.pump();
      await tester.pump();
      final snapshot = tester
          .widget<SmartCycleResultsScreen>(find.byType(SmartCycleResultsScreen))
          .input;
      expect(snapshot.events, isEmpty);
      expect(snapshot.days, 12);
      expect(snapshot.daysToHarvest, 5);
      expect(snapshot.intensity, .8);
      // A provider refresh while loading cannot replace the captured input.
      store.parcels = [store.parcels.first.copyWith(name: 'Nombre cambiado')];
      store.notifyListeners();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.widget<Text>(find.byKey(const Key('cycle-result-events'))).data,
        'Sin eventos adicionales',
      );
      expect(find.text('Parcela Norte · Maíz'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('cycle-result-settings')))
            .data,
        'Intensidad: 80% · Horizonte: 12 días · Cosecha prevista: día 5',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await revealCycle(
        tester,
        drought,
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<FilterChip>(drought).selected, isFalse);
      await tester.tap(drought);
      await tester.pump();
      await openResults(tester);
      final updated = tester
          .widget<SmartCycleResultsScreen>(find.byType(SmartCycleResultsScreen))
          .input;
      expect(updated.events, {SimulationEvent.drought});
      expect(updated.parcel.name, 'Nombre cambiado');
    },
  );

  testWidgets(
    'selecciona varias o todas y desactiva generar cuando no hay ninguna',
    (tester) async {
      final store = TerraStore()..parcels = demoParcels();
      await tester.pumpWidget(cycleWith(store));
      final all = find.byKey(const Key('cycle-select-all'));
      await revealCycle(
        tester,
        all,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(all);
      await tester.pump();
      await openResults(tester);
      final screen = tester.widget<SmartCycleResultsScreen>(
        find.byType(SmartCycleResultsScreen),
      );
      expect(screen.scenarios.length, 3);
      expect(find.text('3 parcelas simuladas'), findsOneWidget);
      expect(find.textContaining('Cómo se calcula'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await revealCycle(
        tester,
        all,
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(all);
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('cycle-show-results')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('cycle-select-demo-1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cycle-select-demo-2')));
      await tester.pump();
      await openResults(tester);
      expect(
        tester
            .widget<SmartCycleResultsScreen>(
              find.byType(SmartCycleResultsScreen),
            )
            .scenarios
            .length,
        2,
      );
    },
  );

  testWidgets('cada parcela conserva su propia fecha de cosecha', (
    tester,
  ) async {
    final parcels = demoParcels().take(2).toList();
    await tester.pumpWidget(cycleWith(TerraStore()..parcels = parcels));
    final all = find.byKey(const Key('cycle-select-all'));
    await revealCycle(
      tester,
      all,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(all);
    await tester.pumpAndSettle();
    final harvest = find.byKey(const Key('cycle-harvest'));
    await revealCycle(
      tester,
      harvest,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    tester.widget<Slider>(harvest).onChanged!(7);
    await tester.pump();
    final dropdown = find.byKey(const Key('cycle-parcel-demo-1'));
    await revealCycle(
      tester,
      dropdown,
      -180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('${parcels[1].name} · ${parcels[1].crop}').last);
    await tester.pumpAndSettle();
    tester.widget<Slider>(harvest).onChanged!(21);
    await tester.pump();
    await openResults(tester);
    final scenarios = tester
        .widget<SmartCycleResultsScreen>(find.byType(SmartCycleResultsScreen))
        .scenarios;
    expect(scenarios.map((s) => s.input.daysToHarvest), [7, 21]);
  });

  for (final outcome in ['guardado', 'cancelado', 'error']) {
    testWidgets(
      'guardar PDF: $outcome conserva el informe y permite volver a intentarlo',
      (tester) async {
        final parcel = demoParcels().first;
        SimulationReport? captured;
        var calls = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: appDarkTheme,
            home: SmartCycleResultsScreen(
              scenarios: [
                SimulationScenario(
                  source: parcel,
                  input: SimulationInput(parcel: parcel),
                ),
              ],
              saveReport: (report) async {
                captured = report;
                calls++;
                if (outcome == 'error') throw Exception('fallo simulado');
                return outcome == 'guardado';
              },
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        final save = find.byKey(const Key('cycle-save-report'));
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(captured?.parcels.single.scenario.source.id, parcel.id);
        expect(
          find.byKey(const Key('cycle-save-success')),
          outcome == 'guardado' ? findsOneWidget : findsNothing,
        );
        expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
        if (outcome == 'error') {
          expect(
            find.text('No se pudo guardar el informe. Vuelve a intentarlo.'),
            findsOneWidget,
          );
        }
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(calls, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
