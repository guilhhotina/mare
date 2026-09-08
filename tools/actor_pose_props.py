_DIRECTIONS = ((1, 1), (-1, 1), (-1, -1), (1, -1))
_DRAWERS = {}


def _drawer(function):
    _DRAWERS[function.__name__[1:]] = function
    return function


def _at(origin, facing, forward=0, lateral=0, height=0):
    dx, dy = _DIRECTIONS[facing]
    return (round(origin[0] + dx * forward - dy * lateral),
            round(origin[1] + (dy * forward + dx * lateral) / 2 - height))


def _line(draw, points, color, width=1):
    draw.line(tuple(points), fill=color, width=width)


def _disc(draw, point, color, rx=1, ry=None, outline=None):
    x, y = point
    ry = rx if ry is None else ry
    draw.ellipse((x - rx, y - ry, x + rx, y + ry), fill=color, outline=outline)


def _grip(draw, point, palette):
    draw.point(point, fill=palette['skin'])


def _box(draw, origin, facing, width, depth, height, palette, colors=('woodL', 'wood', 'woodD')):
    footprint = ((-depth / 2, -width / 2), (depth / 2, -width / 2),
                 (depth / 2, width / 2), (-depth / 2, width / 2))
    bottom = tuple(_at(origin, facing, f, l) for f, l in footprint)
    top = tuple(_at(origin, facing, f, l, height) for f, l in footprint)
    edges = sorted(range(4), key=lambda i: bottom[i][1] + bottom[(i + 1) % 4][1])
    for index in edges:
        next_index = (index + 1) % 4
        shade = colors[1] if bottom[index][0] < bottom[next_index][0] else colors[2]
        draw.polygon((bottom[index], bottom[next_index], top[next_index], top[index]), fill=palette[shade])
    draw.polygon(top, fill=palette[colors[0]])


def _sheet(draw, origin, facing, palette, width=5, height=5, fill='cream', edge='woodD'):
    corners = tuple(_at(origin, facing, 0, l, z) for l, z in
                    ((-width / 2, 0), (width / 2, 0), (width / 2, height), (-width / 2, height)))
    draw.polygon(corners, fill=palette[fill], outline=palette[edge])
    return corners


def _paper(draw, origin, facing, palette, width=5, height=5):
    _sheet(draw, origin, facing, palette, width, height)
    for row in (2, 4):
        if row < height:
            _line(draw, (_at(origin, facing, 0, -1, row), _at(origin, facing, 0, 1, row)), palette['stone'])


def _book(draw, origin, page, facing, palette, width=6):
    left = _at(origin, facing, 0, -width / 2)
    right = _at(origin, facing, 0, width / 2)
    upper_left = _at(left, facing, 2, 0, 2)
    upper_right = _at(right, facing, 2, 0, 2)
    spine_top = _at(origin, facing, 2, 0, 1)
    draw.polygon((left, upper_left, spine_top, origin), fill=palette['cream'], outline=palette['woodD'])
    draw.polygon((origin, spine_top, upper_right, right), fill=palette['light'], outline=palette['woodD'])
    _line(draw, (origin, spine_top), palette['sand'])
    _line(draw, (_at(left, facing, 1, 1, 1), _at(origin, facing, 1, -1)), palette['stone'])
    _line(draw, (spine_top, page, right), palette['cream'])


def _mug(draw, origin, facing, palette, fill='cream'):
    x, y = origin
    dx, _ = _DIRECTIONS[facing]
    draw.rectangle((x - 1, y - 3, x + 1, y), fill=palette[fill])
    _line(draw, ((x - 1, y), (x + 1, y)), palette['shade'])
    draw.point((x, y - 3), fill=palette['woodD'])
    hx = x - 2 * dx
    _line(draw, ((x - dx, y - 2), (hx, y - 2), (hx, y - 1), (x - dx, y - 1)), palette[fill])


def _flower(draw, stem, head, palette, color='coral'):
    _line(draw, (stem, head), palette['grass'])
    x, y = head
    draw.point((x - 1, y + 1), fill=palette['grass2'])
    _disc(draw, head, palette[color], 1)
    draw.point(head, fill=palette['light'])


def _bag(draw, origin, facing, palette, fill='sand', handle=True):
    _box(draw, origin, facing, 4, 2, 5, palette, (fill, fill, 'wood'))
    if handle:
        _line(draw, (_at(origin, facing, 0, -1, 5), _at(origin, facing, 0, -1, 7),
                     _at(origin, facing, 0, 1, 7), _at(origin, facing, 0, 1, 5)), palette['woodD'])


def _bottle(draw, origin, palette, color='blue'):
    x, y = origin
    draw.rectangle((x - 1, y - 4, x + 1, y), fill=palette[color])
    _line(draw, ((x, y - 6), (x, y - 4)), palette[color])
    draw.point((x, y - 6), fill=palette['cream'])
    draw.point((x - 1, y - 3), fill=palette['light'])


def _bucket(draw, origin, palette, fill='stone', content='cream'):
    x, y = origin
    draw.polygon(((x - 3, y - 4), (x + 3, y - 4), (x + 2, y), (x - 2, y)), fill=palette[fill])
    draw.ellipse((x - 3, y - 5, x + 3, y - 2), fill=palette[content], outline=palette['woodD'])
    _line(draw, ((x - 3, y - 3), (x - 2, y - 6), (x + 2, y - 6), (x + 3, y - 3)), palette['woodD'])


def draw_props(draw, pose, facing, palette, layer):
    if layer not in ('back', 'front'):
        raise ValueError(f'Unsupported actor prop layer: {layer}')
    name = pose['prop']
    if name is None:
        return
    selected_layer = 'back' if name == 'hopscotch' or facing in (2, 3) else 'front'
    if layer == selected_layer:
        _DRAWERS[name](draw, pose['prop_points'], facing, palette)


@_drawer
def _survey(draw, points, facing, c):
    base, scope_start, scope_tip, mount, flag = points
    for lateral in (-2, 2):
        _line(draw, (_at(base, facing, -1, lateral), mount), c['woodD'])
    _line(draw, (_at(base, facing, 2), mount), c['woodD'])
    _line(draw, (mount, _at(mount, facing, 0, 0, 2)), c['stone'], 2)
    _line(draw, (scope_start, scope_tip), c['teal'], 2)
    _disc(draw, scope_tip, c['glass'])
    draw.point(mount, fill=c['light'])
    _line(draw, (flag, _at(flag, facing, 0, 0, 5)), c['wood'])
    draw.polygon((_at(flag, facing, 0, 0, 5), _at(flag, facing, 2, 0, 4),
                  _at(flag, facing, 0, 0, 3)), fill=c['coral'])


@_drawer
def _mark(draw, points, facing, c):
    hand, tip, start, end = points
    _line(draw, (start, end), c['cream'])
    for point in (start, end):
        _line(draw, (_at(point, facing, -1), _at(point, facing, 1)), c['cream'])
    _line(draw, (hand, tip), c['coral'])
    draw.point(tip, fill=c['light'])
    _grip(draw, hand, c)


@_drawer
def _carry_timber(draw, points, facing, c):
    origin, = points
    _box(draw, origin, facing, 10, 2, 2, c)
    _line(draw, (_at(origin, facing, 0, -4, 2), _at(origin, facing, 0, 4, 2)), c['wood'])
    draw.point(_at(origin, facing, 0, -2, 2), fill=c['woodD'])


@_drawer
def _stack_bricks(draw, points, facing, c):
    brick, supply, target = points
    _box(draw, supply, facing, 4, 3, 2, c, ('coral', 'red', 'woodD'))
    _box(draw, _at(supply, facing, 0, 0, 2), facing, 3, 2, 2, c, ('coral', 'red', 'woodD'))
    _box(draw, target, facing, 4, 2, 1, c, ('cream', 'stone', 'shade'))
    _box(draw, brick, facing, 3, 2, 2, c, ('coral', 'red', 'woodD'))
    _line(draw, (_at(brick, facing, 0, -1, 2), _at(brick, facing, 0, 1, 2)), c['red'])


@_drawer
def _mix_mortar(draw, points, facing, c):
    bucket, hand, tip = points
    _bucket(draw, bucket, c)
    _line(draw, (hand, tip), c['woodD'])
    _disc(draw, tip, c['shade'], 1, 0)
    _grip(draw, hand, c)


@_drawer
def _lay_bricks(draw, points, facing, c):
    hand, tip, brick, bed = points
    _box(draw, bed, facing, 5, 2, 1, c, ('cream', 'stone', 'shade'))
    _box(draw, brick, facing, 3, 2, 2, c, ('coral', 'red', 'woodD'))
    _line(draw, (hand, tip), c['woodD'])
    draw.polygon((tip, _at(tip, facing, -2, -1), _at(tip, facing, -2, 1)), fill=c['stone'])
    draw.point(tip, fill=c['light'])
    _grip(draw, hand, c)


@_drawer
def _hammer(draw, points, facing, c):
    hand, tip, contact = points
    _line(draw, (contact, _at(contact, facing, 0, 0, -2)), c['ink'])
    _line(draw, (_at(contact, facing, 0, -1), _at(contact, facing, 0, 1)), c['stone'])
    _line(draw, (hand, tip), c['woodD'])
    _line(draw, (_at(tip, facing, 0, -2), _at(tip, facing, 0, 2)), c['ink'], 2)
    draw.point(_at(tip, facing, 0, -1), fill=c['stone'])
    if tip == contact:
        draw.point(_at(contact, facing, 1, -2, 1), fill=c['light'])
        draw.point(_at(contact, facing, -1, 2, 1), fill=c['cream'])
    _grip(draw, hand, c)


@_drawer
def _saw(draw, points, facing, c):
    hand, tip, contact = points
    blade_top = _at(tip, facing, 0, 0, 2)
    draw.polygon((hand, _at(hand, facing, 0, 0, 2), blade_top, tip), fill=c['stone'])
    _line(draw, (hand, tip), c['ink'])
    for numerator in (1, 3, 5):
        point = (round(hand[0] + (tip[0] - hand[0]) * numerator / 6),
                 round(hand[1] + (tip[1] - hand[1]) * numerator / 6) + 1)
        draw.point(point, fill=c['stone'])
    _disc(draw, hand, c['woodD'], 1)
    draw.point(contact, fill=c['woodL'])
    _grip(draw, hand, c)


@_drawer
def _paint(draw, points, facing, c):
    hand, roller, bucket, contact = points
    _bucket(draw, bucket, c, 'cream', 'coral')
    elbow = _at(roller, facing, 0, 2, -1)
    _line(draw, (hand, elbow, _at(roller, facing, 0, 2)), c['woodD'])
    _line(draw, (_at(roller, facing, 0, -2), _at(roller, facing, 0, 2)), c['coral'], 2)
    draw.point(_at(roller, facing, 0, -1, 1), fill=c['cream'])
    if abs(roller[1] - contact[1]) < 2:
        draw.point(_at(contact, facing, 0, 1), fill=c['coral'])
    _grip(draw, hand, c)


@_drawer
def _inspect_work(draw, points, facing, c):
    board, hand, tip = points
    _paper(draw, board, facing, c, 4, 5)
    _line(draw, (_at(board, facing, 0, -1, 5), _at(board, facing, 0, 1, 5)), c['ink'])
    _line(draw, (hand, tip), c['woodD'])
    draw.point(tip, fill=c['ink'])
    _grip(draw, hand, c)
