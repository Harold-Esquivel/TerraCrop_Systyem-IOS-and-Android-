# Instalación y revisión del sistema

Revisión realizada el 15 de noviembre de 2026 en este Mac. La base activa procede del JSON 2.1 proporcionado por el usuario. El modo local funciona sin configurar servicios externos.

## Actualización NASA POWER — 1.3.1+7

Se validaron 4018 días de 2015–2025 y 1300 valores derivados del paquete recibido. La app incorpora 924 observaciones mensuales nuevas, siete variables y selección explícita de referencia histórica de La Joya. La radiación se convierte de MJ/m²/día a kWh/m²/día y la lluvia se acumula por mes. Se retiraron las coordenadas exactas de los recursos de POWER y de la caché SMAP destinada a la app. Los 12 originales permanecen en `data/environment/private/power_package/`, excluidos de Git. La versión sin coordenadas se conserva en `data/environment/POWER_climatologia_sin_coordenadas.json`.

Validación actual: análisis sin incidencias, 128 pruebas Flutter/aceptación y 13 pruebas Python aprobadas; recorrido Android aprobado. El APK `TerraCrop-1.3.1-Android-ARM64.apk` está en Descargas y sus metadatos en `build/power-review/artifact.json`. Firma y alineación verificadas; contenido y omisión de coordenadas comprobados dentro del APK. Sigue faltando el CSV original SMAP y los datos reales de parcelas/suelo. Las secciones siguientes documentan la revisión inicial de la versión 1.3.0.

## Cambios y datos

- Original conservado en `data/agronomy/TerraCrop_base_para_app_v2.json`; su SHA-256 coincide con el archivo recibido.
- Asset generado en `assets/data/agronomy.json`: 14 cultivos, incluida zanahoria; matriz completa de 196 compatibilidades; 40 fuentes.
- Calendarios y umbrales críticos disponibles en el catálogo. El planificador contrasta el mes elegido con la ventana de siembra y muestra las revisiones pendientes del cultivo.
- Las 17 tablas y los metadatos originales se conservan completos. Productos, presentaciones, secuencias locales, alertas, advertencias y fuentes dinámicas quedan accesibles desde el catálogo.
- Se distinguen extracción, requerimientos de fertilización y aporte de nitrógeno. Los valores desconocidos siguen siendo desconocidos.
- Se conserva el Excel anterior y su importador. Los detalles y las cinco revisiones agronómicas pendientes están en [AGRONOMY_DATA.md](AGRONOMY_DATA.md).

## Entorno instalado y comprobado

| Componente | Estado |
| --- | --- |
| Flutter / Dart | 3.41.9 / 3.11.5, ya instalados; dependencias resueltas conforme a `pubspec.lock` |
| Java | OpenJDK 21.0.11, ya instalado; preparado para terminal mediante `tools/dev_env.sh` |
| Android SDK | Plataforma 36, build-tools 36.0.0, NDK 28.2.13676358, ya instalados |
| Emulador | AVD existente TerraCrop_QA_API35, Android 15/API 35, ARM64; iniciado para las pruebas |
| Node.js | 22.23.5 instalado con Homebrew, coincidente con `functions/package.json` |
| Backend Firebase | Dependencias instaladas; `firebase-admin` 14.5.1 y `firebase-functions` 7.4.0; lockfile añadido |
| CocoaPods | 1.16.2, ya instalado |
| Xcode completo | Pendiente; solo están disponibles las Command Line Tools de Apple |

Se habilitó Swift Package Manager en la configuración local de Flutter, requerido por la dependencia móvil de Mapbox. El proyecto ya lo declara en `pubspec.yaml`.

La actualización de Firebase respeta Node 22 y los puntos de entrada utilizados por la función. Referencias: [notas oficiales de Admin SDK](https://firebase.google.com/support/release-notes/admin/node) y [Firebase Functions 7.4.0](https://github.com/firebase/firebase-functions/releases/tag/v7.4.0). Se comprobó la carga de la función y el manejo local de un evento vacío; el envío remoto requiere configurar Firebase.

## Verificaciones

- `dart analyze`: sin incidencias. Se corrigieron 23 avisos de llaves en condicionales existentes.
- `flutter test --no-pub --reporter expanded test audit/crop_recommendations_audit_test.dart`: 122 pruebas aprobadas, incluidas 12 de aceptación.
- `python3 -m unittest discover -s tools -p 'test_*.py' -v`: nueve pruebas aprobadas. Cubren importación reproducible del JSON, compatibilidad del Excel, unidades, relaciones corruptas, duplicados y meses desconocidos.
- `npm audit --prefix functions`: cero vulnerabilidades reportadas después de actualizar las dependencias.
- `node --check functions/index.js` y carga local del export `sendCriticalAlert`: correctos.
- `flutter build apk --debug --no-pub`: compilación correcta.
- APK release para Android ARM64 generado, firma v2 y alineación ZIP de 16 KB verificadas. Se instaló con `adb install -r`, resultado `Success`, y arrancó con `Status: ok`. El catálogo incluido en el APK coincide byte por byte con el asset del proyecto. Esta comprobación corresponde al emulador Android 15, no a teléfonos físicos ni a un dispositivo con páginas de memoria de 16 KB.
- Prueba nativa en `emulator-5554`: catálogo, cuidados en claro y oscuro, análisis parcial, rotación e historial aprobados. Evidencia y cinco capturas en `build/agronomy-review/`.

Los registros de esta revisión están en `build/system-review/`. Son artefactos locales excluidos de Git.

## APK instalable

Archivo: `build/system-review/TerraCrop-1.3.0-arm64.apk`.

- Versión 1.3.0, código 6; Android API 24 o superior, teléfono ARM64.
- Tamaño: 89 309 476 bytes, aproximadamente 89,3 MB.
- SHA-256: `b034d700a8bb727f6765e6496f6690e7fd394402e12bc655e2a8986cb76ed98d`.
- Compilación release firmada con la clave local Android Debug del proyecto, destinada a pruebas. El mapa usa OpenStreetMap porque no se proporcionó un token Mapbox.

Para instalar en un Android ARM64 conectado y autorizado por USB:

```sh
source tools/dev_env.sh
adb install -r build/system-review/TerraCrop-1.3.0-arm64.apk
```

Para volver a generar el release: `flutter build apk --release --target-platform android-arm64 --no-pub`. Al cambiar de pruebas nativas a release, debe regenerarse el registro de plugins con una ejecución sin `--no-pub`; en este Mac esa preparación actualizó Android antes de detenerse por Xcode, y la compilación posterior con `--no-pub` finalizó correctamente. Instalar Xcode permite completar esa preparación normalmente.

## Usar este entorno

Desde la raíz del proyecto:

```sh
source tools/dev_env.sh
python3 tools/import_agronomy.py
flutter run --no-pub -d emulator-5554
```

Si el emulador está cerrado, iniciarlo antes con `flutter emulators --launch TerraCrop_QA_API35`. El script de entorno prepara Java 21, Node 22 y las rutas del SDK para la terminal actual. No modifica archivos de inicio de la cuenta.

Para repetir las comprobaciones:

```sh
source tools/dev_env.sh
dart analyze
python3 -m unittest discover -s tools -p 'test_*.py' -v
flutter test --no-pub test audit/crop_recommendations_audit_test.dart
npm ci --prefix functions --ignore-scripts
npm audit --prefix functions
node --check functions/index.js
```

En este Mac, la resolución de paquetes de `flutter pub get` termina, pero su preparación posterior de plugins de Apple falla porque Mapbox necesita Swift Package Manager y Flutter requiere Xcode completo para usarlo. Las comprobaciones y compilaciones Android se ejecutaron con `--no-pub` sobre las dependencias ya resueltas. Tras instalar Xcode, ejecutar de nuevo `flutter pub get` para completar también esa preparación.

## Requisitos pendientes

1. **iOS:** instalar Xcode completo y el soporte iOS, seleccionarlo como entorno de desarrollo y completar su configuración inicial. La [guía oficial de Flutter para iOS](https://docs.flutter.dev/platform-integration/ios/setup) detalla los pasos. La comprobación local de compilación no pudo completarse; Flutter informó `Application not configured for iOS` al no poder consultar los ajustes con Xcode. El proyecto contiene `Runner.xcworkspace`, identificador de app y destino iOS 15. Instalar en un iPhone requiere además firma y equipo de desarrollo de Apple.
2. **Mapbox satelital:** añadir el token público propio en `mapbox.defines.json` y pasarlo con `--dart-define-from-file`. La app actual utiliza OpenStreetMap cuando falta el token.
3. **Firebase remoto:** configurar el proyecto, las claves locales, Authentication, Firestore, Messaging y APNs para iOS. La sincronización y los push remotos requieren esa configuración y despliegue. El modo local está disponible.
4. **Datos dinámicos:** los textos de integración del JSON describen fuentes; no aportan una conexión activa ni un pronóstico. Los avisos meteorológicos automáticos requieren implementar y validar esas conexiones.
5. **SMAP original:** existe la caché ambiental en `assets/data/environment.json`, pero falta `data/environment/SMAP.csv` en el repositorio y no se encontró en Descargas. La caché permite ejecutar el sistema. Reproducir toda la importación ambiental requiere recuperar el CSV original; las pruebas verifican la parte GPM disponible y el parser SMAP con una muestra controlada.

`flutter doctor` mantiene dos advertencias adicionales: el SDK de Flutter usa un canal local `user-branch` sin upstream estándar y no reconoce el estado de licencias de Android. Se comprobó que las Command Line Tools 23 responden a `sdkmanager --licenses` indicando que esa opción ya no es necesaria, mientras Flutter 3.41 busca el mensaje antiguo. Las compilaciones y la prueba nativa Android sí terminaron correctamente. No se presenta este diagnóstico como una validación completa de iOS.
