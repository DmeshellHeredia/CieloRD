/// Migración 2 -> 3: instante UTC de captura de una posición GPS fresca.
///
/// Es nullable para conservar observaciones GPS creadas antes de HITO B. No
/// editar una vez distribuida: los cambios futuros deben usar una migración
/// nueva.
const schemaV3Statements = <String>[
  'ALTER TABLE observations ADD COLUMN location_captured_at INTEGER',
];
