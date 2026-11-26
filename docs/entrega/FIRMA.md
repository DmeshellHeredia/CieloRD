# Firma release de CieloRD

El 24-11-2026 se compiló y verificó el APK final
`CieloRD_2024-0063_v1.0.apk` sin usar fallback debug.

Resultado de `apksigner verify --verbose --print-certs`:

- verificación aprobada;
- un firmante;
- clave RSA de 2048 bits;
- APK Signature Scheme v2: verdadero;
- v1, v3, v3.1, v4 y SourceStamp: no presentes;
- SHA-256 del certificado:
  `760f14222aacc30dcd842b762dd72fc59a3ab73fc71300bd67c7be5f55b35852`;
- SHA-256 del APK:
  `1F77A0762E133141E1A51BD13179FBC89E453847A46A8404A55BEB9CDA1E339B`.

V2 es compatible con `minSdk 24`. No se leyó, imprimió ni copió ningún secreto
de `android/key.properties`; la verificación se hizo sobre el APK resultante.
El archivo de propiedades, el keystore y sus contraseñas deben permanecer
privados y fuera de Git.

```powershell
flutter build apk --release --no-pub
apksigner verify --verbose --print-certs `
  build/app/outputs/flutter-apk/CieloRD_2024-0063_v1.0.apk
```

Una instalación debug no puede actualizarse directamente con este release por
usar una firma distinta. Conservar un respaldo privado seguro del keystore es
obligatorio para futuras actualizaciones compatibles.
