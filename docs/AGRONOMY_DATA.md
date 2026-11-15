# Base agronómica e interpretación

El archivo original del usuario se conserva en `data/agronomy/TerraCrop_base_para_app.xlsx`. SHA-256: `31dfa77d7ff94c0595be7a2ad130e5b3dfb712e85938844ff62c9cefd26fd5fa`.

`python3 tools/import_agronomy.py` genera de forma determinista `assets/data/agronomy.json`, que funciona sin servidor. Se preservan ocho hojas, 13 fichas, 169 pares de compatibilidad, tres secuencias, 12 campañas de detalle, 13 reglas, nueve microorganismos y 16 fuentes. Las 113 fórmulas se conservan con su texto y resultado cacheado, sin evaluación ni acceso a vínculos externos. Si se modifica el Excel, debe recalcularse y guardarse primero con una aplicación de hojas de cálculo.

Los nombres se normalizan para reconocer espacios, tildes, IDs y alias de maíz y pimiento. Las referencias de salinidad de ajo y quinua, y los periodos de campaña de alfalfa, quedan nulos cuando el archivo no los define. No se completan con ceros. El índice menciona un Diccionario que no existe como hoja en el archivo; no se inventó esa hoja. Se conservan los IDs de fuentes originales, incluido su salto de numeración.

## Reglas de interpretación

- Base regional: **La Joya, Arequipa**. Los estados «Confirmada», «Potencial» y «No prioritaria» describen lo que declara el Excel; no certifican presencia o idoneidad en otra ubicación.
- N, P₂O₅ y K₂O en **kg/ha** son referencias de requerimientos de fertilización. No se comparan con índices porcentuales de demostración ni se convierten en dosis para la parcela. Un análisis real permite registrar la interpretación de cada nutriente; si falta, queda desconocida.
- CE significa **conductividad del extracto saturado del suelo en dS/m**. No debe sustituirse por la CE de agua o de un sensor con otro método. La distinción y la dependencia del cultivo se contrastaron con el [manual de FAO sobre salinidad](https://www.fao.org/4/x5871e/x5871e04.htm) y la [tabla de tolerancia de FAO](https://www.fao.org/4/T0234E/T0234E03.htm).
- La demanda del cultivo no es riego aplicado ni una prueba de ahorro. Las secuencias tienen duraciones diferentes y se muestran tanto totales como demanda diaria. Esta separación es coherente con el [cálculo de necesidades de riego de FAO](https://www.fao.org/4/s2022e/s2022e08.htm).
- Alfalfa expresa demanda **anual**, es perenne y no tiene un periodo de campaña numérico en este archivo. No se le asigna un ciclo inventado.
- pH alto no identifica por sí solo sodicidad ni autoriza yeso. Se conserva la solicitud de PSI/RAS del archivo; el [Manual Nacional de Agronomía de USDA](https://www.nrcs.usda.gov/sites/default/files/2022-10/National-Agronomy-Manual.pdf) distingue conductividad y parámetros de sodio para esas clasificaciones.
- Microorganismos se muestran con condiciones, restricciones, método y precauciones del archivo. La aplicación comercial requiere verificar cepa y registro; no se realiza ni se calcula una dosis desde la app.

## Decisiones de implementación

Se aplica el límite superior exclusivo de los intervalos contiguos: pH 7.5 entra en S004 y pH 8.5 en S003. Los rangos específicos de cada cultivo se comprueban por separado. El umbral N/P/K <40 y humedad <40 solo existe en el modo demostración; el Excel no proporciona esos porcentajes como límites de laboratorio.

La comprobación de familias de las **tres campañas anteriores** es una regla conservadora de la aplicación, identificada como tal. No equivale a un periodo validado de saneamiento para una enfermedad concreta. El historial incluye campañas repetidas y conserva cultivos antiguos desconocidos, cuya familia no se inventa. Los posibles beneficios de leguminosas se condicionan a nodulación, fósforo, salinidad y manejo; no se prometen ahorros de fertilizante.

Las referencias bibliográficas del libro se incluyen para consulta. La comprobación externa anterior se limita a las distinciones de unidades y conceptos mencionadas; no constituye validación independiente de todas las cifras, microorganismos ni afirmaciones del Excel.

## Presentación de cuidados por parcela

Cultivos muestra hasta tres acciones prioritarias; un control permite consultar las restantes. `crop_care_plan.dart` resume los problemas ya identificados por el motor, agrupa los avisos coincidentes de pH y salinidad, y conserva sus IDs de origen. El catálogo y las reglas importadas permanecen íntegros; la biblioteca técnica y las referencias al Excel no se muestran al usuario.

Las acciones se ordenan por gravedad, con drenaje primero cuando hay encharcamiento porque condiciona el riego y el lavado de sales. Humedad baja y encharcamiento simultáneos solicitan revisar las observaciones antes de aumentar el agua. Estiércol curado o compost maduro se muestran cuando la materia orgánica registrada es inferior al 2%; no se asume este déficit si falta el dato. La salinidad mantiene la precaución de evitar estiércol fresco. Los niveles altos de nutrientes detienen una recomendación de aporte; los desconocidos no heredan los índices demo. No se calculan cantidades de fertilizante ni agua.

La próxima siembra se presenta aparte y conserva los filtros del motor y las condiciones de nodulación, salinidad, presencia local y cultivo perenne. Las razones de descarte se pueden desplegar. Consultar los cuidados no modifica los datos; guardar un análisis actualiza solo su parcela y recalcula sus recomendaciones.
