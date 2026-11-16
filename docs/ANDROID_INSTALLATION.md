# Verificación de instalación Android

Revisión del 15 de noviembre de 2026. El usuario informó que un teléfono queda instalando y otro muestra un error de descarga del paquete, al compartirlo por WhatsApp. No se dispone de modelos, versiones de Android, mensaje literal completo ni registros de esos teléfonos. **La causa de esos fallos no está confirmada.**

## Evidencia obtenida

### Actualización con JSON 2.1

El APK actual de esta revisión es `build/system-review/TerraCrop-1.3.0-arm64.apk`, versión 1.3.0, código 6, API mínima 24, 89 309 476 bytes. Se verificaron firma v2, alineación ZIP de 16 KB y correspondencia exacta del catálogo empaquetado con el asset integrado: 14 cultivos y 196 compatibilidades. Se instaló conservando datos con `adb install -r` y arrancó correctamente en Android 15/API 35 ARM64 virtual. El flujo nativo de cuidados, apariencia clara/oscura, análisis parcial, rotación e historial también pasó. Las capturas están en `build/agronomy-review/` y el hash y registros en `build/system-review/`. Los detalles del entorno y los pendientes para iOS están en [SYSTEM_REVIEW.md](SYSTEM_REVIEW.md).

La compilación está dirigida a ARM64 y utiliza la clave local de pruebas. No se verificó en teléfonos físicos ni con páginas de memoria de 16 KB. La evidencia siguiente corresponde a revisiones anteriores.

- Los APK anteriores debug y release tienen ZIP íntegro, firma APK v2 válida, no llevan `testOnly`, y contienen ARM de 32 bits, ARM de 64 bits y x86 de 64 bits.
- Ambos APK anteriores usan el mismo certificado local Android Debug. Esto descarta una diferencia de firma entre estos dos archivos, pero no con una instalación anterior generada en otra computadora.
- El APK actualizado es versión 1.1.0, código 2, con API mínima 24. La firma y la alineación ZIP de 16 KB se verificaron con `apksigner` y `zipalign`. Las bibliotecas de 64 bits anteriores también se revisaron para alineación ELF.
- En un emulador Android 15/API 35 ARM64 se instaló primero el release anterior y después el nuevo con `adb install -r`: **ambos devolvieron Success**. El paquete instalado reporta versión 1.1.0, código 2. Esta prueba conserva datos durante la actualización; no prueba la instalación en todos los modelos físicos.
- La imagen Android utilizada tiene páginas de 4096 bytes. La comprobación de alineación no equivale a una prueba de ejecución en un teléfono de páginas de 16 KB.
- La prueba nativa completa de recomendaciones también pasó: catálogo 13/169, déficits combinados, análisis parcial sin reutilizar índices demo, rotación de Papa sin solanáceas e historial conservado. Se utilizó almacenamiento en memoria aislado y no se enviaron datos a la nube.

## Distribución

El APK universal para compartir está en `build/android-install-review/release/TerraCrop-1.1.0-universal.apk`; su tamaño y SHA-256 están en `artifact.json` de esa carpeta. Es una compilación release para pruebas, firmada con la misma clave local usada anteriormente. No se cambió la identidad de la app ni se borraron datos para conseguir instalar.

Se generó también `TerraCrop-1.1.0-arm64.apk`, aproximadamente 86.8 MB frente a 122.9 MB del universal. Solo sirve para Android ARM64, no para ARM de 32 bits ni x86. Tiene la misma versión y código, firma válida y alineación comprobada; su huella está en `artifact-arm64.json`. Las pruebas de instalación y uso se realizaron con el universal del mismo código fuente; la variante pequeña se verificó estáticamente. No se presenta como una solución confirmada al fallo físico.

Al recibir el archivo, verificar que conserva extensión `.apk`, terminó de descargarse y su tamaño coincide con el entregado. Abrirlo desde Archivos/Descargas ayuda a distinguir una descarga incompleta de un error del instalador. WhatsApp es el medio informado, pero no hay evidencia para atribuirle el fallo.

Si vuelve a fallar, capturar el mensaje literal y el modelo/versión Android. Cuando se disponga del teléfono, `adb install -r ruta/al/archivo.apk` permite obtener un código específico. No desinstalar la app ni cambiar su firma como ensayo: podría eliminar datos o impedir una actualización compatible.

## Referencias técnicas

La [documentación de adb](https://developer.android.com/tools/adb#move) describe la instalación de APK y la actualización conservando datos. Los estados de fallo [PackageInstaller](https://developer.android.com/reference/android/content/pm/PackageInstaller) distinguen incompatibilidad, conflictos, paquetes inválidos y espacio insuficiente. Son posibles categorías de diagnóstico, no causas confirmadas en estos teléfonos. La [guía de páginas de 16 KB](https://developer.android.com/guide/practices/page-sizes) explica las verificaciones de bibliotecas nativas.
