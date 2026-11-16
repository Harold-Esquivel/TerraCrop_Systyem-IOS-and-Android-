# Auditoría previa a la implementación — 15/11/2026

Especificación: `promtchatgpt.docx`, elegido por el usuario como sustituto del mensaje anterior. Los otros textos pegados no se usan como instrucciones.

## Estado inicial verificado

`flutter test`: **105 pruebas aprobadas** antes de editar código. Inspección de todos los módulos Dart, servicios, dependencias y recursos.

| Componente | Funcionamiento encontrado | Carencia |
| --- | --- | --- |
| Parcelas/mapas | CRUD, geometría, Mapbox móvil/OSM alternativo, historial | Ejemplos situados en Lima; no hay vinculación geográfica con NASA |
| Persistencia | TerraStore, SharedPreferences, cola de escritura, Firebase opcional | No hay repositorio ambiental ni campañas planificadas |
| Cultivos | CropRecommendationEngine ejecuta condiciones de suelo y matriz; CropCarePlan resume acciones | Falta traza estructurada de todas las reglas; S005 solo informa en algunos casos |
| Smart-Cycle | Escenarios multiselección, 3 s de carga, resultados y PDF nativo | CropSimulation usa coeficientes ilustrativos; no calcula campañas desde siembra ni usa NASA |
| Smart-Market | Seis sensores, búsqueda, filtros, carrito y pedido ficticio | No recibe riesgos ni genera recomendaciones; humedad del aire y suelo comparten categoría |
| Monitoreo | Dispositivos, batería y estado persistidos de demostración | No hay adquisición IoT física ni lecturas climáticas reales |
| Alertas | Transporte local/FCM opcional, mensaje genérico de simulación | No hay alerta de campaña con condición, evidencia, acción y verificación |
| Datos agronómicos | JSON tipado importado del Excel; unidades y originales conservados | Temperaturas, duraciones y secuencias no evalúan campañas; microbios no llegan al mercado |

## Libro recibido

SHA-256 coincide con `data/agronomy/TerraCrop_base_para_app.xlsx`: no se sustituye ni altera. Se leen las ocho hojas completas, incluidas las 169 filas de compatibilidad, fórmulas y resultados cacheados. Conteos: 13 cultivos, 169 pares ordenados, 3 escenarios, 12 pasos, 9 microorganismos, 13 reglas, 16 referencias. Índice: 12 filas con contenido; Cultivos: 14; Secuencias: 5; Compatibilidad: 170; Secuencias detalle: 13; Microorganismos: 10; Suelo Reglas: 14; Fuentes: 17 (incluyen encabezados).

No existe la hoja Diccionario mencionada en el índice. No hay calendario de siembra ni etapas críticas fechadas por variedad. Cebolla, pimiento, tomate y arroz describen duración desde trasplante: no se debe llamar siembra a ese inicio sin aclararlo. Alfalfa no tiene duración numérica de campaña y su agua es anual. Ajo/quinua carecen de umbral numérico de CE. Zapallo conserva extrapolación de salinidad de otra especie. Referencias microbianas generales no identifican ensayos por cepa. Intervalos pH y CE se solapan en extremos; se documentan convenciones, sin corregir silenciosamente la tabla.

## Archivos ambientales recibidos

- GPM/IMERG: 129 meses, enero 2015–septiembre 2025; Giovanni identifica GPM_3IMERGM_07, Final Run, exportación en mm/mes. Conservar bounding box solicitado y bounding box de datos; no confundir área pedida con resolución de parcela.
- SMAP: 1.410 registros, abril 2015–diciembre 2025; punto de consulta privado de La Joya, m³/m³. Faltan producto/versión, resolución y banderas de calidad. No afirmar filtrado recomendado ni inferir humedad radicular. Las coordenadas exactas se omiten en los archivos destinados a la app.
- POWER, pronóstico estacional y boletín ENSO regional: no suministrados. Ausencia explícita; no descargar retrospectivas para presentarlas como pronóstico.

## Cambios previstos

Importador ambiental reproducible sin dependencias nuevas, originales y metadatos; repositorio ambiental local tipado y estadísticas mensuales; motor de campañas y alertas; traza de reglas de suelo; recomendaciones de medición/microorganismos; acceso desde Smart-Cycle conservando simulación/PDF y catálogo/carrito. Pruebas de importación, unidades, fechas, ausencias, ámbito geográfico, reglas, mercado y recorrido integrado. No borrar ni reubicar parcelas existentes.
