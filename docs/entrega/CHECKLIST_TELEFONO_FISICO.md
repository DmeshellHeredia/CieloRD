# Checklist de teléfono físico — CieloRD 1.0.0+1

Ejecutar sobre el APK release candidato identificado en `ESTADO.md`. Registrar
modelo, versión Android, fecha, resultado y evidencia. No usar información
personal real si el teléfono no pertenece al responsable.

## Preparación

- [ ] Confirmar SHA-256 del APK antes de copiarlo.
- [ ] Exportar datos de cualquier instalación debug previa y desinstalarla;
      debug y release no comparten firma.
- [ ] Activar modo avión **antes del primer lanzamiento**.
- [ ] Instalar release desde una fuente autorizada y revocar luego el permiso
      “instalar apps desconocidas” si se habilitó temporalmente.
- [ ] Verificar etiqueta `CieloRD`, icono adaptativo y splash sin destello blanco.
- [ ] Confirmar versión `1.0.0 (1)` en Acerca de.

## Requisitos esenciales

- [ ] Confirmar que el perfil inicial muestra foto, nombre, apellidos,
      matrícula `2024-0063` y frase; editarlo y comprobar persistencia.
- [ ] Crear una observación publicada sin GPS usando lugar escrito.
- [ ] Crear un borrador incompleto, cerrar/reabrir, editarlo y publicarlo.
- [ ] Buscar y combinar filtros de fecha, categoría y lugar.
- [ ] Editar una observación y confirmar refresco del Diario.
- [ ] Abrir detalle y comprobar ubicación escrita cuando no hay coordenadas.
- [ ] Usar mapa offline y comprobar marcador/coordenadas sin internet.

## GPS y permisos

- [ ] Denegar ubicación y confirmar que aún guarda con ubicación manual.
- [ ] Conceder aproximada y registrar precisión mostrada.
- [ ] Conceder precisa, capturar GPS real y verificar provincia/marcador.
- [ ] Desactivar servicio de ubicación y comprobar mensaje recuperable.
- [ ] Denegar permanentemente y comprobar orientación a Ajustes sin bloqueo.

## Fotos y audio

- [ ] Cámara real: capturar foto, guardar, cerrar app y verificar persistencia.
- [ ] Galería: seleccionar original, guardar y confirmar que CieloRD no lo borra.
- [ ] Probar foto grande y cinco fotos; la sexta debe rechazarse claramente.
- [ ] Grabar, pausar/reproducir y oír una nota; reiniciar y volver a reproducir.
- [ ] Mantener grabación hasta 120 s y confirmar entrega automática una vez.
- [ ] Interrumpir por llamada/cambio de salida/background y verificar recuperación.
- [ ] Cancelar una edición con medios nuevos y comprobar ausencia de huérfanos.

## Datos, seguridad y accesibilidad

- [ ] Exportar ZIP a almacenamiento local y a un proveedor disponible.
- [ ] Borrar Todo, reiniciar y confirmar ausencia de datos/medios privados.
- [ ] Confirmar que originales y ZIP externo permanecen.
- [ ] Importar ZIP y comprobar conteos, fotos y audios byte/visualmente.
- [ ] Simular falta de espacio al exportar/importar y verificar fallo recuperable.
- [ ] Activar bloqueo con huella/rostro/credencial y probar cancelación/bloqueo.
- [ ] Probar TalkBack, orden de foco, etiquetas y controles de audio.
- [ ] Probar texto máximo, movimiento reducido y temas Día/Noche/Astrónomo.

## Matriz mínima de dispositivos

- [ ] Teléfono principal Android 13 o superior.
- [ ] Un segundo dispositivo o teléfono Android 7–12 si está disponible.
- [ ] Probar rotación, suspensión, retorno desde Recientes y arranque en frío.
- [ ] Revisar batería/temperatura y tiempos con una copia de cientos de MB si es
      viable sin comprometer la fecha de entrega.

## Cierre

- [ ] Restaurar red, permisos y ajustes temporales.
- [ ] Eliminar únicamente datos de prueba creados para QA.
- [ ] Registrar fallos con pasos, captura y logcat; no publicar el APK hasta
      resolver fallos críticos/importantes.
