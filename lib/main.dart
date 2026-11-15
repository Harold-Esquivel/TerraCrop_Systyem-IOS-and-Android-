import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';

import 'app/app_theme.dart';
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
  Widget build(BuildContext context) => MaterialApp(
    title: 'TerraCrop',
    debugShowCheckedModeBanner: false,
    theme: appTheme,
    locale: const Locale('es'),
    home: const EntryScreen(),
  );
}
