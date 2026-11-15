import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final output = Directory('build/simulation-report-review/captures')
    ..createSync(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      await File('${output.path}/$name.png').writeAsBytes(bytes);
      return bytes.length >= 8 &&
          bytes[0] == 137 &&
          bytes[1] == 80 &&
          bytes[2] == 78 &&
          bytes[3] == 71;
    },
    responseDataCallback: (data) async {
      final summary = Map<String, dynamic>.from(data ?? {});
      final screenshots = summary.remove('screenshots') as List<dynamic>?;
      summary['screenshots'] = [
        for (final item in screenshots ?? []) item['screenshotName'],
      ];
      await File(
        '${output.path}/result.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(summary));
    },
  );
}
