import '../../../core/domain/app_failure.dart';
import '../../../core/domain/result.dart';
import 'observation_input.dart';
import 'observation_types.dart';

final class ObservationValidator {
  const ObservationValidator();
  Result<ObservationInput> validate(
    ObservationInput input, {
    required ObservationStatus status,
  }) {
    final errors = <String, String>{};
    if (status == ObservationStatus.published) {
      if (input.title.trim().isEmpty) errors['title'] = 'required';
      if (input.observedAt == null) errors['observedAt'] = 'required';
      if (input.category == null) errors['category'] = 'required';
    }
    if ((input.observedAt == null) != (input.utcOffsetMinutes == null)) {
      errors['utcOffsetMinutes'] = 'time_offset_pair_required';
    }
    final offset = input.utcOffsetMinutes;
    if (offset != null && (offset < -840 || offset > 840)) {
      errors['utcOffsetMinutes'] = 'out_of_range';
    }
    final duration = input.durationSeconds;
    if (duration != null && duration < 0) {
      errors['durationSeconds'] = 'non_negative';
    }
    final elevation = input.elevationDegrees;
    if (elevation != null &&
        (!elevation.isFinite || elevation < 0 || elevation > 90)) {
      errors['elevationDegrees'] = 'out_of_range';
    }
    final subtype = input.subtypeCode;
    if (subtype != null && !RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(subtype)) {
      errors['subtypeCode'] = 'invalid_code';
    }
    final location = input.location;
    if (location != null) {
      final lat = location.latitude;
      final lon = location.longitude;
      if ((lat == null) != (lon == null)) {
        errors['location.coordinates'] = 'pair_required';
      }
      if (lat != null && (!lat.isFinite || lat < -90 || lat > 90)) {
        errors['location.latitude'] = 'out_of_range';
      }
      if (lon != null && (!lon.isFinite || lon < -180 || lon > 180)) {
        errors['location.longitude'] = 'out_of_range';
      }
      if (lat != null &&
          lon != null &&
          location.source != LocationSource.gps &&
          location.source != LocationSource.manual) {
        errors['location.source'] = 'coordinate_source_required';
      }
      if ((location.source == LocationSource.gps ||
              location.source == LocationSource.manual) &&
          !location.hasCoordinates) {
        errors['location.coordinates'] = 'required';
      }
      if (location.source == LocationSource.text &&
          (location.placeName?.trim().isEmpty ?? true)) {
        errors['location.placeName'] = 'required';
      }
      final accuracy = location.accuracyM;
      if (accuracy != null &&
          (!accuracy.isFinite ||
              accuracy < 0 ||
              location.source != LocationSource.gps ||
              !location.hasCoordinates)) {
        errors['location.accuracyM'] = 'invalid_accuracy';
      }
      final capturedAt = location.capturedAt;
      if (capturedAt != null &&
          (location.source != LocationSource.gps ||
              !location.hasCoordinates ||
              !capturedAt.isUtc)) {
        errors['location.capturedAt'] = 'gps_utc_coordinates_required';
      }
    }
    if (input.media.where((m) => m.kind == MediaKind.photo).length > 5) {
      errors['media.photos'] = 'max_5';
    }
    if (input.media.where((m) => m.kind == MediaKind.audio).length > 3) {
      errors['media.audios'] = 'max_3';
    }
    final ids = <String>{};
    for (var i = 0; i < input.media.length; i++) {
      final m = input.media[i];
      final prefix = 'media.$i';
      if (m.id.trim().isEmpty || !ids.add(m.id)) {
        errors['$prefix.id'] = 'invalid_or_duplicate';
      }
      if (!_safeRelativePath(m.relativePath)) {
        errors['$prefix.relativePath'] = 'unsafe_path';
      }
      if (m.byteSize <= 0) errors['$prefix.byteSize'] = 'positive_required';
      if (!m.mimeType.startsWith(
        m.kind == MediaKind.photo ? 'image/' : 'audio/',
      )) {
        errors['$prefix.mimeType'] = 'wrong_media_type';
      }
      if (m.kind == MediaKind.audio &&
          (m.durationMs == null ||
              m.durationMs! <= 0 ||
              m.durationMs! > 120000)) {
        errors['$prefix.durationMs'] = 'audio_duration_1_120000';
      }
      if (m.kind == MediaKind.photo && m.durationMs != null) {
        errors['$prefix.durationMs'] = 'photo_has_no_duration';
      }
      if (m.sha256 != null && !RegExp(r'^[a-f0-9]{64}$').hasMatch(m.sha256!)) {
        errors['$prefix.sha256'] = 'invalid_hash';
      }
    }
    return errors.isEmpty
        ? Success(input)
        : Failure(AppFailure(FailureCode.validation, fieldErrors: errors));
  }

  bool _safeRelativePath(String path) =>
      path.isNotEmpty &&
      !path.startsWith('/') &&
      !path.contains('\\') &&
      !path.contains(':') &&
      !path.contains('\u0000') &&
      path.split('/').every((p) => p.isNotEmpty && p != '.' && p != '..');
}
