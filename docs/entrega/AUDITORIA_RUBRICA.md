# Auditoría contra el Plan Maestro v1.0

Fecha final: 25-11-2026. Leyenda: **A** automatizado, **E** emulador y **F**
teléfono físico.

## Requisitos irrenunciables

| Requisito | Estado | Evidencia |
|---|---|---|
| CRUD completo SQLite y persistencia | Cumple (A/E) | Repositorio real, migraciones v1–v4, reapertura y conflictos optimistas. |
| Campos obligatorios y opcionales | Cumple (A) | Modelos, validadores y round-trip SQLite. |
| Estados `draft` y `published` | Cumple (A/E) | Flujos de borrador, edición y publicación. |
| GPS opcional y ubicación manual | Cumple técnicamente (A/E); GPS real F | Denegación no bloquea; texto, coordenadas y mapa manual disponibles. |
| Fotos y notas de voz | Cumple técnicamente (A/E); hardware F | Staging/commit/reconcile/reinicio, límites 5/3 y audio 120 s. |
| Listado, búsqueda y filtros | Cumple (A/E) | SQL parametrizado y pruebas widget/integración. |
| Detalle y mapa offline | Cumple (A/E) | GeoJSON empaquetado, proyección, marcadores y QA sin red. |
| Perfil con foto, nombre, matrícula y frase | Cumple (A/E) | Identidad final sembrada offline, editable y visible en Acerca de. |
| Borrar Todo y archivos asociados | Cumple (A/E) | Servicio, recuperación, enlaces seguros y semántica de perfil posterior. |
| Icono con app + matrícula | Cumple (A/E) | Adaptive/legacy/monocromo con `CieloRD` y `2024-0063`; launcher inspeccionado. |
| Funciones esenciales 100 % offline | Cumple (A/E) | Primera instalación/arranque y mapa con Wi-Fi/datos apagados. |
| APK instalable y firmado | Cumple (E) | Release v2 firmado, hash registrado e instalación limpia. |
| Documentación y licencias | Cumple | README, contratos, OFL y atribución cartográfica. |

## Funcionalidades adicionales

| Extra | Estado |
|---|---|
| Estadísticas locales | Cumple (A/E). |
| Modo Astrónomo rojo | Cumple (A/E); inspección final aprobada. |
| Borradores | Cumple (A/E). |
| Exportación/importación | Cumple (A/E); selector externo y round-trip físico pendientes F. |
| Autenticación local opcional | Cumple técnicamente (A/E); biometría real pendiente F. |
| Preferencias/accesibilidad | Cumple técnicamente (A/E); TalkBack físico pendiente F. |

## Entregables

| Entregable | Estado |
|---|---|
| Código fuente organizado | Cumple. |
| APK `CieloRD_2024-0063_v1.0.apk` | Cumple; 66,484,844 bytes. |
| Firma release | Cumple; v2, RSA 2048, un firmante. |
| Nombre, matrícula, foto y frase | Cumple. |
| Icono con matrícula | Cumple. |
| README final | Cumple localmente; validar render público tras push. |
| Repositorio/Release/enlace directo | En publicación; actualizar tras verificación pública. |
| QR y PDF | Deliberadamente no generados todavía. |
| QA teléfono físico | Pendiente según checklist específico. |

## Pruebas de aceptación

1. Instalación limpia y modo avión: aprobada E; repetir en teléfono F.
2. Perfil inicial y edición: aprobados A/E.
3. Observación sin GPS y fallback manual: aprobados A/E.
4. Foto/audio tras reinicio: aprobados A/E; hardware y audición F.
5. Búsqueda/filtros/detalle: aprobados A/E.
6. Mapa offline: aprobado A/E.
7. Borrador/publicación: aprobados A/E.
8. Exportar/importar/rechazar ZIP malicioso: aprobado A/E; selector físico F.
9. Borrar Todo/reinicio/interrupción: aprobado A/E; muerte real F.
10. Analyze/test/build/firma: 0 incidencias, 577/6/0, release firmado.

## Conclusión

No se detecta un requisito funcional obligatorio ausente. El único trabajo de
validación restante depende de hardware físico y no bloquea la integridad del
APK firmado. QR y PDF dependen de una URL pública real y verificada.
