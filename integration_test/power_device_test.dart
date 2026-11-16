import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:terracrop/app/app_theme.dart';
import 'package:terracrop/data/agronomy_catalog.dart';
import 'package:terracrop/data/models.dart';
import 'package:terracrop/data/terra_store.dart';
import 'package:terracrop/screens/campaign_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('POWER integrado en una campaña Android con selección explícita', (
    tester,
  ) async {
    await AgronomyCatalog.load();
    final previousPreferences = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(
      () => SharedPreferencesAsyncPlatform.instance = previousPreferences,
    );
    final store = TerraStore()
      ..parcels = [demoParcels().first.copyWith(clearSoilAnalysis: true)];
    addTearDown(store.dispose);
    final before = store.parcels.single.toJson();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(theme: appTheme, home: const CampaignScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    final scrollable = find.byType(Scrollable).first;
    Future<void> reveal(Finder finder) async {
      await tester.scrollUntilVisible(finder, 180, scrollable: scrollable);
      await Scrollable.ensureVisible(tester.element(finder), alignment: .3);
      await tester.pumpAndSettle();
    }

    final toggle = find.byKey(const Key('campaign-regional-climate'));
    await reveal(toggle);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    await binding.takeScreenshot('power-01-reference-selection');
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    final evaluate = find.byKey(const Key('campaign-evaluate'));
    await reveal(evaluate);
    await tester.tap(evaluate);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    final card = find.byType(CampaignResultCard);
    await reveal(card);
    final evaluation = tester.widget<CampaignResultCard>(card).evaluation;
    expect(evaluation.climate.any((c) => c.source.id == 'power_T2M'), isTrue);
    expect(evaluation.climate.any((c) => c.source.id == 'power_WS2M'), isTrue);
    expect(evaluation.forecasts, isEmpty);
    expect(evaluation.input.parcel.soilAnalysis, isNull);
    expect(store.parcels.single.toJson(), before);
    final provenance = find.text('Datos climáticos y procedencia');
    await reveal(provenance);
    await tester.tap(provenance);
    await tester.pumpAndSettle();
    // The visible climate uses human variable names and its historical period.
    expect(find.textContaining('POWER 2015–2025'), findsWidgets);
    await binding.takeScreenshot('power-02-history-and-provenance');
    expect(tester.takeException(), isNull);
    binding.reportData = {
      ...?binding.reportData,
      'checks': {
        'powerClimatology':
            '2015–2025, siete variables, sin coordenadas exactas',
        'activation': 'Referencia seleccionada explícitamente',
        'units': 'Lluvia mensual, radiación kWh/m²/día y viento m/s',
        'soilAndForecasts': 'Sin análisis de suelo inventado ni pronósticos',
        'parcel': 'Sin modificar datos de parcela',
      },
    };
  });
}
