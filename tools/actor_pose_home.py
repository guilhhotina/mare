from actor_pose_props import _at, _line, _disc, _grip, _book, _box


def _unlock_door(p, f):
    forward = (0, 1, 3, 3, 1, 0)[f]
    lateral = (2, 1, 0, 0, 1, 2)[f]
    height = (4, 6, 7, 7, 6, 4)[f]
    p.bend((0, 0, 1, 1, 0, 0)[f], 0, (0, 1, 1, 1, 1, 0)[f], 0)
    p.feet((0, 0, 1, 1, 0, 0)[f])
    hand = p.near(forward, lateral, height)
    p.far(0, 2, (4, 4, 5, 5, 4, 4)[f])
    tip = p.q(forward + 2, p.side * lateral, height)
    tooth = p.q(forward + 2, p.side * (lateral + (1 if f == 3 else 0)), height + (0 if f == 3 else 1))
    p.prop('home_key', hand, tip, tooth)


def _knock_door(p, f):
    p.bend((0, 1, 1, 1, 1, 1, 0, 0)[f], 0, (0, 1, 1, 1, 1, 1, 1, 1)[f], 0)
    p.feet((0, 0, 1, 1, 1, 0, 0, 0)[f])
    p.near((0, 2, 5, 3, 5, 3, 1, 0)[f], (2, 1, 0, 1, 0, 1, 2, 2)[f], (4, 7, 7, 8, 7, 7, 5, 4)[f])
    p.far(0, 2, 4)


def _greet_neighbor(p, f):
    p.bend(0, 0, (0, 0, 0, 0, 1, 0, 0, 0)[f], (0, 0, -1, 0, 0, 0, 0, 0)[f])
    p.near((0, 0, 1, 1, 1, 1, 0, 0)[f], (2, 3, 2, 3, 2, 3, 3, 2)[f], (4, 7, 10, 10, 10, 10, 7, 4)[f])
    p.far(0, 2, (4, 5, 5, 4, 4, 4, 4, 4)[f])


def _draw_key(draw, points, facing, c):
    hand, tip, tooth = points
    _line(draw, (hand, tip, tooth), c['sand'])
    _disc(draw, hand, c['woodD'], 1, outline=c['cream'])
    draw.point(tip, fill=c['light'])
    _grip(draw, hand, c)


def _read_book(p, f):
    page_lateral = (3, 3, 2, 0, -2, -3, -3, -3)[f]
    page_lift = (0, 0, 2, 3, 2, 0, 0, 0)[f]
    p.seat()
    p.bend(0, 0, 1, (1, 2, 2, 1, 1, 2, 1, 1)[f])
    support = p.far(2, 3, 5)
    hand = p.near(2, (3, 3, 2, 0, -2, -3, 0, 3)[f], (5, 5, 7, 8, 7, 5, 6, 5)[f])
    origin = p.q(2, 0, 5)
    page = p.q(2, p.side * page_lateral, 5 + page_lift)
    page_top = p.q(4, p.side * page_lateral, 7 + page_lift)
    p.prop('home_book', origin, page, page_top, hand, support)


def _draw_book(draw, points, facing, c):
    origin, page, page_top, hand, support = points
    left = _at(origin, facing, 0, -3)
    right = _at(origin, facing, 0, 3)
    _line(draw, (_at(left, facing, 0, 0, -1), _at(origin, facing, 0, 0, -1),
                 _at(right, facing, 0, 0, -1)), c['teal'])
    _book(draw, origin, right, facing, c)
    if page not in (left, right):
        spine_top = _at(origin, facing, 2, 0, 1)
        draw.polygon((origin, spine_top, page_top, page), fill=c['light'], outline=c['sand'])
        _line(draw, (page, page_top), c['cream'])
    _grip(draw, support, c)
    _grip(draw, hand, c)


def _tilt(origin, facing, cosine, sine, forward, lateral, height):
    return _at(origin, facing, cosine * forward - sine * height, lateral,
               sine * forward + cosine * height)


def _drink_mug(p, f):
    cosine, sine = ((1, 0), (1, 0), (0.94, 0.34), (0.8, 0.6),
                    (0.8, 0.6), (0.94, 0.34), (1, 0), (1, 0))[f]
    p.bend(0, 0, 0, (1, 0, 0, -1, -1, 0, 0, 1)[f])
    p.far(0, 2, (4, 4, 5, 5, 5, 5, 4, 4)[f])
    lip = p.q((1, 2, 2, 1, 1, 2, 2, 1)[f], p.side * (1, 1, 0, 0, 0, 0, 1, 1)[f],
              (6, 7, 8, 8, 8, 8, 7, 6)[f])
    if f in (3, 4):
        hx, hy = p.data['head_offset']
        lip = (12 + p.dx + hx, 10 + hy)
    hand = _tilt(lip, p.facing, cosine, sine, 1, p.side * 2, -1)
    p.data['near_hand'] = hand
    coordinates = ((0, -p.side, 0), (2, -p.side, 0), (2, p.side, 0), (0, p.side, 0),
                   (2, -p.side, -2), (2, p.side, -2), (0, p.side, -2),
                   (1, p.side * 2, 0), (1, p.side * 2, -2))
    p.prop('home_mug', hand, *(_tilt(lip, p.facing, cosine, sine, *point) for point in coordinates))


def _draw_mug(draw, points, facing, c):
    hand, rim_inner_far, rim_outer_far, rim_outer_near, rim_inner_near, base_outer_far, base_outer_near, base_inner_near, handle_top, handle_bottom = points
    draw.polygon((rim_outer_far, rim_outer_near, base_outer_near, base_outer_far), fill=c['shade'])
    draw.polygon((rim_inner_near, rim_outer_near, base_outer_near, base_inner_near), fill=c['cream'])
    _line(draw, (base_inner_near, base_outer_near, base_outer_far), c['stone'])
    draw.polygon((rim_inner_far, rim_outer_far, rim_outer_near, rim_inner_near), fill=c['woodD'], outline=c['light'])
    handle_root_top = ((rim_inner_near[0] + rim_outer_near[0]) // 2,
                       (rim_inner_near[1] + rim_outer_near[1]) // 2)
    handle_root_bottom = ((base_inner_near[0] + base_outer_near[0]) // 2,
                          (base_inner_near[1] + base_outer_near[1]) // 2)
    _line(draw, (handle_root_top, handle_top, handle_bottom, handle_root_bottom), c['cream'])
    _grip(draw, hand, c)


def _water_planter(p, f):
    cosine, sine = ((1, 0), (1, 0), (0.99, -0.12), (0.97, -0.25),
                    (0.94, -0.34), (0.97, -0.25), (1, 0), (1, 0))[f]
    p.bend((0, 0, 1, 1, 1, 1, 0, 0)[f], 0, (0, 0, 1, 1, 1, 1, 0, 0)[f],
           (1, 1, 0, 0, 0, 0, 1, 1)[f])
    p.feet((0, 0, 1, 1, 1, 1, 0, 0)[f])
    hand = p.near((1, 1, 2, 2, 2, 2, 1, 1)[f], (1, 1, 0, 0, 0, 0, 1, 1)[f],
                  (5, 6, 8, 9, 9, 9, 7, 5)[f])
    support = _tilt(hand, p.facing, cosine, sine, -1, -p.side, -3)
    p.data['far_hand'] = support
    coordinates = ((-1.5, -1, -4), (1.5, -1, -4), (1.5, 1, -4), (-1.5, 1, -4),
                   (-1.5, -1, -1), (1.5, -1, -1), (1.5, 1, -1), (-1.5, 1, -1),
                   (-1, 0, -1), (-1, 0, 0), (1, 0, 0), (1, 0, -1),
                   (1.5, 0, -3), (3, 0, -1), (5, 0, 1))
    shape = tuple(_tilt(hand, p.facing, cosine, sine, *point) for point in coordinates)
    water_end = p.q(7, 0, 7) if f in (3, 4, 5) else shape[-1]
    p.prop('home_watering_can', hand, support, *shape, water_end)


def _draw_watering_can(draw, points, facing, c):
    hand, support = points[:2]
    bottom, top = points[2:6], points[6:10]
    handle = points[10:14]
    spout = points[14:17]
    water_end = points[17]
    _line(draw, handle, c['deep'])
    edges = sorted(range(4), key=lambda index: bottom[index][1] + bottom[(index + 1) % 4][1])
    for index in edges:
        next_index = (index + 1) % 4
        color = 'teal' if bottom[index][0] < bottom[next_index][0] else 'deep'
        draw.polygon((bottom[index], bottom[next_index], top[next_index], top[index]), fill=c[color])
    draw.polygon(top, fill=c['mint'], outline=c['teal'])
    _line(draw, spout, c['deep'], 2)
    _line(draw, spout, c['teal'])
    _line(draw, (_at(spout[-1], facing, 0, -1), _at(spout[-1], facing, 0, 1)), c['stone'])
    if spout[-1] != water_end:
        _line(draw, (_at(spout[-1], facing, 0, 0, -1), water_end), c['blue'])
        draw.point(water_end, fill=c['water'])
    _grip(draw, support, c)
    _grip(draw, hand, c)


def _sweep_steps(p, f):
    sweep = (-2, -2, -1, 1, 2, 2, 0, -2)[f]
    lift = (0, 0, 0, 0, 0, 1, 1, 0)[f]
    p.bend((0, 0, 1, 1, 1, 1, 0, 0)[f], (0, 1, 1, 1, 1, 0, 0, 0)[f], 1, 1)
    p.feet((0, 0, 1, 1, 1, 0, 0, 0)[f])
    top = p.q(1, p.side * sweep / 4, 9 + lift)
    binding = p.q(5, p.side * sweep, 3 + lift)
    support = (round((top[0] * 3 + binding[0]) / 4), round((top[1] * 3 + binding[1]) / 4))
    hand = (round((top[0] * 2 + binding[0] * 3) / 5), round((top[1] * 2 + binding[1] * 3) / 5))
    p.data['far_hand'] = support
    p.data['near_hand'] = hand
    collar_left = p.q(5, p.side * (sweep - 0.5), 3 + lift)
    collar_right = p.q(5, p.side * (sweep + 0.5), 3 + lift)
    tip_left = p.q(5, p.side * (sweep - 2), 1 + lift)
    tip_right = p.q(5, p.side * (sweep + 2), 1 + lift)
    middle = p.q(5, p.side * sweep, 1 + lift)
    p.prop('home_broom', top, support, hand, binding, collar_left, collar_right, tip_left, tip_right, middle)


def _draw_broom(draw, points, facing, c):
    top, support, hand, binding, collar_left, collar_right, tip_left, tip_right, middle = points
    draw.polygon((collar_left, collar_right, tip_right, tip_left), fill=c['woodL'], outline=c['wood'])
    _line(draw, (collar_left, tip_left), c['sand'])
    _line(draw, (binding, middle), c['sand'])
    _line(draw, (collar_right, tip_right), c['woodD'])
    _line(draw, (top, support, hand, binding), c['woodD'])
    _line(draw, (top, support), c['woodL'])
    _line(draw, (collar_left, collar_right), c['teal'])
    _grip(draw, support, c)
    _grip(draw, hand, c)


def _carry_groceries(p, f):
    near_forward = (2, 2, 1, 1, 2, 2, 2, 2)[f]
    far_forward = (0, 0, 1, 1, 0, 0, 0, 0)[f]
    near_height = (4.5, 4.5, 4.5, 5, 4.5, 4.5, 4.5, 4.5)[f]
    far_height = (4.5, 4.5, 5, 4.5, 4.5, 4.5, 4.5, 4.5)[f]
    lower = (1, 2, 1, 1, 2, 1, 1, 1)[f]
    p.bend(-1, lower, (-1, -1, 0, 0, -1, -1, -1, -1)[f], lower)
    p.feet((0, 0, 1, 1, 0, -1, 0, 0)[f], (0, 0, 1, 0, 0, 0, 0, 0)[f],
           (0, 0, 0, 0, 1, 0, 0, 0)[f])
    near_hand = p.near(near_forward, 2, near_height)
    far_hand = p.far(far_forward, 3, far_height)
    near_bag = p.q(near_forward, p.side * 2, near_height - 4)
    far_bag = p.q(far_forward, -p.side * 3, far_height - 4)
    p.prop('home_groceries', near_bag, near_hand, far_bag, far_hand)


def _draw_groceries(draw, points, facing, c):
    near_bag, near_hand, far_bag, far_hand = points
    bags = ((near_bag, near_hand, False), (far_bag, far_hand, True))
    for origin, hand, bread in sorted(bags, key=lambda bag: bag[0][1]):
        if bread:
            _line(draw, (_at(origin, facing, 0, 0, 2), _at(origin, facing, -0.5, 0, 5)), c['woodL'], 2)
            _line(draw, (_at(origin, facing, -0.5, -0.5, 4), _at(origin, facing, -0.5, 0.5, 4)), c['cream'])
        else:
            _disc(draw, _at(origin, facing, 0, 0, 3.5), c['coral'], 1)
            _line(draw, (_at(origin, facing, 0, -0.5, 3), _at(origin, facing, 0, -1, 5)), c['grass'])
            _line(draw, (_at(origin, facing, 0, -0.5, 3), _at(origin, facing, 1, -0.5, 4)), c['grass2'])
        _box(draw, origin, facing, 3, 2, 3, c, ('woodD', 'sand', 'wood'))
        _line(draw, (_at(origin, facing, 0, -1, 3), hand, _at(origin, facing, 0, 1, 3)), c['woodD'])
        _line(draw, (_at(origin, facing, 0, -1, 1), _at(origin, facing, 0, 1, 1)), c['woodL'])
        _grip(draw, hand, c)


AUTHORS = {
    'unlock_door': _unlock_door,
    'knock_door': _knock_door,
    'greet_neighbor': _greet_neighbor,
    'read_book': _read_book,
    'drink_mug': _drink_mug,
    'water_planter': _water_planter,
    'sweep_steps': _sweep_steps,
    'carry_groceries': _carry_groceries,
}

DRAWERS = {
    'home_key': _draw_key,
    'home_book': _draw_book,
    'home_mug': _draw_mug,
    'home_watering_can': _draw_watering_can,
    'home_broom': _draw_broom,
    'home_groceries': _draw_groceries,
}
