# Informes de Smart-Cycle

La versión 1.3.0+6 permite seleccionar una o varias parcelas, o marcar todas. Los eventos, la intensidad y el horizonte se comparten; la fecha de cosecha y los ajustes de condiciones se conservan por parcela. Una selección vacía desactiva la generación. Cada informe captura sus parcelas al pulsar el botón, para que una actualización posterior del estado no cambie un resultado ya abierto.

## Contenido para el agricultor

La pantalla y el PDF muestran nombre y cultivo, eventos elegidos, plazo, condición y merma simuladas, planificación de cosecha y cuidados breves. El PDF incluye toda la lista de cuidados de cada parcela; la pantalla destaca tres y permite desplegar los restantes. La evolución se resume en inicio, cosecha prevista si está dentro del horizonte y final. No se exportan fórmulas, coeficientes, reglas internas, referencias al Excel ni explicaciones del cálculo.

Las recomendaciones de partida se generan con el análisis de suelo original mediante `CropRecommendationEngine` y `buildCropCarePlan`. Los ajustes de la simulación no sustituyen ese análisis. Los datos de ejemplo se identifican; un campo real desconocido no hereda una carencia de los índices demo. Los consejos ante el escenario son condicionales y no equivalen a haber detectado en campo una sequía, una plaga o una helada. El encharcamiento registrado impide sugerir aumentar el riego ante sequía. La fertilización simulada no borra una deficiencia real ni autoriza repetir aportes.

La proyección conserva el motor demostrativo existente: sus índices de condición, humedad y merma no son medidas de rendimiento ni probabilidades calibradas. El análisis agronómico se mantiene separado de esos índices; no se convierten categorías del laboratorio a porcentajes ni requerimientos kg/ha a lecturas. La nota breve del informe recuerda verificar el campo y que la fecha de cosecha no queda garantizada.

## Guardado

`SimulationPdf` genera A4 sin conexión y conserva acentos mediante Noto Sans, distribuida con su licencia SIL en `assets/fonts/LICENSE.txt`. `file_picker` abre el selector nativo para elegir ubicación y nombre del PDF. Una cancelación no se comunica como guardado; los errores permiten reintentar. No se solicitan permisos de acceso general a los archivos del teléfono.

`image` se fija en 4.5.4 porque PDF 3.12 limita `archive` a versiones anteriores a 4.1 y `image` 4.11 utiliza una API ausente en esas versiones. Esto permite conservar Dart 3.11 sin alterar el SDK. Las versiones resueltas están en `pubspec.lock`.

## Verificación

```sh
flutter test test/simulation_report_test.dart test/smart_cycle_screen_test.dart
```

La prueba crea `build/simulation-report-review/example.pdf`. Se comprueban selección, fechas distintas, captura de datos, recomendaciones y guardado/cancelación/error. La prueba nativa usa preferencias en memoria y no inicializa Firebase.

Para verificar la escritura real en Downloads de un emulador Android, ejecutar el ayudante en una terminal y la prueba en otra:

```sh
python3 tools/confirm_android_report_save.py --device emulator-5554
```

```sh
flutter drive --driver=test_driver/simulation_report_driver.dart --target=integration_test/simulation_report_device_test.dart -d emulator-5554
```

El ayudante solo actúa en emuladores y confirma exclusivamente un selector de guardado que contiene el nombre de un PDF de Smart-Cycle. Recupera el documento como `build/simulation-report-review/native-saved.pdf`; las capturas de la app y el resumen quedan en `build/simulation-report-review/captures/`.
