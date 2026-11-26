# Plan de implementación — identidad final CieloRD

Spec: `docs/superpowers/specs/2026-11-24-final-identity-design.md`.

No se ejecutan commits ni herramientas Git por restricción expresa. El avance
se registra en `docs/entrega/FINAL_IDENTITY_LEDGER.md`.

## Tarea 1 — Contrato de identidad y asset offline

Archivos:

- Crear `lib/app/app_identity.dart`.
- Crear `tool/convert_profile_photo.dart`.
- Crear `assets/profile/michael_heredia.webp`.
- Modificar `pubspec.yaml`.
- Crear pruebas de asset/identidad.

Pasos:

1. Escribir pruebas que exijan los valores literales y que Flutter pueda cargar
   y decodificar el WebP empaquetado.
2. Ejecutarlas y observar RED por API/asset ausentes.
3. Añadir constantes, conversor y asset; declarar el asset.
4. Ejecutar y observar GREEN.

## Tarea 2 — Siembra única y Borrar Todo

Archivos:

- Crear `lib/features/profile/application/initial_profile_seeder.dart`.
- Modificar `lib/features/media/data/local_media_service.dart`.
- Modificar `lib/main.dart`.
- Crear `test/repositories/initial_profile_seeder_test.dart`.

Pasos:

1. Probar instalación limpia, perfil preexistente, idempotencia y
   Borrar Todo + reinicio sin resiembra.
2. Observar RED.
3. Añadir importación de bytes, seeder y composición de producción.
4. Observar GREEN y ejecutar pruebas de perfil/erase.

## Tarea 3 — Acerca de sin placeholders

Archivos:

- Modificar `lib/l10n/cielo_strings.dart`.
- Modificar `lib/features/profile/presentation/about_screen.dart`.
- Modificar `lib/features/profile/presentation/profile_avatar.dart`.
- Modificar `lib/ui_kit/branding/cielo_brand.dart`.
- Actualizar pruebas widget afectadas y añadir identidad final.

Pasos:

1. Cambiar primero las expectativas: datos definitivos y estado vacío
   accionable, sin textos “pendiente”.
2. Observar RED.
3. Implementar el renderizado mínimo y el valor de branding por defecto.
4. Observar GREEN.

## Tarea 4 — Icono final

Archivos:

- Crear SVG foreground/legacy finales.
- Eliminar fuentes provisionales y plantilla con placeholder.
- Actualizar `assets/branding/README.md`.
- Actualizar prueba de recursos Android.
- Regenerar PNG con `tool/generate_android_branding.ps1 -StudentId 2024-0063`.

Pasos:

1. Añadir expectativa de fuentes finales y ausencia global del marcador.
2. Observar RED.
3. Crear fuentes finales y generar recursos.
4. Observar GREEN e inspeccionar visualmente 48/192/432 px.

## Tarea 5 — Documentación y puerta final

Actualizar README y documentos de entrega. Ejecutar:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release --no-pub
```

Verificar con `apksigner`, calcular SHA-256, copiar sin sobrescribir secretos a
`build/app/outputs/flutter-apk/CieloRD_2024-0063_v1.0.apk` y confirmar que la
copia es byte a byte idéntica. Si ADB está disponible, instalar limpio y revisar
icono, Acerca de, versión y mapa offline.
