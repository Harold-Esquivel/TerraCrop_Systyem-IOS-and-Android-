import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:terracrop/app/app_theme.dart';
import 'package:terracrop/data/models.dart';
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

void main() {
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
      await tester.scrollUntilVisible(
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
      'Cómo se calcula',
    ]) {
      await tester.scrollUntilVisible(
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
      await tester.scrollUntilVisible(
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
}
