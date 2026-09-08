import json
import re
from PIL import ImageFont

LOCALES = ('pt', 'en', 'de')
FORMAT = re.compile(r'%(?:[-+0]*\d*(?:\.\d+)?)?[cdiouxXeEfgGqs%]')


def build(root, rows, lua):
    data = {code: {'messages': {}, 'catalog': []} for code in LOCALES}
    glyphs = json.loads((root / 'web/typefaces.json').read_text())['body13']
    for source in ('ui', 'domain'):
        entries = json.loads((root / 'assets/locales' / (source + '.json')).read_text())
        for key, values in entries.items():
            assert set(values) == set(LOCALES), (source, key, 'incomplete locales')
            formats = [spec for spec in FORMAT.findall(key) if spec != '%%']
            for code, value in values.items():
                assert isinstance(value, str) and value, (source, key, code, 'empty translation')
                assert all(ch in glyphs or ch == '\n' for ch in value), (source, key, code, 'missing glyph')
                if formats:
                    assert [spec for spec in FORMAT.findall(value) if spec != '%%'] == formats, (source, key, code, 'format mismatch')
                messages = data[code]['messages']
                assert key not in messages or messages[key] == value, (source, key, code, 'conflicting translation')
                messages[key] = value
    font = ImageFont.truetype(str(root / 'web/vendor/PixelifySans.ttf'), 13)
    names = json.loads((root / 'assets/locales/catalog.json').read_text())
    assert set(names) == set(LOCALES), 'incomplete catalog locales'
    for code in LOCALES:
        assert len(names[code]) == len(rows), (code, 'incomplete catalog')
        for row, name in zip(rows, names[code]):
            assert name and all(ch in glyphs for ch in name), (code, name, 'missing catalog glyph')
            lines = ['']
            for word in name.split():
                candidate = (lines[-1] + ' ' + word).strip()
                if sum(max(2, round(font.getlength(ch))) * 2 for ch in candidate) > 184:
                    lines.append(word)
                else:
                    lines[-1] = candidate
            assert len(lines) <= 2 and all(lines), (code, name, 'catalog needs more than two lines')
            assert all(sum(max(2, round(font.getlength(ch))) * 2 for ch in line) <= 184 for line in lines), (code, name, 'catalog line too wide')
            translated = list(row)
            translated[0] = name
            translated[9:11] = lines + [''] * (2 - len(lines))
            data[code]['catalog'].append(translated)
    source = 'return ' + lua(data) + '\n'
    (root / 'src/locales.lua').write_text(source)
    web = {code: {} for code in LOCALES}
    for key, values in json.loads((root / 'assets/locales/web.json').read_text()).items():
        assert set(values) == set(LOCALES), (key, 'incomplete web locales')
        for code, value in values.items():
            assert isinstance(value, str) and value, (key, code, 'empty web translation')
            web[code][key] = value
    (root / 'web/locales.js').write_text('window.MareWebLocales=' + json.dumps(web, ensure_ascii=False, separators=(',', ':')) + ';\n')
    return source
