/// Textos visibles de CieloRD en español (República Dominicana).
///
/// Todo texto que vea la persona usuaria vive aquí, para mantener un
/// vocabulario coherente y permitir que las pruebas busquen el texto exacto.
/// Una acción conserva el mismo nombre en todo el flujo
/// ("Borrar todo" → "Datos borrados").
abstract final class CieloStrings {
  // ── App ────────────────────────────────────────────────────────────────
  static const String appName = 'CieloRD';
  static const String themeMenu = 'Tema de colores';
  static const String themeNight = 'Noche';
  static const String themeDay = 'Día';
  static const String themeAstro = 'Astrónomo (rojo)';
  static const String offlinePromise = 'Funciona sin conexión, desde la primera apertura.';

  // ── Acciones comunes ───────────────────────────────────────────────────
  static const String save = 'Guardar';
  static const String saving = 'Guardando…';
  static const String saveDraft = 'Guardar borrador';
  static const String publish = 'Publicar';
  static const String cancel = 'Cancelar';
  static const String close = 'Cerrar';
  static const String edit = 'Editar';
  static const String delete = 'Eliminar';
  static const String retry = 'Reintentar';
  static const String discardChanges = 'Descartar cambios';
  static const String keepEditing = 'Seguir editando';
  static const String openSettings = 'Abrir ajustes';
  static const String clearFilters = 'Limpiar filtros';
  static const String writePlace = 'Escribir el lugar';
  static const String useLastKnown = 'Usar última conocida';
  static const String loading = 'Cargando';
  static const String loadingObservations = 'Cargando observaciones';

  // ── Categorías raíz ────────────────────────────────────────────────────
  static const String categoryAstronomy = 'Astronomía';
  static const String categoryAtmospheric = 'Fenómeno atmosférico';
  static const String categoryAtmosphericShort = 'Atmosférico';
  static const String categoryBirds = 'Aves';
  static const String categoryArtificial = 'Aeronave u objeto artificial';
  static const String categoryArtificialShort = 'Artificial';
  static const String categoryOther = 'Otro';
  static const String categoryLabel = 'Categoría';

  // ── Condiciones del cielo ──────────────────────────────────────────────
  static const String skyConditionLabel = 'Condición del cielo';
  static const String skyClear = 'Despejado';
  static const String skyPartlyCloudy = 'Parcialmente nublado';
  static const String skyCloudy = 'Nublado';
  static const String skyHaze = 'Bruma';
  static const String skySaharanDust = 'Calima';
  static const String skySaharanDustHint = 'Polvo del Sahara';
  static const String skyLightRain = 'Lluvia ligera';
  static const String skyOther = 'Otra';
  static const String skyUnknown = 'No sé';

  // ── Dirección cardinal ─────────────────────────────────────────────────
  static const String directionLabel = 'Dirección';
  static const String directionNone = 'Sin dirección';
  static const String directionN = 'Norte';
  static const String directionNE = 'Noreste';
  static const String directionE = 'Este';
  static const String directionSE = 'Sureste';
  static const String directionS = 'Sur';
  static const String directionSW = 'Suroeste';
  static const String directionW = 'Oeste';
  static const String directionNW = 'Noroeste';

  // ── Duración ───────────────────────────────────────────────────────────
  static const String durationLabel = 'Duración';
  static const String durationOther = 'Otra';
  static const String durationRemove = 'Quitar duración';
  static const String durationMinutes = 'Minutos';
  static const String durationSeconds = 'Segundos';
  static const String durationOptional = 'Opcional';
  static String durationIncrease(String unit) => 'Aumentar $unit';
  static String durationDecrease(String unit) => 'Disminuir $unit';

  // ── Observaciones ──────────────────────────────────────────────────────
  static const String draft = 'Borrador';
  static const String complete = 'Completar';
  static const String gpsLocation = 'GPS';
  static const String manualLocation = 'Manual';
  static const String noLocation = 'Sin ubicación';
  static String photos(int n) => n == 1 ? '1 foto' : '$n fotos';
  static String voiceNotes(int n) => n == 1 ? '1 nota de voz' : '$n notas de voz';
  static String draftsPending(int n) =>
      n == 1 ? '1 borrador por completar' : '$n borradores por completar';

  // ── Diario ─────────────────────────────────────────────────────────────
  static const String diaryTitle = 'Diario';
  static const String register = 'Registrar';
  static const String searchHint = 'Buscar por título, descripción o lugar';
  static const String searchLabel = 'Buscar observaciones';
  static const String clearSearch = 'Borrar búsqueda';
  static const String filters = 'Filtros';
  static String filtersWithCount(int n) => n == 0 ? filters : '$filters ($n)';
  static const String showResults = 'Ver resultados';
  static const String clearAll = 'Quitar todo';
  static const String dateLabel = 'Fecha';
  static const String dateAny = 'Cualquier fecha';
  static const String dateToday = 'Hoy';
  static const String dateLast7 = 'Últimos 7 días';
  static const String dateLast30 = 'Últimos 30 días';
  static const String dateThisMonth = 'Este mes';
  static const String dateThisYear = 'Este año';
  static const String placeLabel = 'Lugar';
  static const String placeHint = 'Ej.: Constanza, Samaná';
  static String placeFilter(String place) => 'Lugar: $place';
  static const String statusLabel = 'Mostrar';
  static const String statusPublished = 'Publicadas';
  static const String statusDrafts = 'Borradores';
  static const String statusAll = 'Todas';
  static const String viewDrafts = 'Ver borradores';
  static String removeFilter(String filter) => 'Quitar filtro $filter';
  static const String noDate = 'Sin fecha ni hora';
  static const String untitled = 'Sin título';
  static String observationsCount(int n) => n == 1 ? '1 observación' : '$n observaciones';
  static String observationsCountMore(int n) => '$n+ observaciones';
  static const String loadMoreError = 'No se pudieron cargar más observaciones.';
  static const String loadingMore = 'Cargando más observaciones';
  static const String endOfDiary = 'Has llegado al principio de tu diario.';
  static const String draftsBannerMessage ='Complétalos y publícalos para que aparezcan en tu diario.';
  static const String emptyDraftsViewTitle = 'No tienes borradores';
  static const String emptyDraftsViewMessage =
      'Cuando guardes un registro rápido sin todos los datos, aparecerá aquí para completarlo.';

  // ── Formulario ─────────────────────────────────────────────────────────
  static const String newObservation = 'Nueva observación';
  static const String editObservation = 'Editar observación';
  static const String completeDraft = 'Completar borrador';
  static const String titleLabel = 'Título';
  static const String titleHint = 'Ej.: Lluvia de Leónidas sobre Valle Nuevo';
  static const String requiredToPublish = 'Obligatorio para publicar';
  static const String optional = 'Opcional';
  static const String dateTimeHelp = 'Hora local del lugar de la observación.';
  static const String changeDate = 'Cambiar fecha';
  static const String changeTime = 'Cambiar hora';
  static const String descriptionHint = 'Qué viste, cómo se movía, brillo, color…';
  static const String elevationToggle = 'Indicar altura sobre el horizonte';
  static String elevationValue(int degrees) => '$degrees°';
  static const String elevationHelp = '0° es el horizonte; 90°, justo encima de ti.';
  static const String locationLabel = 'Ubicación';
  static const String placeNameLabel = 'Lugar';
  static const String addCoordinates = 'Añadir coordenadas manuales';
  static const String removeCoordinates = 'Quitar coordenadas';
  static const String latitudeLabel = 'Latitud';
  static const String longitudeLabel = 'Longitud';
  static const String latitudeHint = '18.4861';
  static const String longitudeHint = '-69.9312';
  static const String coordinatesHelp = 'Grados decimales. En República Dominicana la longitud es negativa (Oeste).';
  static const String gpsComingSoon = 'El GPS se podrá usar desde el registro en una próxima versión.';
  static const String saveChanges = 'Guardar cambios';
  static const String publishing = 'Publicando…';
  static const String fixErrors = 'Revisa los campos marcados para poder publicar.';
  static const String published = 'Observación publicada';
  static const String draftSaved = 'Borrador guardado';
  static const String changesSaved = 'Cambios guardados';
  static const String observationDeleted = 'Observación eliminada';
  static const String discardTitle = '¿Descartar los cambios?';
  static const String discardMessage = 'Se perderán los cambios que hiciste en esta observación publicada.';
  static const String reload = 'Recargar';

  // Errores por campo (códigos del ObservationValidator).
  static const String fieldRequired = 'Este dato es obligatorio para publicar.';
  static const String fieldOutOfRange = 'El valor está fuera del rango permitido.';
  static const String fieldNonNegative = 'No puede ser negativo.';
  static const String fieldCoordinatesPair = 'Indica latitud y longitud juntas.';
  static const String fieldInvalidNumber = 'Escribe un número, por ejemplo 18.4861.';
  static const String fieldLatitudeRange = 'La latitud va de -90 a 90.';
  static const String fieldLongitudeRange = 'La longitud va de -180 a 180.';
  static const String fieldPlaceRequired = 'Escribe el nombre del lugar.';
  static const String fieldInvalid = 'Revisa este dato.';
  static const String fieldTooManyPhotos = 'Máximo 5 fotos por observación.';
  static const String fieldTooManyAudios = 'Máximo 3 notas de voz por observación.';

  // ── Registro rápido ────────────────────────────────────────────────────
  static const String quickRecord = 'Registro rápido';
  static String quickRecordNow(String time) => 'Ahora, $time';
  static const String quickTitleHint = 'Título (opcional)';
  static const String quickPlaceHint = 'Lugar (opcional)';
  static const String fullForm = 'Formulario completo';
  static const String chooseCategoryFirst = 'Elige una categoría para guardar.';

  // ── Detalle ────────────────────────────────────────────────────────────
  static const String detailTitle = 'Observación';
  static const String back = 'Volver';
  static const String observedAtLabel = 'Fecha y hora';
  static const String descriptionLabel = 'Descripción';
  static const String noDescription = 'Sin descripción.';
  static const String elevationLabel = 'Altura estimada';
  static String elevation(double degrees) => '${degrees.round()}° sobre el horizonte';
  static const String coordinatesLabel = 'Coordenadas';
  static const String mediaLabel = 'Fotos y notas de voz';
  static const String noMedia = 'Sin fotos ni notas de voz.';
  static const String unknownValue = 'No registrado';

  // ── Errores por código (FailureCode) ───────────────────────────────────
  static const String failureValidation = 'Algunos datos no son válidos. Revísalos e inténtalo de nuevo.';
  static const String failureConflict =
      'Esta observación cambió mientras la editabas. Recarga para ver la versión más reciente.';
  static const String failurePermissionDenied = 'CieloRD no tiene el permiso necesario para esta acción.';
  static const String failurePermissionPermanentlyDenied =
      'El permiso está desactivado en Ajustes del teléfono.';
  static const String failureServiceDisabled = 'El servicio necesario está apagado en el teléfono.';
  static const String failureTimeout = 'La operación tardó demasiado. Inténtalo de nuevo.';
  static const String failureCorruptData =
      'Hay datos dañados que no se pudieron leer. El resto de tu diario sigue disponible.';
  static const String failureUnsupportedVersion = 'Estos datos vienen de una versión más nueva de CieloRD.';
  static const String failurePersistence =
      'No se pudo leer o guardar en la base de datos del teléfono. Inténtalo de nuevo.';
  static const String failureIo = 'No se pudo acceder a un archivo del teléfono.';
  static const String failureUnavailable = 'Esta función aún no está disponible.';
  static const String failureUnexpected = 'Ocurrió un error inesperado. Inténtalo de nuevo.';

  // ── Estados vacíos ─────────────────────────────────────────────────────
  static const String emptyDiaryTitle = 'Tu cielo aún está por escribirse';
  static const String emptyDiaryMessage =
      'Registra lo que veas esta noche: una lluvia de meteoros, un halo o el paso de la Estación Espacial.';
  static const String emptyDiaryAction = 'Registrar primera observación';
  static const String noResultsTitle = 'Ninguna observación coincide';
  static String noResultsMessage(String query) => query.isEmpty
      ? 'Prueba con otros filtros o quítalos para ver todo tu diario.'
      : 'No hay resultados para «$query» con los filtros actuales.';
  static const String noDraftsTitle = 'No tienes borradores pendientes';
  static const String noDraftsMessage =
      'Los registros rápidos sin datos completos aparecerán aquí para que los termines.';
  static const String statsNotEnoughTitle = 'Aún no hay tendencias';
  static String statsNotEnoughMessage(int count) =>
      'Registra al menos 3 observaciones para ver estadísticas. Llevas $count.';

  // ── Errores ────────────────────────────────────────────────────────────
  static const String errorTitle = 'Algo no salió como esperábamos';
  static const String errorLoadObservations =
      'No se pudieron cargar las observaciones. Tus datos siguen guardados en el teléfono.';
  static const String errorSave = 'No se pudo guardar. Tu borrador está a salvo.';
  static const String errorStorageFull = 'No hay espacio suficiente en el teléfono.';
  static const String errorNotFound = 'Esta observación ya no existe.';
  static const String errorLocationDenied =
      'Sin permiso de ubicación. Puedes escribir el lugar o marcarlo a mano.';
  static const String errorLocationDeniedForever =
      'El permiso de ubicación está desactivado en Ajustes. Puedes escribir el lugar a mano.';
  static const String errorGpsOff = 'El GPS está apagado. Puedes escribir el lugar a mano.';
  static String errorGpsTimeout(int meters) =>
      'No logramos una señal precisa. Usamos la última conocida (±$meters m).';
  static const String errorCameraDenied =
      'Sin acceso a la cámara. Puedes elegir una foto de la galería.';
  static const String errorMicDenied =
      'Sin acceso al micrófono. No se pueden grabar notas de voz.';
  static String errorRecordingInterrupted(String elapsed) =>
      'La grabación se interrumpió. Se guardó lo grabado hasta $elapsed.';
  static const String errorImportInvalid = 'Este archivo no es una copia de CieloRD.';
  static const String errorImportNewer = 'Esta copia viene de una versión más nueva de CieloRD.';
  static const String errorAuthUnavailable =
      'Configura una huella o un PIN en tu teléfono para usar el bloqueo.';
  static const String errorAuthLockedOut = 'Demasiados intentos. Usa el PIN del teléfono.';

  // ── Diálogos ───────────────────────────────────────────────────────────
  static const String deleteObservationTitle = '¿Eliminar esta observación?';
  static const String deleteObservationMessage =
      'Se eliminarán también sus fotos y notas de voz guardadas en CieloRD.';
  static const String eraseAllTitle = '¿Borrar todos los datos de CieloRD?';
  static const String eraseAllMessage =
      'CieloRD quedará como recién instalada. Esta acción no se puede deshacer.';
  static const String eraseAllAction = 'Borrar todo';
  static const String eraseAllDone = 'Datos borrados';
  static const String eraseAllAcknowledge = 'Entiendo que no se puede deshacer';
  static const String eraseAllExportFirst = 'Exportar una copia antes';
  static const String eraseAllKeepsExternal =
      'No se tocan las fotos originales de tu galería ni las copias exportadas fuera de la app.';
  static String eraseAllObservations(int n) =>
      n == 1 ? '1 observación y sus borradores' : '$n observaciones y sus borradores';
  static String eraseAllPhotos(int n) => n == 1 ? '1 foto guardada' : '$n fotos guardadas';
  static String eraseAllAudios(int n) => n == 1 ? '1 nota de voz' : '$n notas de voz';
  static const String eraseAllProfile = 'Tu perfil, foto y preferencias';

  static const String unsavedTitle = '¿Guardar los cambios como borrador?';
  static const String unsavedMessage =
      'Si sales ahora sin guardar, perderás lo que escribiste en esta observación.';

  // ── Accesibilidad ──────────────────────────────────────────────────────
  static const String selected = 'seleccionado';
  static String thumbnailOf(String title) => 'Foto de $title';

  // ── Hito C: común ──────────────────────────────────────────────────────
  static const String failureBusy =
      'CieloRD está terminando otra operación con tus datos. Espera un momento e inténtalo de nuevo.';
  static const String done = 'Listo';
  static const String goToDiary = 'Ir al Diario';
  static const String offlineMap = 'Mapa offline';
  static String attachments(int n) => n == 1 ? '1 adjunto' : '$n adjuntos';

  // ── Perfil y Acerca de ─────────────────────────────────────────────────
  static const String profileTitle = 'Perfil';
  static const String profileEdit = 'Editar perfil';
  static const String profileSaved = 'Perfil guardado';
  static const String profileEmpty = 'Crea tu perfil para añadir tus datos.';
  static const String profilePhotoEmpty = 'Sin foto de perfil';
  static const String profilePhoto = 'Foto del perfil';
  static const String profilePhotoRemove = 'Quitar foto';
  static const String profilePhotoCamera = 'Tomar foto';
  static const String profilePhotoGallery = 'Elegir de la galería';
  static const String profileFirstName = 'Nombre';
  static const String profileLastName = 'Apellido';
  static const String profileStudentId = 'Matrícula';
  static const String profileStudentIdHelp = 'Escríbela tal como aparece en tu carné.';
  static const String profileMotto = 'Frase motivadora';
  static const String profilePrivacy = 'Estos datos se guardan solo en este teléfono.';
  static const String profileTooLong = 'El texto es demasiado largo.';
  static const String profileInvalidCharacters = 'Quita los saltos de línea y caracteres especiales.';
  static const String profileDiscardMessage = 'Se perderán los cambios que hiciste en tu perfil.';
  static const String aboutTitle = 'Acerca de';
  static String aboutVersion(String version) => 'Versión $version';
  static const String aboutObserver = 'Observador';
  static const String aboutMap = 'Créditos del mapa';
  static const String aboutMapCredit =
      'Límites provinciales: geoBoundaries gbOpen DOM-ADM1-93820187 (2022). Fuente: Natural Earth. Dominio público.';
  static const String aboutMapScope =
      'El mapa muestra solo límites provinciales; no incluye calles ni direcciones.';
  static const String aboutLicenses = 'Licencias';
  static const String aboutFonts =
      'Tipografías Atkinson Hyperlegible y Space Grotesk: SIL Open Font License 1.1.';
  static const String aboutLicensesAll = 'Ver todas las licencias';

  // ── Estadísticas ───────────────────────────────────────────────────────
  static const String statsTitle = 'Estadísticas';
  static const String statsTotal = 'Publicadas';
  static const String statsThisMonth = 'Este mes';
  static const String statsDuration = 'Tiempo observado';
  static String statsDurationFrom(int n) =>
      n == 1 ? 'De 1 observación con duración' : 'De $n observaciones con duración';
  static const String statsDurationNone = 'Sin duraciones registradas';
  static const String statsDraftsExcluded = 'Los borradores no se cuentan.';
  static const String statsByCategory = 'Por categoría';
  static const String statsByMonth = 'Por mes';
  static const String statsByMonthHint = 'Últimos 12 meses';
  static const String statsByHour = 'Por hora';
  static const String statsByHourHint = 'Hora local de cada observación';
  static const String statsProvinces = 'Provincias más frecuentes';
  static const String statsProvincesHint = 'Según las coordenadas';
  static const String statsNoProvinces =
      'Aún no hay observaciones con coordenadas dentro del mapa.';
  static const String statsPlaces = 'Lugares más frecuentes';
  static const String statsPlacesHint = 'Según el nombre escrito';
  static const String statsNoPlaces = 'Aún no hay lugares escritos.';
  static const String statsEmptyTitle = 'Aún no hay estadísticas';
  static const String statsEmptyMessage =
      'Publica tu primera observación y aquí verás cuándo, qué y dónde observas.';
  static const String statsShowTable = 'Ver como tabla';
  static const String statsShowChart = 'Ver como gráfico';
  static String statsPeak(String label, String count) => 'Máximo: $label, $count.';

  // ── Ajustes ────────────────────────────────────────────────────────────
  static const String settingsTitle = 'Ajustes';
  static const String settingsAppearance = 'Apariencia';
  static const String settingsTheme = 'Tema';
  static const String themeSystem = 'Sistema';
  static const String themeSystemHint = 'Sistema usa Día o Noche según el teléfono. Astrónomo usa solo rojo para conservar la visión nocturna.';
  static const String settingsReducedMotion = 'Reducir movimiento';
  static const String settingsReducedMotionHint = 'Quita transiciones y animaciones de la app';
  static const String settingsReducedMotionSystem = 'Tu teléfono ya tiene desactivadas las animaciones';
  static const String settingsSecurity = 'Seguridad';
  static const String settingsLock = 'Bloquear CieloRD';
  static const String settingsLockHint =
      'Pide la huella, el rostro o el PIN del teléfono al abrir y al volver';
  static const String settingsLockScope =
      'El bloqueo protege el acceso a la app en este teléfono. No cifra la base de datos ni los archivos.';
  static const String settingsLockNoCredentials =
      'Este teléfono no tiene huella, rostro ni PIN configurados. Actívalos en los ajustes del teléfono para usar el bloqueo.';
  static const String settingsData = 'Datos';
  static const String settingsAbout = 'Información';
  static const String settingsSaveFailed =
      'No se pudo guardar la preferencia. Se restauró el valor anterior.';

  // ── Bloqueo ────────────────────────────────────────────────────────────
  static const String lockTitle = 'CieloRD está bloqueada';
  static const String lockMessage =
      'Usa la huella, el rostro o el PIN del teléfono para abrir tu diario.';
  static const String lockUnlock = 'Desbloquear';
  static const String lockUnlocking = 'Esperando al teléfono…';
  static const String lockPromptTitle = 'CieloRD';
  static const String lockPromptHint = 'Confirma tu identidad';
  static const String lockReasonOpen = 'Desbloquea tu diario de observaciones';
  static const String lockReasonEnable = 'Confirma para activar el bloqueo';
  static const String lockReasonDisable = 'Confirma para desactivar el bloqueo';
  static const String lockEnabled = 'Bloqueo activado';
  static const String lockDisabled = 'Bloqueo desactivado';
  static const String lockCancelled = 'No se confirmó tu identidad.';
  static const String lockFailed = 'El teléfono no reconoció tu identidad. Inténtalo de nuevo.';
  static const String lockTemporarily = 'Demasiados intentos. Espera unos segundos y vuelve a intentarlo.';
  static const String lockBiometric =
      'La biometría está bloqueada. Desbloquea el teléfono con tu PIN y vuelve a intentarlo.';
  static const String lockUnavailable =
      'El teléfono no pudo verificar tu identidad ahora. Inténtalo de nuevo.';
  static const String lockCredentialsMissing =
      'El teléfono ya no tiene PIN ni biometría, así que CieloRD no puede verificar tu identidad.';
  static const String lockOpenWithout = 'Desactivar bloqueo y abrir';
  static const String startupFailureTitle = 'No se pudieron leer tus preferencias';
  static const String startupFailureMessage =
      'CieloRD no puede abrirse sin saber si el bloqueo está activado. Tus datos no se han modificado.';

  // ── Exportar e importar ────────────────────────────────────────────────
  static const String exportTitle = 'Exportar';
  static const String exportHint = 'Guarda una copia fuera de CieloRD';
  static const String exportZip = 'Copia completa (ZIP)';
  static const String exportZipHint =
      'Observaciones, borradores, fotos y notas de voz. Se puede importar en CieloRD.';
  static const String exportJson = 'Solo datos (JSON)';
  static const String exportJsonHint =
      'Texto legible con todas las observaciones, sin fotos ni audios. No se puede importar.';
  static const String exportIncludeProfile = 'Incluir mi perfil';
  static const String exportPrivacy =
      'La copia no va cifrada: quien tenga el archivo podrá ver tus observaciones, ubicaciones, fotos y audios. No incluye preferencias ni el bloqueo.';
  static const String exporting = 'Exportando…';
  static const String exportDone = 'Copia guardada';
  static String exportSummary(int observations, int media) =>
      '${observationsCount(observations)} y ${attachments(media)}.';
  static String exportMissing(int n) => n == 1
      ? '1 adjunto no se incluyó porque su archivo falta o está dañado.'
      : '$n adjuntos no se incluyeron porque sus archivos faltan o están dañados.';
  static const String exportFailed = 'No se pudo exportar';
  static const String importTitle = 'Importar';
  static const String importHint = 'Recupera una copia completa (ZIP)';
  static const String importIntro =
      'Elige una copia ZIP hecha con CieloRD. Primero se revisa entera; no se cambia nada hasta que confirmes.';
  static const String importMerge =
      'Se suma a lo que ya tienes: nunca sobrescribe tus observaciones ni tu perfil.';
  static const String importChoose = 'Elegir copia';
  static const String importInspecting = 'Revisando la copia…';
  static const String importPreviewTitle = 'Contenido de la copia';
  static const String importCreated = 'Creada';
  static const String importVersion = 'Versión de CieloRD';
  static const String importFormat = 'Formato de copia';
  static const String importObservations = 'Observaciones';
  static const String importDrafts = 'De ellas, borradores';
  static const String importPhotos = 'Fotos';
  static const String importAudios = 'Notas de voz';
  static const String importPlanTitle = 'Qué pasará al importar';
  static String importNew(int n) =>
      n == 1 ? '1 observación nueva se añade' : '$n observaciones nuevas se añaden';
  static String importIdentical(int n) =>
      n == 1 ? '1 ya está en el teléfono y se omite' : '$n ya están en el teléfono y se omiten';
  static String importCopies(int n) => n == 1
      ? '1 es distinta de la tuya: se añade como copia y la tuya no cambia'
      : '$n son distintas de las tuyas: se añaden como copia y las tuyas no cambian';
  static const String importProfileYes = 'El perfil se importa porque aún no tienes uno';
  static const String importProfileNo = 'Tu perfil actual se conserva';
  static String importMissing(int n) => n == 1
      ? 'Falta 1 adjunto que ya no estaba al crear la copia'
      : 'Faltan $n adjuntos que ya no estaban al crear la copia';
  static const String importNothing = 'Todo lo de esta copia ya está en el teléfono.';
  static const String importing = 'Importando…';
  static const String importDone = 'Importación terminada';
  static String importSummary(int observations, int media) =>
      'Se añadieron ${observationsCount(observations)} y ${attachments(media)}.';
  static const String importProfileDone = 'Se importó tu perfil';
  static String importIdenticalDone(int n) => n == 1
      ? 'Se omitió 1 que ya estaba en el teléfono'
      : 'Se omitieron $n que ya estaban en el teléfono';
  static String importCopiesDone(int n) => n == 1
      ? '1 se añadió como copia; la tuya no cambió'
      : '$n se añadieron como copia; las tuyas no cambiaron';
  static const String importFailed = 'No se importó nada';
  static const String importFailedSuffix = 'Tus datos no cambiaron.';
  static const String importNotAZip = 'Este archivo no es un ZIP válido o está incompleto.';
  static const String importUnsafe = 'La copia contiene rutas no permitidas y se rechazó por seguridad.';
  static const String importUnexpected = 'La copia contiene archivos que CieloRD no reconoce.';
  static const String importTooLarge = 'La copia es demasiado grande para importarla en el teléfono.';
  static const String importHash =
      'La copia está dañada: algún archivo no coincide con su comprobación.';
  static const String importWrongType = 'La copia contiene un adjunto que no es una foto o audio válido.';
  static const String importExpired = 'La revisión caducó. Vuelve a elegir la copia.';
  static const String exportTooLarge = 'Tus datos superan el tamaño máximo de una copia (2 GB).';
  static String backupPhase(String phase) => switch (phase) {
    'read' => 'Leyendo observaciones',
    'media' => 'Añadiendo adjuntos',
    'verify' => 'Comprobando la copia',
    'write' => 'Guardando el archivo',
    'copy' => 'Abriendo la copia',
    'extract' => 'Preparando adjuntos',
    _ => 'Trabajando',
  };

  // ── Borrar todo ────────────────────────────────────────────────────────
  static const String eraseHint = 'Elimina todos los datos privados de CieloRD';
  static const String eraseCounting = 'Contando tus datos';
  static const String eraseWillDelete = 'Se borrará de este teléfono';
  static const String eraseWillKeep = 'No se toca';
  static String erasePublished(int n) =>
      n == 1 ? '1 observación publicada' : '$n observaciones publicadas';
  static String eraseDrafts(int n) => n == 1 ? '1 borrador' : '$n borradores';
  static const String eraseProfileOnly = 'Tu perfil';
  static const String eraseProfileWithPhoto = 'Tu perfil y su foto';
  static const String eraseProfileNone = 'Perfil: no hay ninguno guardado';
  static const String eraseSettings = 'Preferencias y bloqueo, que vuelven a su valor inicial';
  static String eraseTemporary(int n) => n == 1
      ? '1 archivo temporal o pendiente de limpieza'
      : '$n archivos temporales o pendientes de limpieza';
  static const String eraseKeepOriginals = 'Las fotos originales de tu galería';
  static const String eraseKeepExports = 'Las copias que exportaste fuera de CieloRD';
  static const String eraseKeepResources = 'El mapa, las fuentes y los recursos de la app';
  static const String eraseNotForensic =
      'CieloRD elimina los archivos y lo comprueba, pero no puede garantizar que no se recuperen con herramientas forenses.';
  static const String erasing = 'Borrando…';
  static const String eraseDoneMessage =
      'Se comprobó que no queda ningún dato privado. CieloRD está como recién instalada.';
  static const String erasePartialTitle = 'El borrado no se completó';
  static String erasePartialFiles(int n) =>
      n == 1 ? 'Queda 1 archivo privado sin eliminar.' : 'Quedan $n archivos privados sin eliminar.';
  static const String erasePartialDatabase = 'La base de datos no se pudo vaciar del todo.';
  static const String erasePartialPreferences = 'Quedan preferencias internas sin limpiar.';
  static const String erasePartialRetry =
      'Reintenta ahora. Si cierras la app, el borrado continuará la próxima vez que la abras.';
  static const String erasePendingMessage =
      'Un borrado anterior se interrumpió. Termínalo para asegurarte de que no queda nada.';
  static const String eraseFinish = 'Terminar borrado';
}
