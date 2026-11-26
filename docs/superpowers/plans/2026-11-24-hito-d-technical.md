# CieloRD Hito D Technical Closure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:executing-plans` task-by-task. Steps use checkbox syntax.

**Goal:** Producir y verificar un APK release firmado con branding Android y
documentación de entrega completa, sin publicar ni inventar identidad.

**Architecture:** Recursos Android nativos derivados de la marca SVG existente,
pruebas de estructura/decodificación y una puerta final reproducible. La
auditoría referencia código, tests, APK y comprobaciones manuales por separado.

**Tech Stack:** Flutter 3.47.7, Dart 3.13.5, Android XML/PNG, Gradle, ADB,
apksigner.

**Spec:** `docs/superpowers/specs/2026-11-24-hito-d-technical-design.md`

## Global Constraints

- No leer, imprimir ni copiar secretos de `android/key.properties`.
- No URL, QR, PDF, publicación, Git, commits, push o merges.
- No inventar matrícula; el icono final queda bloqueado solo por ese dato.
- No actualizar dependencias innecesariamente ni cambiar contratos A/B/C.
- Repetir pub get, analyze, test, debug, release y QA después de los cambios.

## Review Focus

- APK release firmado con la clave release y no con Android Debug.
- Recursos adaptativos válidos en API 26+ y fallback legado decodificable.
- Splash oscuro sin destello blanco en API pre-31 y 31+.
- Ningún placeholder `{{MATRICULA}}` empaquetado.
- Auditoría distingue evidencia automática, emulador y teléfono físico.

---

### Task 1: Branding Android

**Files:** recursos `android/app/src/main/res/**`, manifest, fuente provisional
en `assets/branding`, prueba `test/unit/android_branding_resources_test.dart`.

- [ ] Escribir prueba que falle por recursos adaptativos/splash ausentes.
- [ ] Ejecutar la prueba y observar RED por archivos faltantes.
- [ ] Añadir icono provisional `CieloRD`, capas adaptativas, monocromo y splash.
- [ ] Ejecutar prueba focalizada y verificar GREEN.
- [ ] Comprobar visualmente PNG y recursos XML.

### Task 2: Auditoría y documentación

**Files:** `README.md`, `docs/entrega/*`, auditoría nueva y ledger D.

- [ ] Mapear cada requisito del Plan Maestro a implementación y evidencia.
- [ ] Actualizar README con build release, instalación, límites y privacidad.
- [ ] Actualizar checklist de teléfono y datos personales pendientes.
- [ ] Documentar arte provisional y bloqueo exacto del icono final.

### Task 3: Puerta automatizada y artefactos

- [ ] Ejecutar `flutter pub get`.
- [ ] Ejecutar `flutter analyze` y `flutter test` completos.
- [ ] Construir APK debug y release sin pub.
- [ ] Medir tamaño y contenido; calcular SHA-256 release.
- [ ] Verificar firma release con `apksigner` sin exponer secretos.

### Task 4: QA Android y cierre

- [ ] Confirmar `emulator-5554`, instalar release y lanzar sin red.
- [ ] Verificar nombre, icono/splash, Diario, mapa y rutas esenciales.
- [ ] Revisar logcat y restaurar el estado temporal del emulador.
- [ ] Actualizar estado D con aprobadas, omitidas, fallidas y pendientes.
- [ ] Repetir la puerta afectada si cualquier corrección cambia archivos.

Ruling: no se usa el workspace/commits del ejecutor porque el proyecto no es
repositorio y el responsable prohíbe explícitamente operaciones Git; el ledger
persistente será `docs/entrega/HITO_D_LEDGER.md`.
