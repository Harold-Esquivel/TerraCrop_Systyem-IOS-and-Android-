import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';

import 'app/app_theme.dart';
import 'app/app_appearance.dart';
import 'app/entry_screen.dart';
import 'data/terra_store.dart';
import 'data/alert_service.dart';
import 'data/cloud_service.dart';
import 'data/agronomy_catalog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AgronomyCatalog.load();
  const mapboxToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
  if (mapboxToken.isNotEmpty) MapboxOptions.setAccessToken(mapboxToken);
  await CloudService.instance.initialize();
  final store = TerraStore();
  await store.load();
  await AlertService.instance.initialize();
  runApp(
    ChangeNotifierProvider.value(value: store, child: const TerraCropApp()),
  );
}

class TerraCropApp extends StatelessWidget {
  const TerraCropApp({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => AppAppearance()..load(),
    child: const _ThemedApp(),
  );
}

class _ThemedApp extends StatelessWidget {
  const _ThemedApp();
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TerraCrop',
    debugShowCheckedModeBanner: false,
    theme: appTheme,
    darkTheme: appDarkTheme,
    themeMode: context.watch<AppAppearance>().mode,
    themeAnimationDuration: const Duration(milliseconds: 250),
    builder: (context, child) {
      final dark = Theme.of(context).brightness == Brightness.dark;
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: context.colors.canvas,
              systemNavigationBarIconBrightness: dark
                  ? Brightness.light
                  : Brightness.dark,
            ),
        child: child ?? const SizedBox.shrink(),
      );
    },
    locale: const Locale('es'),
    home: const EntryScreen(),
  );
}
