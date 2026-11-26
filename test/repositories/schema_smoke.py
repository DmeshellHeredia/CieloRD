"""Fallback SQLite checks; no Flutter, packages, downloads or shared DB writes.

Pipe dump_schema.dart output to this script. It tests the production SQL,
not sqflite callbacks or Android integration (those remain separate gates).
"""
import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

STATEMENTS = json.load(sys.stdin)


class SchemaTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cielord_c0_")
        self.path = Path(self.temp.name) / "test.db"
        self.db = sqlite3.connect(self.path)
        self.db.execute("PRAGMA foreign_keys = ON")
        with self.db:
            for statement in STATEMENTS:
                self.db.execute(statement)

    def tearDown(self):
        self.db.close()
        self.temp.cleanup()

    def draft(self, identifier="draft"):
        self.db.execute("INSERT INTO observations(id,status,title,created_at,updated_at) VALUES (?,'draft','',1,1)", (identifier,))

    def test_empty_draft_persists_after_reopen(self):
        self.draft()
        self.db.commit()
        self.db.close()
        self.db = sqlite3.connect(self.path)
        self.assertEqual(self.db.execute("SELECT id,duration_seconds FROM observations").fetchall(), [("draft", None)])

    def test_minimal_publication_and_original_offset(self):
        self.db.execute("INSERT INTO observations(id,status,title,observed_at_utc_ms,utc_offset_minutes,category_code,created_at,updated_at) VALUES ('p','published','Luna',1795388400000,-240,'astronomy',1,1)")
        self.assertEqual(self.db.execute("SELECT utc_offset_minutes,duration_seconds,description,latitude FROM observations").fetchone(), (-240, None, None, None))

    def test_invalid_fields_are_rejected(self):
        for column, value in [("status", "bad"), ("duration_seconds", -1), ("category_code", "bad"), ("elevation_degrees", 91), ("latitude", 18), ("utc_offset_minutes", -240), ("revision", 0), ("accuracy_m", 10)]:
            with self.subTest(column=column), self.assertRaises(sqlite3.IntegrityError):
                self.db.execute(f"INSERT INTO observations(id,status,title,created_at,updated_at,{column}) VALUES ('bad','draft','',1,1,?)" if column != "status" else "INSERT INTO observations(id,title,created_at,updated_at,status) VALUES ('bad','',1,1,?)", (value,))

    def test_publication_requires_title_date_category(self):
        for title, instant, offset, category in [(" ", 1, -240, "astronomy"), ("Luna", None, None, "astronomy"), ("Luna", 1, -240, None)]:
            with self.subTest(title=title, instant=instant, category=category), self.assertRaises(sqlite3.IntegrityError):
                self.db.execute("INSERT INTO observations(id,status,title,observed_at_utc_ms,utc_offset_minutes,category_code,created_at,updated_at) VALUES ('bad','published',?,?,?,?,1,1)", (title, instant, offset, category))

    def test_foreign_keys_and_file_ownership(self):
        self.db.execute("INSERT INTO media_files VALUES ('m','media/m.jpg','image/jpeg',10,NULL,NULL,1)")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("INSERT INTO observation_media VALUES ('missing','m','photo',0)")
        self.draft()
        self.db.execute("INSERT INTO observation_media VALUES ('draft','m','photo',0)")
        self.db.execute("DELETE FROM observations")
        self.assertEqual(self.db.execute("SELECT COUNT(*) FROM observation_media").fetchone()[0], 0)
        self.assertEqual(self.db.execute("SELECT COUNT(*) FROM media_files").fetchone()[0], 1)

    def test_singletons_and_student_id_text(self):
        self.db.execute("INSERT INTO observer_profile VALUES (1,'Ana','Díaz','00123','Mirar',NULL)")
        self.assertEqual(self.db.execute("SELECT student_id FROM observer_profile").fetchone()[0], "00123")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("INSERT INTO app_settings(id) VALUES (2)")
        self.db.execute("INSERT INTO app_settings(id) VALUES (1)")
        self.assertEqual(self.db.execute("SELECT theme FROM app_settings").fetchone()[0], "night")

    def test_failed_transaction_does_not_leave_partial_rows(self):
        with self.assertRaises(sqlite3.IntegrityError):
            with self.db:
                self.draft()
                self.draft()
        self.assertEqual(self.db.execute("SELECT COUNT(*) FROM observations").fetchone()[0], 0)


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0]], verbosity=2)
