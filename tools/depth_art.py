import struct
from PIL import Image, ImageDraw
from primitives import Art


class DepthAtlas:
    def __init__(self):
        self.data = bytearray()
        self.terrain = {}

    def tile(self, mask):
        if mask not in self.terrain:
            art = Art(1, 1)
            art.im = Image.new('RGBA', (65, 65))
            art.d = ImageDraw.Draw(art.im)
            art.ox, art.oy = 32, 17
            art.depth = [-1e9] * (65 * 65)
            heights = [16 if mask & (1 << i) else 0 for i in range(4)]
            points = [(0, 0, heights[0]), (1, 0, heights[1]), (1, 1, heights[2]), (0, 1, heights[3])]
            art.poly([points[0], points[1], points[2]], 'grass')
            art.poly([points[0], points[2], points[3]], 'grass')
            self.terrain[mask] = art.depth
        return self.terrain[mask].copy()

    def add(self, name, image, values):
        x0, y0, x1, y1 = image.getbbox()
        pixels = image.load()
        offset = len(self.data)
        for y in range(y0, y1):
            for x in range(x0, x1):
                if pixels[x, y][3]:
                    depth = values[y * image.width + x]
                    assert -128 < depth < 128, (name, x, y, depth)
                    encoded = round(depth * 256)
                else:
                    encoded = -32768
                self.data.extend(struct.pack('<h', encoded))
        return [offset, len(self.data) - offset]
