# Auditoría de recomendaciones de cultivos

Estas pruebas de aceptación verifican lo que se solicita al producto: identificar déficits individuales y combinados, evitar diagnósticos incongruentes y adaptar la propuesta de rotación al cultivo actual. Consultan la interfaz con parcelas sintéticas; no escriben datos reales ni envían notificaciones.

Se ejecutan explícitamente para comparar los requisitos con la interfaz. Inicialmente detectaron ocho carencias; la integración del Excel añade el motor que las corrige. Las expectativas de negocio se mantienen: solo se adaptaron los selectores a la nueva composición de la interfaz. Un fallo indica un requisito pendiente; no debe cambiarse la expectativa para ocultarlo.

```sh
flutter test --no-pub audit/crop_recommendations_audit_test.dart --reporter expanded
```

Esto comprueba el comportamiento del software. No valida científicamente los tratamientos ni convierte los índices NPK de demostración en mediciones de laboratorio.
