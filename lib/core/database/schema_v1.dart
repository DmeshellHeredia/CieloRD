/// Immutable migration 0 -> 1. Add new migrations instead of editing a shipped v1.
const schemaV1Statements = <String>[
  '''CREATE TABLE observations (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(trim(id)) > 0),
    status TEXT NOT NULL CHECK(status IN ('draft','published')),
    title TEXT NOT NULL DEFAULT '',
    observed_at_utc_ms INTEGER,
    utc_offset_minutes INTEGER CHECK(utc_offset_minutes BETWEEN -840 AND 840),
    category_code TEXT CHECK(category_code IN ('astronomy','atmospheric','birds','artificial','other')),
    subtype_code TEXT,
    sky_condition_code TEXT CHECK(sky_condition_code IN ('clear','partly_cloudy','cloudy','mist','saharan_dust','light_rain','other','unknown')),
    description TEXT,
    duration_seconds INTEGER CHECK(duration_seconds >= 0),
    direction_code TEXT CHECK(direction_code IN ('n','ne','e','se','s','sw','w','nw')),
    elevation_degrees REAL CHECK(elevation_degrees BETWEEN 0 AND 90),
    place_name TEXT,
    place_search TEXT,
    latitude REAL CHECK(latitude BETWEEN -90 AND 90),
    longitude REAL CHECK(longitude BETWEEN -180 AND 180),
    location_source TEXT CHECK(location_source IN ('text','manual','gps')),
    accuracy_m REAL CHECK(accuracy_m >= 0),
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL CHECK(updated_at >= created_at),
    revision INTEGER NOT NULL DEFAULT 1 CHECK(revision >= 1),
    CHECK((observed_at_utc_ms IS NULL AND utc_offset_minutes IS NULL) OR
          (observed_at_utc_ms IS NOT NULL AND utc_offset_minutes IS NOT NULL)),
    CHECK(status = 'draft' OR (length(trim(title)) > 0 AND
          observed_at_utc_ms IS NOT NULL AND category_code IS NOT NULL)),
    CHECK((latitude IS NULL AND longitude IS NULL) OR
          (latitude IS NOT NULL AND longitude IS NOT NULL)),
    CHECK(latitude IS NULL OR (location_source IS NOT NULL AND location_source IN ('manual','gps'))),
    CHECK(location_source IS NULL OR location_source = 'text' OR latitude IS NOT NULL),
    CHECK(location_source IS NULL OR location_source != 'text' OR
          (place_name IS NOT NULL AND length(trim(place_name)) > 0)),
    CHECK(accuracy_m IS NULL OR (location_source IS NOT NULL AND location_source = 'gps' AND latitude IS NOT NULL))
  )''',
  '''CREATE TABLE media_files (
    id TEXT PRIMARY KEY NOT NULL CHECK(length(trim(id)) > 0),
    relative_path TEXT NOT NULL UNIQUE CHECK(length(relative_path) > 0),
    mime_type TEXT NOT NULL,
    byte_size INTEGER NOT NULL CHECK(byte_size > 0),
    sha256 TEXT CHECK(sha256 IS NULL OR (length(sha256) = 64 AND sha256 NOT GLOB '*[^0-9a-f]*')),
    duration_ms INTEGER CHECK(duration_ms > 0 AND duration_ms <= 120000),
    created_at INTEGER NOT NULL
  )''',
  '''CREATE TABLE observation_media (
    observation_id TEXT NOT NULL REFERENCES observations(id) ON DELETE CASCADE,
    media_id TEXT NOT NULL UNIQUE REFERENCES media_files(id) ON DELETE RESTRICT,
    kind TEXT NOT NULL CHECK(kind IN ('photo','audio')),
    sort_order INTEGER NOT NULL CHECK(sort_order >= 0),
    PRIMARY KEY(observation_id, media_id),
    UNIQUE(observation_id, sort_order)
  )''',
  '''CREATE TABLE observer_profile (
    id INTEGER PRIMARY KEY CHECK(id = 1),
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    student_id TEXT NOT NULL,
    motto TEXT NOT NULL,
    photo_media_id TEXT REFERENCES media_files(id) ON DELETE RESTRICT
  )''',
  '''CREATE TABLE app_settings (
    id INTEGER PRIMARY KEY CHECK(id = 1),
    theme TEXT NOT NULL DEFAULT 'night' CHECK(theme IN ('night','day','astronomer')),
    text_scale REAL CHECK(text_scale > 0 AND text_scale <= 3),
    reduced_motion INTEGER NOT NULL DEFAULT 0 CHECK(reduced_motion IN (0,1)),
    authentication_enabled INTEGER NOT NULL DEFAULT 0 CHECK(authentication_enabled IN (0,1))
  )''',
  '''CREATE TABLE pending_file_deletions (
    relative_path TEXT PRIMARY KEY NOT NULL CHECK(length(relative_path) > 0),
    created_at INTEGER NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0 CHECK(attempts >= 0),
    last_error TEXT
  )''',
  'CREATE INDEX observations_date_idx ON observations(status, observed_at_utc_ms DESC, id DESC)',
  'CREATE INDEX observations_category_idx ON observations(status, category_code, observed_at_utc_ms DESC, id DESC)',
  'CREATE INDEX observations_place_idx ON observations(place_search)',
  'CREATE INDEX profile_photo_idx ON observer_profile(photo_media_id)',
];
