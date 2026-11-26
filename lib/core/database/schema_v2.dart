/// Migración 1 -> 2: búsqueda normalizada en título, descripción y lugar.
///
/// SQLite de Android no pliega acentos y sqflite no permite registrar
/// funciones propias, así que el texto normalizado se calcula en Dart al
/// escribir (`search_text`) y se rellena aquí para las filas existentes.
/// No editar una vez distribuida: los cambios futuros van en v3.
const schemaV2Statements = <String>[
  "ALTER TABLE observations ADD COLUMN search_text TEXT NOT NULL DEFAULT ''",
];
