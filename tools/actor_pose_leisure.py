from actor_pose_props import _at, _line, _disc, _grip, _box, _flower


AUTHORS = {}
DRAWERS = {}


def _author(function):
    AUTHORS[function.__name__[1:]] = function
    return function


def _drawer(function):
    DRAWERS[function.__name__[1:]] = function
    return function


@_author
def _sit_bench(p, f):
    p.seat((0, 0, 1, 1, 0, -1, -1, 0)[f])
    p.bend(0, 0, (0, 0, 0, 1, 1, 0, -1, 0)[f], (0, 0, 1, 0, 0, 0, 0, 0)[f])
    p.near(2, 2, (4, 4, 5, 5, 4, 4, 4, 4)[f])
    p.far(1, 2, 5)


@_author
def _eat_snack(p, f):
    p.seat((0, 0, 0, 0, 0, 1, 0, 0)[f])
    p.bend(0, 0, (0, 0, 1, 1, 1, 1, 0, 0)[f], (0, 0, 0, 0, 1, 0, 0, 0)[f])
    hand = p.near((2, 2, 1, 1, 1, 1, 2, 2)[f], 1, (5, 6, 7, 7, 7, 6, 5, 5)[f])
    wrapper = p.far(2, 1, 4)
    p.prop('eat_snack', hand, wrapper)


@_drawer
def _eat_snack(draw, points, facing, c):
    hand, wrapper = points
    x, y = wrapper
    draw.polygon(((x - 2, y - 1), (x - 1, y - 3), (x + 2, y - 2), (x + 1, y + 1)), fill=c['cream'])
    _line(draw, ((x - 1, y - 2), (x, y), (x + 1, y - 1)), c['shade'])
    x, y = hand
    draw.rectangle((x - 1, y - 2, x + 1, y), fill=c['woodL'])
    _line(draw, ((x - 1, y - 1), (x + 1, y - 1)), c['cream'])
    draw.point((x + (1 if facing in (0, 3) else -1), y), fill=c['grass'])
    _grip(draw, wrapper, c)
    _grip(draw, hand, c)


@_author
def _smell_flower(p, f):
    p.bend((0, 1, 2, 3, 3, 2, 1, 0)[f], (0, 0, 1, 2, 2, 1, 0, 0)[f],
           (0, 1, 3, 5, 5, 3, 1, 0)[f], (0, 0, 1, 2, 2, 1, 0, 0)[f])
    hand = p.near((2, 4, 6, 7, 7, 6, 4, 2)[f], (2, 1, 0, 0, 0, 0, 1, 2)[f], (4, 5, 5, 5, 5, 5, 5, 4)[f])
    p.far((0, 0, 1, 2, 2, 1, 0, 0)[f], 2, 3)
    p.prop('smell_flower', p.q(7, 0, 3), p.q(7, 0, 7), hand)


@_drawer
def _smell_flower(draw, points, facing, c):
    stem, head, hand = points
    _flower(draw, stem, head, c)
    _line(draw, (_at(stem, facing, 0, 0, 1), _at(stem, facing, 0, 1, 2)), c['grass2'])
    _grip(draw, hand, c)


@_author
def _feed_birds(p, f):
    p.bend((0, 0, 0, 1, 1, 1, 0, 0)[f], (0, 0, 0, 0, 1, 1, 0, 0)[f],
           (0, 0, 1, 1, 2, 2, 1, 0)[f], (0, 0, 0, 1, 2, 2, 1, 0)[f])
    pouch = p.far(2, 1, 5)
    hand = p.near((2, 2, 4, 6, 5, 3, 2, 2)[f], (1, 1, 1, 0, 1, 1, 1, 1)[f], (5, 6, 6, 5, 4, 4, 5, 5)[f])
    head = p.q(9, 0, (3, 3, 3, 3, 2, 1, 1, 3)[f])
    beak = p.q(8, 0, (3, 3, 3, 3, 2, 0, 0, 3)[f])
    if f < 3:
        seeds = (_at(hand, p.facing, 0, 0, 1),)
    elif f < 5:
        seeds = (p.q((7, 8)[f - 3], 0, (4, 2)[f - 3]),)
    elif f < 7:
        seeds = (p.q(8),)
    else:
        seeds = ()
    p.prop('feed_birds', pouch, hand, p.q(10), head, beak, *seeds)


@_drawer
def _feed_birds(draw, points, facing, c):
    pouch, hand, ground, head, beak, *seeds = points
    body = _at(ground, facing, 0, 0, 2)
    for lateral in (-1, 1):
        foot = _at(ground, facing, 0, lateral)
        _line(draw, (foot, _at(foot, facing, 0, 0, 1)), c['woodD'])
    _line(draw, (body, _at(body, facing, 2, 0, 1)), c['asphalt'])
    _disc(draw, body, c['stone'], 2, 1)
    _line(draw, (_at(body, facing, 0, -1), _at(body, facing, 1)), c['asphalt'])
    _line(draw, (body, head), c['stone'])
    _disc(draw, head, c['teal'], 1)
    draw.point(_at(head, facing, 0, 0, 1), fill=c['ink'])
    draw.point(beak, fill=c['sand'])
    _box(draw, pouch, facing, 3, 1, 3, c, ('sand', 'cream', 'shade'))
    draw.point(_at(pouch, facing, 0, 0, 2), fill=c['wood'])
    for seed in seeds:
        draw.point(seed, fill=c['woodL'])
    _grip(draw, pouch, c)
    _grip(draw, hand, c)


@_author
def _take_photo(p, f):
    forward = (3, 3, 2, 2, 2, 2, 3, 3)[f]
    height = (5, 6, 8, 8, 8, 8, 6, 5)[f]
    p.feet(1)
    p.bend(0, 0, (0, 0, 1, 1, 1, 1, 0, 0)[f], 0)
    near = p.near(forward, 2, height + (0, 1, 2, 2, 1, 2, 1, 0)[f])
    far = p.far(forward, 2, height)
    p.prop('take_photo', p.q(forward, 0, height), p.q(forward + 2, 0, height + 1),
           p.q(forward, p.side * 2, height + 2 - (f == 4)), near, far)


@_drawer
def _take_photo(draw, points, facing, c):
    body, lens, shutter, near, far = points
    _box(draw, body, facing, 4, 2, 2, c, ('asphalt', 'ink', 'deep'))
    _line(draw, (_at(body, facing, 0, -1, 2), _at(body, facing, 0, 1, 2)), c['stone'])
    _line(draw, (_at(body, facing, 1, 0, 1), lens), c['ink'], 2)
    _disc(draw, lens, c['glass'], 1, outline=c['ink'])
    draw.point(lens, fill=c['blue'])
    draw.point(shutter, fill=c['coral'])
    _grip(draw, far, c)
    _grip(draw, near, c)


@_author
def _look_out(p, f):
    p.bend((0, 0, 1, 1, 1, 1, 0, 0)[f], 0, (0, 1, 1, 2, 1, 0, 0, 0)[f], 0)
    p.near((1, 1, 1, 2, 1, 0, 1, 1)[f], (2, 2, 1, 1, 1, 1, 2, 2)[f], (4, 7, 10, 10, 10, 10, 7, 4)[f])
    p.far(0, 2, 4)


@_author
def _stretch(p, f):
    forward = (0, 0, 0, -1, -1, -1, 0, 0)[f]
    lateral = (2, 3, 3, 1, 0, 1, 3, 2)[f]
    height = (4, 7, 10, 12, 13, 12, 8, 4)[f]
    p.feet(1)
    p.bend(forward, (0, 0, -1, -1, -1, -1, 0, 0)[f])
    p.near(forward, lateral, height)
    p.far(forward, lateral, height)


@_author
def _exercise(p, f):
    forward = (1, 2, 4, 5, 5, 4, 2, 1)[f]
    lateral = (2, 2, 1, 1, 1, 1, 2, 2)[f]
    height = (4, 5, 6, 6, 6, 6, 5, 4)[f]
    p.bend((0, 0, 1, 1, 1, 1, 0, 0)[f], (0, 1, 2, 3, 3, 2, 1, 0)[f],
           (0, 0, 1, 1, 1, 1, 0, 0)[f], (0, 1, 2, 3, 4, 2, 1, 0)[f])
    p.data['near_foot'] = p.q(0, p.side * 2)
    p.data['far_foot'] = p.q(0, -p.side * 2)
    p.near(forward, lateral, height)
    p.far(forward, lateral, height + 1)


@_author
def _play_ball(p, f):
    height = (6, 5, 7, 11, 13, 11, 7, 6)[f]
    hands = p.q(3, 0, (6, 5, 7, 8, 7, 8, 7, 6)[f])
    p.bend(0, (0, 1, -1, -1, 0, 0, 1, 0)[f], (0, 0, 0, 0, 1, 1, 0, 0)[f],
           (0, 1, -1, -1, -1, -1, 1, 0)[f])
    near = (hands[0] + p.dx * 2, hands[1] + 1)
    far = (hands[0] - p.dx * 2, hands[1] + 1)
    p.data['near_hand'] = near
    p.data['far_hand'] = far
    ball = p.q(3, 0, height)
    stripe = ((-1, -1), (0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0))[f]
    p.prop('play_ball', ball, (ball[0] + stripe[0], ball[1] + stripe[1]), near, far)


@_drawer
def _play_ball(draw, points, facing, c):
    ball, stripe, near, far = points
    x, y = ball
    _disc(draw, ball, c['cream'], 2, outline=c['deep'])
    _line(draw, ((2 * x - stripe[0], 2 * y - stripe[1]), ball, stripe), c['coral'])
    draw.point((x - 1, y - 1), fill=c['light'])
    _grip(draw, far, c)
    _grip(draw, near, c)


@_author
def _hopscotch(p, f):
    forward = (0, 0, 2, 3, 2, 0, 0, 0)[f]
    p.bend(forward, (0, 1, -2, 1, -3, 2, 1, 0)[f])
    near = ((0, 2, 0), (0, 2, 0), (2, 1, 2), (3, 0, 0),
            (2, 1, 3), (0, 2, 0), (0, 2, 0), (0, 2, 0))[f]
    far = ((0, 2, 0), (0, 2, 0), (2, 1, 2), (2, 1, 3),
           (2, 1, 3), (0, 2, 0), (0, 2, 0), (0, 2, 0))[f]
    p.data['near_foot'] = p.q(near[0], p.side * near[1], near[2])
    p.data['far_foot'] = p.q(far[0], -p.side * far[1], far[2])
    lateral = (2, 3, 4, 4, 4, 3, 2, 2)[f]
    height = (4, 5, 8, 6, 9, 5, 4, 4)[f]
    p.near(forward, lateral, height)
    p.far(forward, lateral, height + 1)
    p.prop('hopscotch', p.q(0))


@_drawer
def _hopscotch(draw, points, facing, c):
    origin, = points
    for forward, lateral in ((0, -2), (0, 2), (3, 0), (6, -2), (6, 2)):
        corners = tuple(_at(origin, facing, forward + df, lateral + dl)
                        for df, dl in ((-1.5, -1.5), (1.5, -1.5), (1.5, 1.5), (-1.5, 1.5)))
        _line(draw, (*corners, corners[0]), c['cream'])
    _line(draw, (_at(origin, facing, 2.5), _at(origin, facing, 3.5)), c['light'])


def _animal(draw, ground, head, muzzle, tail, facing, c):
    side = -1 if facing in (0, 2) else 1
    for forward, lateral in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        foot = _at(ground, facing, forward, lateral)
        _line(draw, (_at(foot, facing, 0, 0, 2), foot), c['woodD'])
    _line(draw, (_at(ground, facing, 1, 0, 2), tail), c['wood'])
    body = _at(ground, facing, 0, 0, 2)
    _disc(draw, body, c['sand'], 3, 1, c['wood'])
    _line(draw, (_at(ground, facing, -2, 0, 2), head), c['sand'], 2)
    _line(draw, (_at(head, facing, 0, -side * 2, 1), _at(head, facing, 0, -side * 2, -1)), c['woodD'])
    _disc(draw, head, c['cream'], 2, outline=c['wood'])
    _line(draw, (head, muzzle), c['sand'], 2)
    draw.point(muzzle, fill=c['ink'])
    _line(draw, (_at(head, facing, 0, side * 2, 1), _at(head, facing, 0, side * 2, -1)), c['woodL'])
    draw.point(_at(head, facing, 0, side, 1), fill=c['ink'])
    _line(draw, (_at(head, facing, 1, -1, -1), _at(head, facing, 1, 1, -1)), c['teal'])


@_author
def _pet_animal(p, f):
    p.bend((0, 1, 2, 2, 2, 2, 1, 0)[f], (0, 1, 2, 2, 2, 2, 1, 0)[f],
           (0, 1, 3, 3, 3, 3, 1, 0)[f], (0, 1, 2, 2, 2, 2, 1, 0)[f])
    hand = p.near((2, 4, 6, 7, 8, 7, 4, 2)[f], (2, 1, 0, 0, 0, 0, 1, 2)[f], (4, 5, 6, 6, 5, 6, 5, 4)[f])
    p.far((0, 1, 2, 2, 2, 2, 1, 0)[f], 2, (4, 3, 2, 2, 2, 2, 3, 4)[f])
    tail = p.q(12, p.side * (-1, 0, 1, 2, 1, 0, -1, -1)[f], (3, 4, 4, 3, 4, 4, 3, 3)[f])
    p.prop('pet_animal', p.q(10), p.q(7, 0, 4), p.q(6, 0, 4), tail, hand)


@_drawer
def _pet_animal(draw, points, facing, c):
    ground, head, muzzle, tail, hand = points
    _animal(draw, ground, head, muzzle, tail, facing, c)
    _grip(draw, hand, c)


@_author
def _feed_animal(p, f):
    p.bend((0, 0, 1, 2, 2, 2, 1, 0)[f], (0, 0, 1, 2, 2, 2, 1, 0)[f],
           (0, 1, 2, 3, 3, 3, 1, 0)[f], (0, 0, 1, 2, 2, 2, 1, 0)[f])
    supply = p.far(2, 2, 5)
    hand = p.near((2, 3, 5, 7, 7, 6, 4, 2)[f], (1, 1, 0, 0, 0, 0, 1, 1)[f], (5, 6, 6, 6, 6, 6, 5, 5)[f])
    head = p.q(8, 0, (4, 4, 5, 5, 5, 5, 4, 4)[f])
    muzzle = p.q(7, 0, (4, 4, 5, 6, 6, 5, 4, 4)[f])
    tail = p.q(12, p.side * (0, 1, -1, 1, -1, 1, 0, 0)[f], (3, 3, 4, 4, 3, 4, 3, 3)[f])
    treat = (hand,) if f < 4 else ()
    p.prop('feed_animal', p.q(10), head, muzzle, tail, supply, hand, *treat)


@_drawer
def _feed_animal(draw, points, facing, c):
    ground, head, muzzle, tail, supply, hand, *treat = points
    _animal(draw, ground, head, muzzle, tail, facing, c)
    _box(draw, supply, facing, 3, 1, 3, c, ('sand', 'coral', 'red'))
    _line(draw, (_at(supply, facing, 1, -1, 1), _at(supply, facing, 1, 1, 1)), c['cream'])
    _grip(draw, supply, c)
    _grip(draw, hand, c)
    for point in treat:
        _disc(draw, point, c['woodL'], 1, 0)
