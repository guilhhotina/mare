import math
from primitives import Art


DIRECTIONS = ((1, 0), (.7071067811865476, .7071067811865476), (0, 1), (-.7071067811865476, .7071067811865476), (-1, 0), (-.7071067811865476, -.7071067811865476), (0, -1), (.7071067811865476, -.7071067811865476))
RING = tuple((math.cos(i * math.pi / 4), math.sin(i * math.pi / 4)) for i in range(8))


class MovingArt(Art):
    def __init__(self, facing, water=False):
        super().__init__(2, 2, 48)
        self.dx, self.dy = DIRECTIONS[facing]
        self.ox, self.oy = 76, 60
        self.water = water

    def rotate(self, forward, side):
        return forward * self.dx - side * self.dy, forward * self.dy + side * self.dx

    def poly(self, points, color):
        if self.water:
            clipped = []
            previous = points[-1]
            for current in points:
                if (previous[2] >= 0) != (current[2] >= 0):
                    ratio = previous[2] / (previous[2] - current[2])
                    clipped.append((previous[0] + (current[0] - previous[0]) * ratio, previous[1] + (current[1] - previous[1]) * ratio, 0))
                if current[2] >= 0:
                    clipped.append(current)
                previous = current
            points = clipped
        if len(points) >= 3:
            super().poly(points, color)

    def body(self, sections, colors):
        rings = [[(forward, width * cosine, center + height * sine) for cosine, sine in RING] for forward, width, center, height in sections]
        for first, second in zip(rings, rings[1:]):
            for i in range(8):
                j = (i + 1) % 8
                color = colors[0] if 1 <= i <= 2 else colors[1] if i < 4 else colors[2]
                self.poly([first[i], second[i], second[j]], color)
                self.poly([first[i], second[j], first[j]], color)
        self.poly(rings[0], colors[2])
        self.poly(rings[-1], colors[1])

    def ripple(self, forward, width, frame):
        shift = (0, .015, 0, -.015)[frame % 4]
        self.line([(forward + .035, -width, .04), (forward + shift, -width * .7, .04), (forward - .025, 0, .04), (forward + shift, width * .7, .04), (forward + .035, width, .04)], 'mint')
