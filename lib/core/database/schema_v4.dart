/// Migración 3 -> 4: admite `theme = 'system'` en las preferencias.
///
/// SQLite no permite cambiar un CHECK, así que se recrea `app_settings` y se
/// copia la fila existente. Ninguna otra tabla la referencia. No editar una vez
/// distribuida: los cambios futuros van en v5.
const schemaV4Statements = <String>[
  '''CREATE TABLE app_settings_v4 (
    id INTEGER PRIMARY KEY CHECK(id = 1),
    theme TEXT NOT NULL DEFAULT 'night' CHECK(theme IN ('system','night','day','astronomer')),
    text_scale REAL CHECK(text_scale > 0 AND text_scale <= 3),
    reduced_motion INTEGER NOT NULL DEFAULT 0 CHECK(reduced_motion IN (0,1)),
    authentication_enabled INTEGER NOT NULL DEFAULT 0 CHECK(authentication_enabled IN (0,1))
  )''',
  'INSERT INTO app_settings_v4 (id, theme, text_scale, reduced_motion, authentication_enabled) '
      'SELECT id, theme, text_scale, reduced_motion, authentication_enabled FROM app_settings',
  'DROP TABLE app_settings',
  'ALTER TABLE app_settings_v4 RENAME TO app_settings',
];
