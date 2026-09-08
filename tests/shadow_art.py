from pathlib import Path
import importlib.util
import unittest

ROOT = Path(__file__).resolve().parents[1]


def load_tool(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'tools' / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


Art = load_tool('primitives').Art
collect = load_tool('shadow_art').collect


def caster_points(art):
    _, words = collect(art, False)
    points = set()
    for word in words:
        low = (word >> 20) & 255
        for z in range(low, low + (word >> 28) + 1):
            points.add((word & 0xfffff) | (z << 20))
    return points


def caster_projection(art, point):
    qx, qy, z = point & 1023, (point >> 10) & 1023, point >> 20
    return round(art.ox + (qx - qy) * .5), round(art.oy + (qx + qy - 128) * .25 - z)


class ShadowArtTests(unittest.TestCase):
    def foliage(self):
        art = Art(head=60)
        art.foliage(.77, .4, 25)
        return art

    def test_opaque_foliage_keeps_contiguous_caster_columns(self):
        points = caster_points(self.foliage())
        columns = {}
        for point in points:
            columns.setdefault(point & 0xfffff, set()).add(point >> 20)
        for heights in columns.values():
            self.assertEqual(heights, set(range(min(heights), max(heights) + 1)))

    def test_transparent_pixel_leaves_a_real_caster_gap(self):
        art = self.foliage()
        solid = caster_points(art)
        x, y = art.p(.77, .4, 25)
        self.assertEqual(art.im.getpixel((x, y - 4))[3], 255)
        art.im.putpixel((x, y - 4), (0, 0, 0, 0))
        cut = caster_points(art)
        removed = set(solid) - set(cut)
        self.assertEqual({caster_projection(art, point) for point in removed}, {(x, y - 4)})
        self.assertEqual(cut, {point for point in solid if caster_projection(art, point) != (x, y - 4)})

    def test_tall_caster_retains_every_height_across_span_boundaries(self):
        art = Art(head=300)
        for z in range(1, 256):
            art.dot(.5, .5, z, 'ink')
        self.assertEqual({point >> 20 for point in caster_points(art)}, set(range(1, 256)))


if __name__ == '__main__':
    unittest.main()
