from actor_pose_props import _at, _line, _disc, _grip, _box, _paper, _mug, _flower


def _browse_stall(p, f):
    p.bend((1, 1, 2, 2, 2, 1, 1, 1)[f], 0,
           (1, 2, 2, 2, 1, 1, 0, 1)[f], (1, 1, 0, 0, 1, 1, 1, 1)[f])
    p.far(5, 2, 12)
    p.near((2, 3, 4, 5, 5, 4, 3, 2)[f],
           (2, 2, 1, 0, -1, 0, 1, 2)[f], (6, 8, 10, 12, 12, 10, 8, 6)[f])


def _choose_produce(p, f):
    forward = (2, 3, 5, 5, 3, 3, 2, 2)[f]
    lateral = (2, 1, 0, 0, 1, 2, 2, 2)[f]
    height = (6, 9, 12, 13, 12, 11, 7, 5)[f]
    p.bend((1, 1, 2, 2, 1, 0, 0, 0)[f], 0,
           (1, 2, 2, 2, 1, 1, 0, 0)[f], (1, 0, 0, 0, 1, 1, 1, 0)[f])
    hand = p.near(forward, lateral, height)
    p.far((5, 5, 5, 5, 4, 3, 2, 1)[f], 2, (12, 12, 12, 12, 10, 8, 6, 4)[f])
    fruit = p.q(5, 0, 13) if f < 3 else p.q(forward, p.side * lateral, height + 1)
    p.prop('choose_produce', fruit, hand)


def _draw_choose_produce(draw, points, facing, c):
    fruit, hand = points
    _disc(draw, fruit, c['coral'], 1, outline=c['red'])
    draw.point(_at(fruit, facing, 0, 0, 1), fill=c['woodD'])
    draw.point(_at(fruit, facing, 1, 0, 2), fill=c['grass'])
    _grip(draw, hand, c)


def _pay_vendor(p, f):
    forward = (1, 2, 2, 3, 5, 5, 3, 1)[f]
    lateral = (2, -2, -2, 0, 0, 0, 1, 2)[f]
    height = (5, 6, 7, 10, 12, 12, 8, 5)[f]
    p.bend((0, 0, 0, 1, 2, 2, 1, 0)[f], 0,
           (0, 1, 1, 1, 2, 2, 1, 0)[f], (1, 2, 1, 0, 0, 1, 1, 0)[f])
    hand = p.near(forward, lateral, height)
    purse_hand = p.far(2, 2, 6)
    if f < 2:
        coin = p.q(2, -p.side * 2, 3)
    elif f < 5:
        coin = p.q(forward, p.side * lateral, height + 1)
    else:
        coin = p.q(5, 0, 13)
    p.prop('pay_vendor', p.q(2, -p.side * 2, 2), coin, hand, purse_hand)


def _draw_pay_vendor(draw, points, facing, c):
    purse, coin, hand, purse_hand = points
    _disc(draw, coin, c['sand'], 1, 0)
    draw.point(coin, fill=c['light'])
    _box(draw, purse, facing, 3, 1, 4, c, ('woodL', 'wood', 'woodD'))
    _line(draw, (_at(purse, facing, 0, -1, 4), _at(purse, facing, 0, 1, 4)), c['woodD'])
    draw.point(_at(purse, facing, 1, 0, 3), fill=c['sand'])
    _grip(draw, hand, c)
    _grip(draw, purse_hand, c)


def _serve_coffee(p, f):
    forward = (3, 2, 3, 5, 7, 7, 5, 3)[f]
    lateral = (2, 2, 1, 1, 0, 0, 1, 2)[f]
    height = (7, 8, 10, 10, 10, 10, 9, 7)[f]
    p.bend((0, 0, 0, 1, 2, 2, 1, 0)[f], 0,
           (0, 0, 0, 1, 1, 1, 0, 0)[f], (1, 0, 0, 0, 0, 0, 0, 1)[f])
    p.feet((0, 0, 0, 1, 1, 1, 1, 0)[f])
    hand = p.near(forward - 1, lateral - 1, height + 2)
    support = p.far(3, 3, 7)
    p.prop('serve_coffee', p.q(3, 0, 6), p.q(3, p.side * 2, 7),
           p.q(forward, p.side * lateral, height), hand, support)


def _draw_serve_coffee(draw, points, facing, c):
    tray, saucer, cup, hand, support = points
    _box(draw, tray, facing, 6, 3, 1, c, ('woodL', 'wood', 'woodD'))
    rim = tuple(_at(tray, facing, forward, lateral, 1) for forward, lateral in
                ((-1.5, -3), (1.5, -3), (1.5, 3), (-1.5, 3), (-1.5, -3)))
    _line(draw, rim, c['woodD'])
    _disc(draw, saucer, c['cream'], 2, 0)
    _mug(draw, cup, facing, c)
    _line(draw, (_at(cup, facing, 0, 0, 5), _at(cup, facing, 1, 0, 6)), c['cream'])
    _grip(draw, hand, c)
    _grip(draw, support, c)


def _bake_bread(p, f):
    center = (4, 4, 4, 4.5, 4.5, 4, 4, 4)[f]
    length = (1, 1, 1, 1.5, 1.5, 1, 1, 1)[f]
    width = (1.5, 1.5, 1.5, 2, 1, 1.5, 1.5, 1.5)[f]
    p.bend((0, 0, 1, 2, 1, 1, 0, 0)[f], (0, 0, 1, 1, 1, 0, 0, 0)[f],
           (1, 1, 2, 2, 2, 1, 1, 1)[f], (1, 1, 1, 2, 1, 1, 1, 1)[f])
    p.feet(1)
    hand = p.near((3, 3, 5, 6, 5, 3, 3, 3)[f],
                  (1, 1, 0, 0, 1, 1, 1, 1)[f], (8, 10, 8, 7, 7, 8, 9, 8)[f])
    support = p.far(4, 3, 5)
    p.prop('bake_bread', p.q(4, 0, 5),
           p.q(center - length, 0, 6), p.q(center, -p.side * width, 6),
           p.q(center + length, 0, 6), p.q(center, p.side * width, 6),
           p.q(center, 0, (8, 8, 8, 7, 8, 8, 8, 8)[f]), hand, support)


def _draw_bake_bread(draw, points, facing, c):
    board, back, far, front, near, crown, hand, support = points
    _box(draw, board, facing, 6, 4, 1, c)
    _line(draw, (_at(board, facing, -1, -2, 1), _at(board, facing, -1, 2, 1)), c['wood'])
    draw.polygon((back, far, front, near), fill=c['sand'])
    draw.polygon((back, crown, front, near), fill=c['cream'])
    _line(draw, (back, crown), c['light'])
    draw.point(_at(crown, facing, 1, 0), fill=c['sand'])
    _grip(draw, hand, c)
    _grip(draw, support, c)


def _cook_stir(p, f):
    tip_forward = (4, 4, 5, 4, 3, 4, 5, 4)[f]
    tip_lateral = (1, 1, 0, -1, 0, 1, 0, 1)[f]
    p.bend((0, 0, 1, 1, 1, 1, 0, 0)[f], 0, 1, (1, 0, 1, 1, 2, 1, 1, 1)[f])
    hand = p.near((2, 2, 3, 3, 2, 2, 3, 2)[f],
                  (2, 2, 2, 1, 1, 2, 2, 2)[f], (11, 12, 12, 11, 11, 12, 11, 11)[f])
    support = p.far(4, 4, 8)
    p.prop('cook_stir', p.q(4, 0, 6), p.q(4, -p.side * 2, 8), support, hand,
           p.q(tip_forward, p.side * tip_lateral, 10 if f == 1 else 9))


def _draw_cook_stir(draw, points, facing, c):
    pot, handle_root, support, hand, tip = points
    x, y = pot
    _line(draw, (handle_root, support), c['ink'], 2)
    draw.polygon(((x - 3, y - 3), (x + 3, y - 3), (x + 2, y), (x - 2, y)), fill=c['teal'])
    _line(draw, ((x - 2, y), (x + 2, y)), c['deep'])
    _disc(draw, (x, y - 3), c['coral'], 3, 1, c['woodD'])
    draw.point((x - 1, y - 3), fill=c['cream'])
    draw.point((x + 1, y - 3), fill=c['grass'])
    _line(draw, (hand, tip), c['woodD'])
    _disc(draw, tip, c['woodL'], 1, 0)
    _grip(draw, hand, c)
    _grip(draw, support, c)


def _arrange_flowers(p, f):
    forward = (5, 6, 7, 7, 7, 7, 6, 5)[f]
    lateral = (2, 2, 1, 0, -1, 1, 2, 2)[f]
    height = (8, 9, 10, 9, 8, 9, 8, 8)[f]
    p.bend((1, 1, 2, 2, 2, 2, 1, 1)[f], 0,
           (1, 1, 2, 2, 2, 1, 1, 1)[f], (1, 0, 0, 1, 1, 1, 1, 1)[f])
    support = p.far(7, 1, 7)
    hand = p.near(forward, lateral, height)
    p.prop('arrange_flowers', p.q(7, 0, 7), p.q(7, -p.side * 2, 11),
           p.q(8, p.side, 12), hand, p.q(forward + 1, p.side * lateral, height + 3), support)


def _draw_arrange_flowers(draw, points, facing, c):
    stems, left, right, hand, flower, support = points
    _flower(draw, support, left, c, 'light')
    _flower(draw, stems, right, c, 'coral')
    _line(draw, (stems, hand), c['grass'])
    _flower(draw, hand, flower, c, 'sand')
    _line(draw, (_at(stems, facing, 0, -1), _at(stems, facing, 0, 1)), c['grass2'])
    _grip(draw, hand, c)
    _grip(draw, support, c)


def _repair_bike(p, f):
    p.bend((1, 2, 2, 2, 2, 2, 2, 1)[f], (2, 3, 4, 4, 4, 4, 3, 2)[f],
           (2, 2, 3, 3, 3, 3, 2, 2)[f], (3, 4, 4, 4, 4, 4, 4, 3)[f])
    p.feet(1)
    support = p.far(7, 2, 7)
    hand = p.near((3, 5, 7, 7, 7, 7, 5, 3)[f],
                  (2, 2, 2, 3, 3, 2, 2, 2)[f], (5, 6, 6, 5, 4, 5, 6, 5)[f])
    tip = p.q((5, 6, 7, 7, 7, 7, 6, 5)[f],
              p.side * (1, 1, 0, 0, 0, 0, 1, 1)[f], 3)
    p.prop('repair_bike', p.q(7, -p.side * 4, 2), p.q(7, p.side * 4, 2),
           p.q(7, 0, 3), p.q(7, -p.side * 2, 5), support,
           p.q(7, p.side * 2, 5), p.q(7, p.side * 3, 7), hand, tip)


def _draw_repair_bike(draw, points, facing, c):
    rear, front, crank, seat_post, saddle, steering, bar, hand, tip = points
    for wheel in (rear, front):
        _disc(draw, wheel, None, 2, 2, c['ink'])
        _line(draw, ((wheel[0] - 1, wheel[1]), (wheel[0] + 1, wheel[1])), c['stone'])
        _line(draw, ((wheel[0], wheel[1] - 1), (wheel[0], wheel[1] + 1)), c['stone'])
        draw.point(wheel, fill=c['woodL'])
    frame = (rear, seat_post, steering, crank, seat_post, rear, crank)
    _line(draw, frame, c['deep'], 2)
    _line(draw, frame, c['teal'])
    _line(draw, (seat_post, saddle), c['stone'])
    _line(draw, ((saddle[0] - 1, saddle[1]), (saddle[0] + 1, saddle[1])), c['woodD'], 2)
    _line(draw, (front, steering, bar), c['stone'])
    _line(draw, ((bar[0] - 1, bar[1]), (bar[0] + 1, bar[1] - 1)), c['woodD'])
    _line(draw, (crank, _at(crank, facing, -1, 1, -1)), c['ink'])
    _line(draw, (hand, tip), c['stone'], 2)
    _disc(draw, tip, c['stone'], 1)
    draw.point(tip, fill=c['ink'])
    _grip(draw, hand, c)
    _grip(draw, saddle, c)


def _load_crate(p, f):
    forward = (5, 5, 5, 4, 4, 6, 8, 8)[f]
    height = (0, 0, 0, 2, 5, 4, 1, 1)[f]
    p.bend((0, 1, 2, 2, 0, 1, 2, 0)[f], (0, 2, 4, 2, 0, 1, 3, 0)[f],
           (1, 2, 2, 2, 0, 1, 2, 1)[f], (1, 3, 4, 2, 0, 1, 3, 1)[f])
    p.feet((0, 1, 1, 1, 1, 2, 2, 1)[f])
    if f < 2:
        grip_forward = (2, 4)[f]
        grip_lateral = (2, 3)[f]
        grip_height = (4, 3)[f]
    elif f == 7:
        grip_forward, grip_lateral, grip_height = 5, 2, 5
    else:
        grip_forward, grip_lateral, grip_height = forward, 3, height + 3
    near = p.near(grip_forward, grip_lateral, grip_height)
    far = p.far(grip_forward, grip_lateral, grip_height)
    p.prop('load_crate', p.q(forward, 0, height), p.q(8), near, far)


def _draw_load_crate(draw, points, facing, c):
    crate, pallet, near, far = points
    _box(draw, pallet, facing, 7, 3, 1, c)
    for lateral in (-2, 0, 2):
        _line(draw, (_at(pallet, facing, -1, lateral, 1),
                     _at(pallet, facing, 1, lateral, 1)), c['woodD'])
    _box(draw, crate, facing, 6, 3, 4, c)
    for lateral in (-1, 1):
        _line(draw, (_at(crate, facing, 1.5, lateral), _at(crate, facing, 1.5, lateral, 4)), c['woodD'])
        _line(draw, (_at(crate, facing, -1.5, lateral, 4), _at(crate, facing, 1.5, lateral, 4)), c['wood'])
    _line(draw, (_at(crate, facing, 1.5, -3, 2), _at(crate, facing, 1.5, 3, 2)), c['woodL'])
    for lateral in (-3, 3):
        _line(draw, (_at(crate, facing, -.5, lateral, 3), _at(crate, facing, .5, lateral, 3)), c['woodD'])
    _grip(draw, far, c)
    _grip(draw, near, c)


def _check_delivery(p, f):
    p.bend(0, 0, (0, 0, 0, 1, 1, 1, 0, 0)[f], (1, 2, 2, 1, 1, 2, 2, 1)[f])
    manifest = p.far(3, 2, (6, 7, 8, 8, 8, 7, 6, 6)[f])
    receipt = p.near((3, 3, 4, 3, 3, 4, 3, 3)[f],
                     (2, 3, 3, 1, 0, 2, 2, 2)[f], (6, 7, 8, 9, 8, 8, 7, 6)[f])
    p.prop('check_delivery', manifest, receipt)


def _draw_check_delivery(draw, points, facing, c):
    manifest, receipt = points
    _paper(draw, manifest, facing, c, 4, 6)
    _line(draw, (_at(manifest, facing, 0, -1, 6), _at(manifest, facing, 0, 1, 6)), c['stone'])
    _line(draw, (_at(manifest, facing, 0, -1, 1), _at(manifest, facing, 0, -1, 5)), c['shade'])
    _paper(draw, receipt, facing, c, 3, 4)
    _line(draw, (_at(receipt, facing, 0, -1, 3), _at(receipt, facing, 0, 1, 3)), c['coral'])
    _grip(draw, manifest, c)
    _grip(draw, receipt, c)


AUTHORS = {
    'browse_stall': _browse_stall,
    'choose_produce': _choose_produce,
    'pay_vendor': _pay_vendor,
    'serve_coffee': _serve_coffee,
    'bake_bread': _bake_bread,
    'cook_stir': _cook_stir,
    'arrange_flowers': _arrange_flowers,
    'repair_bike': _repair_bike,
    'load_crate': _load_crate,
    'check_delivery': _check_delivery,
}

DRAWERS = {
    'choose_produce': _draw_choose_produce,
    'pay_vendor': _draw_pay_vendor,
    'serve_coffee': _draw_serve_coffee,
    'bake_bread': _draw_bake_bread,
    'cook_stir': _draw_cook_stir,
    'arrange_flowers': _draw_arrange_flowers,
    'repair_bike': _draw_repair_bike,
    'load_crate': _draw_load_crate,
    'check_delivery': _draw_check_delivery,
}
