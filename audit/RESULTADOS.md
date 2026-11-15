# Resultado de la auditoría de recomendaciones

## Actualización tras integrar el Excel

La implementación basada en `TerraCrop_base para app.xlsx` corrige los ocho fallos descritos más abajo. Las **12 pruebas de aceptación ahora pasan**: se detectan déficits individuales y simultáneos, se evita atribuirlos falsamente al pH y Papa queda descartada como rotación de sí misma. La auditoría mantiene las expectativas de negocio y utiliza los identificadores de los nuevos componentes para leer los resultados.

El diagnóstico distingue índices de demostración de análisis de laboratorio; no transforma referencias de kg/ha en lecturas. La matriz de 169 pares, las familias, el historial y las restricciones de pH/CE determinan las opciones y sus condiciones. La eficacia agronómica local sigue requiriendo validación y los datos faltantes no se dan por confirmados.

La sección siguiente conserva el resultado histórico para documentar qué estaba pendiente antes de incorporar la base.

## Resultado histórico anterior al Excel

Fecha: 15 de noviembre de 2026. Implementación auditada: `74fdffa`.

**La función solicitada no está completa.** Hay avisos básicos, pero no un diagnóstico individual de N/P/K ni un motor de rotación adaptado al cultivo.

Se ejecutaron 12 pruebas de aceptación sobre la interfaz de Cultivos, con parcelas sintéticas: **4 aprobadas y 8 fallidas**. Los fallos son aserciones de requisitos incumplidos, no errores del entorno de prueba. No se modificó código de producción ni datos de las parcelas del iPhone.

| Caso probado | Resultado observado | Aceptación |
| --- | --- | --- |
| pH 5.3, resto normal | Informa pH bajo. | Aprobada |
| pH 8.0, resto normal | Informa pH alto. | Aprobada |
| Humedad 35%, resto normal | Informa humedad baja. | Aprobada |
| Condiciones saludables | No muestra aviso de déficit; ofrece acciones generales. | Aprobada |
| pH 5.8, N/P/K en 70 | Dice que los nutrientes están bajos. | Fallida: diagnóstico incongruente |
| pH 7.5, N/P/K en 70 | Dice que los nutrientes están bajos. | Fallida: diagnóstico incongruente |
| Solo nitrógeno en 20 | Aviso genérico de nutrientes; no identifica nitrógeno. | Fallida |
| Solo fósforo en 20 | Mismo aviso genérico; no identifica fósforo. | Fallida |
| Solo potasio en 20 | Mismo aviso genérico; no identifica potasio. | Fallida |
| pH 5.3, humedad 20 y N/P/K en 20 | Informa únicamente el problema de pH. | Fallida: omite déficits simultáneos |
| pH 6.5 normal y nitrógeno en 20 | La recomendación ampliada ordena corregir el pH. | Fallida: acción incongruente |
| Rotación desde Papa, con Maíz como control | Devuelve el mismo texto «Considera quinua o papa…» e incluye el propio cultivo actual, Papa, entre las alternativas. | Fallida: propone repetir el cultivo actual |

## Evidencia en la implementación

- `lib/screens/crops_screen.dart`, función `_advice`: una cadena de condiciones devuelve un único aviso. No evalúa N, P y K por separado.
- Las condiciones de aviso de pH en `_advice` no coinciden con el intervalo de atención de `Parcel.warning` en `lib/data/models.dart`. Esto provoca los falsos avisos de nutrientes.
- La sección ampliada de recomendaciones contiene dos textos fijos. La alternativa para parcelas críticas no consulta el cultivo actual ni el historial.
- `Parcel` solo guarda el cultivo actual. No hay historial de siembras, familias de cultivos ni planificación de ciclos para fundamentar una rotación.
- Smart-Cycle calcula escenarios de demostración, pero no selecciona el siguiente cultivo ni genera un plan de rotación.

## Reproducir

```sh
flutter test --no-pub audit/crop_recommendations_audit_test.dart --reporter expanded
```

El comando devuelve un código de salida distinto de cero mientras sigan pendientes los ocho requisitos detectados. Las pruebas se conservan en `audit/` para no confundir estos fallos de aceptación con la suite existente en `test/`.

La ejecución con salida JSON está en `build/recommendation-audit/results.jsonl`; el resumen de casos y los textos observados, en `build/recommendation-audit/summary.json`. Estos archivos generados están excluidos de Git.

Las 28 pruebas de regresión existentes en `test/` siguen aprobadas y el análisis estático no encontró errores. Esas pruebas no cubrían los requisitos evaluados aquí; no constituyen validación de las recomendaciones ni de la rotación.

## Límite de la verificación

Se comprobó el comportamiento real del software, no la eficacia agronómica de un tratamiento. Los N/P/K actuales son índices de demostración, no análisis de laboratorio; los sensores del archivo proporcionado no incluyen un sensor de N/P/K. No hay base implementada para calcular dosis ni garantizar la idoneidad de una rotación para una parcela real.
