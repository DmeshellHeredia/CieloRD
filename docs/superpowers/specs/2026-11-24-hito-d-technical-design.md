# CieloRD — Diseño técnico del cierre Hito D

Fecha: 24-11-2026. Ejecución autónoma autorizada por el responsable.

## Intención

Convertir el estado funcional A/B/C en un candidato release firmado y auditable,
sin publicar artefactos ni inventar los datos personales todavía pendientes.

## Alcance

- Branding Android: icono legado y adaptativo, monocromo, splash pre-Android 12
  y splash Android 12+.
- Nombre Android `CieloRD`; applicationId y versión actuales se conservan.
- README, documentación de entrega, auditoría de la rúbrica y checklist físico.
- Suite completa, APK debug, APK release firmado, tamaño, SHA-256 y firma.
- QA no destructivo del candidato en `emulator-5554` si ADB responde.

No incluye URL, QR, PDF, publicación, Git ni cambios funcionales fuera del Hito
D.

## Branding

Se reutiliza la marca original de `assets/branding`: luna, cordillera, destello,
paleta y tipografías. Se generan recursos Android deterministas; no se usa IA ni
una marca nueva.

El recurso instalado ahora es **provisional**: contiene la marca y `CieloRD`,
pero no una matrícula. El Plan Maestro exige la matrícula dentro del arte del
icono. Cuando se confirme, el único cambio visual pendiente será regenerar el
primer plano con esa cadena exacta. Nunca se usa `{{MATRICULA}}` ni un valor
inventado en un APK.

El icono adaptativo usa fondo y primer plano separados en 108 dp, contenido en
la zona segura de 66 dp y capa monocroma. Los lanzadores antiguos reciben PNG
compuesto por densidad. El splash usa fondo Abismo y la misma marca; Android
12+ recibe atributos `windowSplashScreen*` en recursos `values-v31`.

## Firma y secretos

Gradle es el único consumidor de `android/key.properties`. Las validaciones no
leen, imprimen ni copian sus valores. Se comprueba el resultado con
`apksigner verify --verbose --print-certs` y se informa solo del esquema de
firma, validez y huella pública del certificado si la herramienta la muestra.

## Evidencia de entrega

La auditoría separa tres estados: aprobado automáticamente, comprobado en
emulador y pendiente en teléfono/datos personales. Una funcionalidad con prueba
automatizada no se presenta como validación física. El APK release candidato se
identifica por ruta, tamaño, fecha, SHA-256 y resultado de firma.

## Decisiones consideradas

1. **Recursos Android nativos derivados de la marca existente (elegido):** no
   añade paquetes ni afecta runtime; ofrece control de todas las API Android.
2. `flutter_launcher_icons`/`flutter_native_splash`: válidos, pero agregan
   dependencias de build para un cierre que ya dispone de recursos fuente.
3. Mantener el icono Flutter hasta recibir matrícula: no cumple el requisito de
   adaptive icon ni la identidad mínima `CieloRD`.

## Criterio de salida

Hito D técnico puede cerrarse con suite, builds, firma y auditoría en verde. La
recomendación de **entrega académica final** seguirá siendo “no listo” mientras
falten matrícula, foto, frase, icono académico con matrícula, capturas, URL, QR,
PDF y pruebas físicas requeridas.
