from pathlib import Path
import sqlite3

CHUNK_SIZE = 3000
MAX_LENGTH = 100000
SAVE_KEYS = tuple(f'mare.island.{slot}{suffix}' for slot in range(1, 4) for suffix in ('', '.backup'))


def checksum(value):
    result = 2166136261
    for byte in value:
        result = ((result ^ byte) * 16777619) & 0xffffffff
    return result


def migrate_storage(path):
    path = Path(path)
    if not path.is_file():
        return 0
    connection = sqlite3.connect(path.resolve().as_uri() + '?mode=rw', uri=True)
    try:
        connection.execute('BEGIN IMMEDIATE')
        if not connection.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='persistent'").fetchone():
            connection.rollback()
            return 0
        changed = 0
        for key in SAVE_KEYS:
            row = connection.execute('SELECT CAST(value AS BLOB) FROM persistent WHERE key=?', (key,)).fetchone()
            if not row or row[0] is None or len(row[0]) <= CHUNK_SIZE:
                continue
            value = row[0]
            if len(value) > MAX_LENGTH:
                raise ValueError(f'{key}: save exceeds {MAX_LENGTH} bytes; database unchanged')
            count = (len(value) + CHUNK_SIZE - 1) // CHUNK_SIZE
            for part in range(count):
                chunk_key = f'{key}.chunk.0.{part + 1}'
                chunk = value[part * CHUNK_SIZE:(part + 1) * CHUNK_SIZE]
                connection.execute('INSERT INTO persistent (key, value) VALUES (?, CAST(? AS TEXT)) ON CONFLICT(key) DO UPDATE SET value=excluded.value', (chunk_key, chunk))
            pointer = f'MARECHUNK1,0,{count},{len(value)},{checksum(value)}'
            connection.execute('UPDATE persistent SET value=? WHERE key=?', (pointer, key))
            changed += 1
        connection.commit()
        return changed
    except BaseException:
        connection.rollback()
        raise
    finally:
        connection.close()
