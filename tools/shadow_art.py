import math


def _pack_columns(points):
    words, previous = [], -1
    for point in sorted(points, key=lambda point: (point & 0xfffff, point >> 20)):
        if words and point == previous + (1 << 20) and words[-1] >> 28 < 15:
            words[-1] += 1 << 28
        else:
            words.append(point)
        previous = point
    return words


def collect(art, elevated):
    res = 8
    width, height = art.nw * res, art.mw * res
    heights, points = [0] * (width * height), set()
    def add(px, py, depth):
        z = (16 * depth - (py - art.oy)) / 2
        total, difference = depth - z / 16, (px - art.ox) / 32
        u, v = (total + difference) / 2, (total - difference) / 2
        qx, qy, qz = round(u * 64) + 64, round(v * 64) + 64, min(255, math.floor(z + .5))
        if (qz > 0 or elevated and qz == 0) and 0 <= qx < 1024 and 0 <= qy < 1024:
            projected_x = round(art.ox + (qx - qy) * .5)
            projected_y = round(art.oy + (qx + qy - 128) * .25 - qz)
            if not (0 <= projected_x < art.im.width and 0 <= projected_y < art.im.height and art.im.getpixel((projected_x, projected_y))[3]):
                return
            points.add(qx | (qy << 10) | (qz << 20))
        x, y = math.floor(u * res), math.floor(v * res)
        if 0 <= x < width and 0 <= y < height:
            heights[y * width + x] = max(heights[y * width + x], min(180, qz))

    for py in range(art.im.height):
        for px in range(art.im.width):
            if art.im.getpixel((px, py))[3]:
                add(px, py, art.depth[py * art.im.width + px])
    return [width, height, heights], _pack_columns(points)
