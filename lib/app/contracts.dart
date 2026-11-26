/// Canonical UI import. Never exports SQLite or platform plugin types.
library;

export '../core/domain/app_failure.dart';
export '../core/domain/result.dart';
export '../features/observations/domain/observation.dart';
export '../features/observations/domain/observation_input.dart';
export '../features/observations/domain/observation_types.dart';
export '../features/observations/domain/observation_filter.dart';
export '../features/observations/domain/observation_validator.dart';
export '../features/observations/domain/observation_repository.dart';
export '../features/observations/domain/observation_service.dart';
export '../features/observations/application/observation_form_controller.dart';
export '../features/location/domain/location_service.dart';
export '../features/media/domain/media_service.dart';
export '../features/profile/domain/profile_repository.dart';
export '../features/settings/domain/settings_repository.dart';
export '../features/statistics/domain/stats_service.dart';
export '../features/backup/domain/backup_service.dart';
export '../features/maintenance/domain/erase_all_service.dart';
export '../features/security/domain/local_auth_service.dart';
