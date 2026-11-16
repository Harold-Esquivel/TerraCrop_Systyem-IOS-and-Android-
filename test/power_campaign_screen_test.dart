import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:terracrop/app/app_theme.dart';
import 'package:terracrop/data/agronomy_catalog.dart';
import 'package:terracrop/data/environment_repository.dart';
import 'package:terracrop/data/models.dart';
import 'package:terracrop/data/terra_store.dart';
import 'package:terracrop/screens/campaign_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late EnvironmentRepository environment;
  setUpAll(() async {
    await AgronomyCatalog.load();
    environment = await EnvironmentRepository.load();
  });
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'la campaña incorpora POWER solo al elegir la referencia histórica',
    (tester) async {
      final store = TerraStore()
        ..parcels = [demoParcels().first.copyWith(clearSoilAnalysis: true)];
      addTearDown(store.dispose);
      final before = store.parcels.single.toJson();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: store,
          child: MaterialApp(
            theme: appTheme,
            home: CampaignScreen(environment: Future.value(environment)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> reveal(Finder finder) async {
        await tester.scrollUntilVisible(
          finder,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(finder), alignment: .3);
        await tester.pumpAndSettle();
      }

      final switchFinder = find.byKey(const Key('campaign-regional-climate'));
      await reveal(switchFinder);
      expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
      final evaluate = find.byKey(const Key('campaign-evaluate'));
      await reveal(evaluate);
      expect(evaluate.hitTestable(), findsOneWidget);
      await tester.tap(evaluate);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await reveal(find.byType(CampaignResultCard));
      final result = tester
          .widget<CampaignResultCard>(find.byType(CampaignResultCard))
          .evaluation;
      expect(result.climate.any((c) => c.source.id == 'power_T2M'), isTrue);
      expect(result.input.useRegionalClimateReference, isTrue);
      expect(store.parcels.single.toJson(), before);
      expect(tester.takeException(), isNull);
    },
  );
}
