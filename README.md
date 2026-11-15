# TerraCrop

Aplicación móvil de agricultura inteligente en **modo prueba**, hecha con Flutter. La interfaz está en español y funciona sin una cuenta o claves de servicio.

## Ejecutar

```sh
flutter pub get
flutter run
```

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

- **Mapa:** mapa satelital Mapbox en Android/iOS con token, parcelas persistentes, edición de vértices, vista 2D/3D, selección, creación y eliminación. Sin token usa OpenStreetMap.
- **Mis cultivos:** pH, humedad, nutrientes, estado, alertas y recomendaciones orientativas.
- **Dispositivos:** cantidad, conexión y batería de equipos demostrativos asociados a cada parcela.
- **Mi perfil:** nombre editable, racha diaria y actividad.
- **Modo prueba:** simulación de pH, humedad, nitrógeno, fósforo y potasio. Una transición a estado crítico muestra un aviso y una notificación local.

Las recomendaciones son reglas de demostración basadas en umbrales. Antes de tomar una decisión agronómica, confirma los valores con un análisis de suelo y asesoría local.

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

## Verificación

```sh
flutter analyze
flutter test
flutter build apk --debug
```

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

La prueba abre la app, cambia entre 3D y 2D, comprueba el guardado local al recibir el final de un arrastre y vuelve al mapa desde Mis cultivos. Restaura la geometría original al terminar; el gesto físico de arrastrar se verifica manualmente.

La estructura separa `data/` (modelos, estado y servicios), `app/` (tema y navegación) y `screens/` (módulos). Provider comparte el estado entre pantallas. Las animaciones de navegación, entrada escalonada, parcelas y controles usan widgets nativos de Flutter.

Los servidores públicos de teselas de OpenStreetMap se usan únicamente para el modo de demostración sin Mapbox. Para distribución a gran escala, configura un proveedor de teselas conforme a su política de uso.
