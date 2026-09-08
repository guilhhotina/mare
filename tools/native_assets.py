from pathlib import Path
import json
import math
import struct
import wave
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def lua(value):
    if isinstance(value, str):
        return '"' + ''.join(chr(b) if 32 <= b < 127 and b not in (34, 92) else '\\%03d' % b for b in value.encode()) + '"'
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, dict):
        return '{' + ','.join('[' + lua(k) + ']=' + lua(v) for k, v in value.items()) + '}'
    if isinstance(value, (list, tuple)):
        return '{' + ','.join(lua(v) for v in value) + '}'
    return str(value)


def encode_runs(image):
    pixels = image.convert('RGBA').load()
    out = bytearray()
    for y in range(image.height):
        x = 0
        while x < image.width:
            color = pixels[x, y]
            end = x + 1
            while end < image.width and pixels[end, y] == color:
                end += 1
            if color[3]:
                out.extend(struct.pack('>HHH4B', x, y, end - x, *color))
            x = end
    return bytes(out)


def build(destination):
    destination.mkdir(parents=True, exist_ok=True)
    atlas = Image.open(ROOT / 'assets/atlas.png').convert('RGBA')
    entries = json.loads((ROOT / 'assets/atlas.json').read_text())
    fonts = json.loads((ROOT / 'web/typefaces.json').read_text())
    glyph_atlas = Image.open(ROOT / 'web/typefaces.png').convert('RGBA')
    with (destination / 'pixels.bin').open('wb') as binary:
        stored = {}
        def store(source, rectangle):
            key = (id(source), rectangle)
            if key not in stored:
                image = source.crop(rectangle)
                offset = binary.tell()
                encoded = encode_runs(image)
                binary.write(encoded)
                stored[key] = {'w': image.width, 'h': image.height, 'offset': offset, 'length': len(encoded)}
            return stored[key].copy()

        for key, meta in entries.items():
            x, y, w, h = (meta[k] for k in ('x', 'y', 'w', 'h'))
            meta.update(store(atlas, (x, y, x + w, y + h)))
            if key.startswith('ui_') and w <= 32 and h <= 32:
                meta['skin'] = store(atlas, (x, y, x + 32, y + 32))
            del meta['x'], meta['y']
        for font in fonts.values():
            for char, metrics in font.items():
                x, y, w, h, advance, ox, oy = metrics
                glyph = store(glyph_atlas, (x, y, x + w, y + h))
                glyph.update(advance=advance, ox=ox, oy=oy)
                font[char] = glyph
    (destination / 'sprites.lua').write_text('return ' + lua(entries) + '\n')
    (destination / 'fonts.lua').write_text('return ' + lua(fonts) + '\n')
    (destination / 'shadow-shapes.bin').write_bytes((ROOT / 'assets/shadow-shapes.bin').read_bytes())
    (destination / 'depths.bin').write_bytes((ROOT / 'assets/depths.bin').read_bytes())
    for kind, (frequency, end_frequency, duration, gain) in enumerate(((520, 390, .045, .013), (620, 820, .12, .03), (180, 120, .12, .03))):
        rate = 22050
        phase = 0.0
        samples = bytearray()
        for i in range(round((duration + .01) * rate)):
            t = i / rate
            fraction = min(1, t / duration)
            phase += 2 * math.pi * frequency * (end_frequency / frequency) ** fraction / rate
            amplitude = gain * (.0001 / gain) ** fraction
            samples.extend(struct.pack('<h', round(math.sin(phase) * amplitude * 32767)))
        with wave.open(str(destination / ('sound-' + str(kind) + '.wav')), 'wb') as audio:
            audio.setnchannels(1)
            audio.setsampwidth(2)
            audio.setframerate(rate)
            audio.writeframes(samples)
    print('Native assets:', len(entries), 'sprites,', (destination / 'pixels.bin').stat().st_size, 'bytes of runs')
