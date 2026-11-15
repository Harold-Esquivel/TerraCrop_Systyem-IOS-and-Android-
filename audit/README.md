# Auditoría de recomendaciones de cultivos

Estas pruebas de aceptación verifican lo que se solicita al producto: identificar déficits individuales y combinados, evitar diagnósticos incongruentes y adaptar la propuesta de rotación al cultivo actual. Consultan la interfaz con parcelas sintéticas; no escriben datos reales ni envían notificaciones.

Se ejecutan explícitamente porque documentan carencias de la implementación actual y pueden fallar. Un fallo aquí indica un requisito pendiente; no debe cambiarse la expectativa para ocultarlo. Están separadas de las pruebas de regresión de `test/`, cuyo éxito no demuestra que exista un motor de rotación.

```sh
flutter test --no-pub audit/crop_recommendations_audit_test.dart --reporter expanded
```

Esto comprueba el comportamiento del software. No valida científicamente los tratamientos ni convierte los índices NPK de demostración en mediciones de laboratorio.
