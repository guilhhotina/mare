from contextlib import closing
from pathlib import Path
import importlib.util
import sqlite3
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('storage_migration', ROOT / 'tools/storage_migration.py')
MIGRATION = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MIGRATION)


class StorageMigrationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / 'app.db'
        self.real = (ROOT / 'tests/fixtures/mare3-first-completion.txt').read_bytes()
        self.legacy = (ROOT / 'tests/fixtures/mare2-v01.txt').read_bytes().strip()
        with closing(sqlite3.connect(self.path)) as db, db:
            db.execute('CREATE TABLE persistent (id INTEGER PRIMARY KEY, key TEXT UNIQUE, value TEXT)')
            db.executemany('INSERT INTO persistent (key,value) VALUES (?,CAST(? AS TEXT))', [
                ('mare.island.1', self.real),
                ('mare.island.1.backup', self.legacy),
                ('mare.options', b'sound,motion,2,1,2'),
                ('unrelated', b'x' * 5000),
            ])

    def contents(self):
        with closing(sqlite3.connect(self.path)) as db:
            return dict(db.execute('SELECT key,CAST(value AS BLOB) FROM persistent'))

    def restore(self, data, key):
        header, bank, count, length, digest = data[key].decode('ascii').split(',')
        self.assertEqual(header, 'MARECHUNK1')
        count, length, digest = int(count), int(length), int(digest)
        self.assertIn(bank, ('0', '1'))
        self.assertLessEqual(count, 34)
        chunks = [data[f'{key}.chunk.{bank}.{index}'] for index in range(1, count + 1)]
        self.assertTrue(all(len(chunk) == 3000 for chunk in chunks[:-1]))
        value = b''.join(chunks)
        self.assertEqual(len(value), length)
        result = 2166136261
        for byte in value:
            result = ((result ^ byte) * 16777619) & 0xffffffff
        self.assertEqual(result, digest)
        return value

    def test_actual_save_and_legacy_backup_remain_byte_exact(self):
        before = self.contents()
        self.assertEqual(MIGRATION.migrate_storage(self.path), 2)
        after = self.contents()
        self.assertEqual(self.restore(after, 'mare.island.1'), self.real)
        self.assertEqual(self.restore(after, 'mare.island.1.backup'), self.legacy)
        self.assertEqual(after['mare.options'], before['mare.options'])
        self.assertEqual(after['unrelated'], before['unrelated'])
        self.assertEqual(MIGRATION.migrate_storage(self.path), 0)
        self.assertEqual(self.contents(), after)

    def test_maximum_payload_and_chunk_split_preserve_bytes(self):
        value = b'0' * 2999 + '\u00e9'.encode() + b'7' * 96999
        self.assertEqual(len(value), 100000)
        with closing(sqlite3.connect(self.path)) as db, db:
            db.execute('UPDATE persistent SET value=CAST(? AS TEXT) WHERE key=?', (value, 'mare.island.1'))
        MIGRATION.migrate_storage(self.path)
        self.assertEqual(self.restore(self.contents(), 'mare.island.1'), value)

    def test_failure_after_first_slot_rolls_back_every_value(self):
        before = self.contents()
        with closing(sqlite3.connect(self.path)) as db, db:
            db.execute("CREATE TRIGGER fail_backup BEFORE INSERT ON persistent WHEN NEW.key LIKE 'mare.island.1.backup.chunk.%' BEGIN SELECT RAISE(ABORT, 'interrupted'); END")
        with self.assertRaises(sqlite3.IntegrityError):
            MIGRATION.migrate_storage(self.path)
        self.assertEqual(self.contents(), before)

    def test_oversized_later_slot_cannot_partially_migrate_database(self):
        with closing(sqlite3.connect(self.path)) as db, db:
            db.execute('INSERT INTO persistent (key,value) VALUES (?,?)', ('mare.island.2', 'x' * 100001))
        before = self.contents()
        with self.assertRaises(ValueError):
            MIGRATION.migrate_storage(self.path)
        self.assertEqual(self.contents(), before)

    def test_missing_database_is_not_created(self):
        missing = self.path.parent / 'missing.db'
        self.assertEqual(MIGRATION.migrate_storage(missing), 0)
        self.assertFalse(missing.exists())


if __name__ == '__main__':
    unittest.main()
