# TerraCrop

Aplicación móvil de agricultura inteligente en **modo prueba**, hecha con Flutter. La interfaz está en español y funciona sin una cuenta o claves de servicio.

## Ejecutar

```sh
flutter pub get
flutter run
```

La instalación y revisión de este equipo, los comandos para Android y los requisitos pendientes para iOS están en [docs/SYSTEM_REVIEW.md](docs/SYSTEM_REVIEW.md). En este Mac, `source tools/dev_env.sh` prepara Java 21, Node 22 y las herramientas de Android para la terminal actual.

La primera apertura muestra tres parcelas de ejemplo cerca de Lima. El mapa necesita internet; los datos de parcelas, perfil, racha y simulaciones quedan guardados en el dispositivo. Las parcelas de ejemplo se pueden editar o eliminar. Para crear una, toca **Nueva parcela** y marca dos esquinas opuestas del rectángulo. El mapa permite desplazar y acercar la vista antes de dibujar.

## Mapa satelital Mapbox

En Android o iOS, configura un token público de Mapbox para usar el mapa satelital como mapa principal:

1. Copia `mapbox.defines.example.json` como `mapbox.defines.json`.
2. Reemplaza el valor de `MAPBOX_ACCESS_TOKEN` por tu token público (`pk.`). El archivo local está excluido de Git.
3. Ejecuta:

```sh
flutter run --dart-define-from-file=mapbox.defines.json
```

La configuración del proyecto habilita Swift Package Manager, requerido por Mapbox 3.35 en iOS. La app requiere iOS 15 o superior por sus dependencias de Firebase. Para instalarla en un iPhone físico, selecciona tu equipo de desarrollo en **Signing & Capabilities** de `ios/Runner.xcworkspace` y mantén activado el modo desarrollador del teléfono.

Selecciona una parcela para ver sus vértices. Arrastra uno para cambiar su forma; al soltarlo, la nueva geometría se guarda junto con los demás datos de la parcela. El botón **Vista 2D/3D** cambia la inclinación sin reiniciar la posición del mapa. La creación, edición de nombre y cultivo, y eliminación siguen disponibles en la misma pantalla.

Sin token, o en web y escritorio, la app usa el mapa de OpenStreetMap para mantener el modo prueba. La edición de vértices requiere el mapa Mapbox de Android o iOS.

Al abrir la app aparece el logo de TerraCrop, después el nombre con un efecto de desenfoque y finalmente el botón **Iniciar sesión**. Ese botón abre una carga de cuatro segundos con plantas que crecen antes de mostrar los módulos. Es un acceso demostrativo, sin formulario ni validación de credenciales. La barra inferior usa una superficie blanca elevada y un círculo azul que recorre los módulos al cambiar de sección.

## Módulos

La identidad visual combina blanco, verde y azul: tarjetas claras, acentos verdes y degradados hacia azul. El modo oscuro utiliza fondos azul profundo, superficies diferenciadas y acentos de mayor contraste.

La barra inferior sigue este orden y abre **Mi perfil** al iniciar:

1. **Mi perfil:** nombre editable, racha diaria, actividad y botón **Dispositivos**, que abre los sensores y equipos por parcela con su conexión y batería. Un botón de luna a la derecha, sobre la barra de módulos, activa el modo oscuro; cambia a sol para volver al modo claro. La elección se guarda localmente y se aplica a todas las pantallas, ventanas y formularios.
2. **Smart-Cycle:** permite elegir una, varias o todas las parcelas, combinar eventos climáticos y agrícolas, ajustar intensidad y horizonte, y definir cosecha y condiciones independientes por parcela. **Ver el resultado** mantiene la carga de tres segundos. El informe reúne resultados, cuidados según los datos registrados y acciones condicionales ante el escenario; el PDF se guarda mediante el selector nativo de archivos. Las fórmulas y explicaciones del cálculo quedan fuera de la interfaz y del documento. [Formato, límites y verificación](docs/SIMULATION_REPORTS.md).
3. **Cultivos:** cuidados puntuales por parcela con tres acciones prioritarias y acceso opcional al resto. Resume riego, materia orgánica, nutrientes, pH, salinidad y drenaje según los datos ingresados. El análisis y el historial se editan por parcela; la próxima siembra se consulta en una ventana aparte con opciones filtradas por compatibilidad, familia, pH y salinidad. Las referencias al Excel y la biblioteca técnica no se muestran en la interfaz.
4. **Smart-Market:** tienda ficticia de seis sensores del archivo **Resumen de Sensores Agrícolas**, con búsqueda, filtros, fichas, carrito y pedido de demostración sin cobros ni envíos. Mantiene soles y dólares separados: SEN0193 S/37, DS18B20 S/20, SHT31 S/30, SEN0161-V2 S/250, DFR0300 US$69.90 y SEN0604 US$69 por importación. La referencia local del SEN0604, S/390, se muestra agotada. Son referencias del archivo, no cotizaciones ni stock en vivo.
5. **MAPA:** mapa satelital Mapbox en Android/iOS con token, parcelas persistentes, edición de vértices, vista 2D/3D, selección, creación y eliminación. Sin token usa OpenStreetMap.

Smart-Cycle sustituye la pantalla manual Modo prueba. Sus escenarios se conservan al cambiar de pestaña y no sobrescriben las lecturas ni la geometría de la parcela. El carrito también se conserva durante la sesión al cambiar de módulo.

El simulador usa reglas y perfiles de cultivo ficticios sin calibración de campo, intensidad constante y una fecha de cosecha introducida por el usuario. No usa clima real ni predice rendimiento comercial; los porcentajes de merma son indicadores didácticos. Su umbral (condición menor de 60/100 o merma potencial de al menos 15%) no garantiza un tiempo seguro de permanencia ni conservación del cultivo.

La base regional está en `assets/data/agronomy.json`, generada del JSON 2.1 original conservado en `data/agronomy/TerraCrop_base_para_app_v2.json`. Incluye 14 cultivos, 196 compatibilidades, tres secuencias diseñadas, cinco secuencias locales, 14 calendarios, 14 umbrales críticos, 13 reglas de suelo, nueve grupos de microorganismos y 40 referencias. Conserva también presentaciones, productos, reglas de alertas, advertencias, fuentes dinámicas y revisiones. Para reproducir la importación, ejecuta `python3 tools/import_agronomy.py`. El planificador consulta las ventanas de siembra y muestra las revisiones pendientes del cultivo. Las descripciones de integración se conservan como datos; las conexiones a fuentes dinámicas requieren implementación y datos reales. La clasificación y las advertencias son las del archivo, no una verificación independiente de todas sus fuentes.

Sin análisis registrado, la app identifica explícitamente sus pH, humedad e índices N/P/K como datos de demostración. El editor de análisis permite pH, CE del extracto saturado en dS/m, materia orgánica y el diagnóstico cualitativo de cada nutriente. Los campos vacíos permanecen desconocidos: no se reemplazan por valores de prueba ni se consideran saludables. Los requerimientos de N/P₂O₅/K₂O en kg/ha son referencias de fertilización por campaña, no concentraciones medidas ni dosis calculadas.

Las rotaciones excluyen el cultivo actual y su familia, revisan de forma conservadora las tres campañas anteriores registradas y explican cada descarte. Los cultivos potenciales mantienen esa clasificación; arroz queda fuera del piloto. Si falta información, las opciones quedan condicionadas a verificarla. Registrar una siembra requiere confirmación y añade el cultivo anterior al historial, incluso si repite una campaña anterior. Consultar una opción o simular no cambia el cultivo real.

La demanda hídrica es demanda del cultivo, no riego aplicado ni ahorro garantizado. Alfalfa conserva su referencia anual y sus periodos de campaña desconocidos. Smart-Cycle muestra estas fichas como contexto, pero mantiene un modelo didáctico sin calibración de campo. Antes de intervenir, confirma el análisis y la pertinencia local de las recomendaciones.

## Firebase opcional: nube y push remoto

El código incluye sincronización con Cloud Firestore, acceso anónimo de Firebase Auth, registro de token FCM y una Cloud Function que envía push al crearse una alerta crítica. Sin configuración de Firebase, todo el modo prueba sigue funcionando localmente.

1. Crea un proyecto Firebase con **Authentication > Anonymous**, **Cloud Firestore** y **Cloud Messaging**. Registra la app Android/iOS con sus identificadores definitivos.
2. Configura las plataformas con `flutterfire configure`. Para iOS, habilita Push Notifications, Background Modes y configura una clave APNs en Firebase. Para Android, usa un dispositivo con Google Play Services.
3. Despliega `firestore.rules` y `functions/` con `firebase deploy --only firestore:rules,functions` desde este directorio, después de seleccionar el proyecto con Firebase CLI. La función puede requerir el plan de facturación correspondiente de Firebase.
4. Ejecuta la app con los valores de configuración de la app Firebase:

Guarda los valores en `firebase.defines.json` (puedes copiar `firebase.defines.example.json`) y ejecuta:

```sh
flutter run --dart-define-from-file=firebase.defines.json
```

En web, agrega `--dart-define=FIREBASE_VAPID_KEY=...` y configura el service worker de FCM. No se incluyen credenciales reales en el repositorio.

La cuenta anónima conserva su identidad en la instalación actual. Para recuperar los mismos datos tras reinstalar o en otro teléfono, se necesitaría vincular una cuenta real; ese flujo no forma parte del modo prueba.

## Distribución Android

La versión actual es **1.3.1+7**, con API mínima 24. Para compartir en teléfonos, utiliza un APK release. Se verificó la instalación del release anterior y su actualización al nuevo en Android 15 ARM64 virtual; esto no determina la causa del fallo reportado en teléfonos físicos enviados por WhatsApp. La evidencia y los límites están en [docs/ANDROID_INSTALLATION.md](docs/ANDROID_INSTALLATION.md).

La compilación universal cubre ARM32, ARM64 y x86_64. Para un teléfono ARM64 puede generarse un archivo más pequeño sin cambiar el código de versión:

```sh
flutter build apk --release --target-platform android-arm64 --dart-define-from-file=mapbox.defines.json
```

Esta compilación reemplaza `app-release.apk`: guárdala con un nombre que indique su arquitectura antes de generar otra. La firma actual es la clave local de pruebas; no debe cambiarse al actualizar una instalación existente.

## Verificación

```sh
flutter analyze
flutter test
flutter build apk --debug
```

La suite incluye 116 pruebas unitarias y de interfaz para los datos agrícolas y las funciones de la app, más las 12 pruebas de aceptación de `audit/` y 13 pruebas Python de importación. La prueba nativa aislada de Android verifica el catálogo, los cuidados resumidos en modo claro y oscuro, el análisis parcial, la rotación y el historial con datos en memoria:

```sh
flutter test audit/crop_recommendations_audit_test.dart
flutter drive --driver=test_driver/agronomy_driver.dart --target=integration_test/agronomy_device_test.dart -d ID_DEL_DISPOSITIVO
```

Las capturas y el resultado quedan en `build/agronomy-review/`. El original del Excel, la procedencia y las distinciones de unidades se describen en [docs/AGRONOMY_DATA.md](docs/AGRONOMY_DATA.md).

Para compilar con el mapa satelital y el token local configurado:

```sh
flutter build apk --debug --dart-define-from-file=mapbox.defines.json
flutter build ios --debug --no-codesign --dart-define-from-file=mapbox.defines.json
```

El APK queda en `build/app/outputs/flutter-apk/app-debug.apk` y la app iOS en `build/ios/iphoneos/Runner.app`. La compilación iOS sin firma permite verificar el código; instalarla en un iPhone físico requiere una cuenta de Apple en Xcode, un equipo de desarrollo y un perfil de aprovisionamiento válido.

Para probar Mapbox en un teléfono Android/iOS conectado o un simulador iOS y guardar capturas en `build/mapbox-device/`:

```sh
flutter drive --driver=test_driver/mapbox_device_driver.dart --target=integration_test/mapbox_device_test.dart --dart-define-from-file=mapbox.defines.json -d ID_DEL_DISPOSITIVO
```

La prueba entra en MAPA desde Mi perfil, cambia entre 3D y 2D, comprueba el guardado local al recibir el final de un arrastre y vuelve al mapa desde Cultivos. Restaura la geometría original al terminar; el gesto físico de arrastrar se verifica manualmente.

Para verificar los nuevos módulos, el acceso a Dispositivos y la conservación del carrito entre pestañas, con capturas en `build/module-review/`:

```sh
flutter drive --driver=test_driver/modules_driver.dart --target=integration_test/modules_device_test.dart -d ID_DEL_DISPOSITIVO
```

Para comprobar el cambio claro/oscuro, su persistencia, los resultados de Smart-Cycle y el carrito, con capturas en `build/appearance-review/captures/`:

```sh
flutter drive --driver=test_driver/appearance_driver.dart --target=integration_test/appearance_device_test.dart -d ID_DEL_DISPOSITIVO
```

La estructura separa `data/` (modelos, estado y servicios), `app/` (tema y navegación) y `screens/` (módulos). Provider comparte el estado entre pantallas. Las animaciones de navegación, entrada escalonada, parcelas y controles usan widgets nativos de Flutter.

Los servidores públicos de teselas de OpenStreetMap se usan únicamente para el modo de demostración sin Mapbox. Para distribución a gran escala, configura un proveedor de teselas conforme a su política de uso.

## Clima NASA POWER integrado

Se incorporaron las siete variables históricas de 2015–2025 desde 4018 registros diarios verificados. En Smart-Cycle → Planificar campaña, activa **Usar referencias históricas de La Joya** para consultar este contexto. Son referencias históricas, sin coordenadas exactas, pronósticos ni mediciones de suelo de la parcela. Los originales están en `data/environment/private/power_package/`, excluidos de Git. Para reproducir la validación e importación: `python3 tools/import_power_package.py data/environment/private/power_package`. Evidencia en `build/power-review/`.
