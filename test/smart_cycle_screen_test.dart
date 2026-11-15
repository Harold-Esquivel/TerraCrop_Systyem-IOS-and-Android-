import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:terracrop/app/app_theme.dart';
import 'package:terracrop/data/models.dart';
import 'package:terracrop/data/terra_store.dart';
import 'package:terracrop/screens/smart_cycle_screen.dart';

Widget cycleWith(TerraStore store) => ChangeNotifierProvider.value(
  value: store,
  child: MaterialApp(
    theme: appTheme,
    home: const Scaffold(body: SafeArea(child: SmartCycleScreen())),
  ),
);

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
      await tester.scrollUntilVisible(
        find.byKey(const Key('cycle-window-result')),
        250,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 25,
      );
      expect(find.byKey(const Key('cycle-window-result')), findsOneWidget);
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
    expect(tester.takeException(), isNull);
  });
}
