from actor_pose_props import _at, _bag, _book, _box, _disc, _grip, _line, _paper, _sheet


def _read_notice(p, f):
    p.bend(0, 0, (0, 1, 1, 1, 1, 1, 0, 0)[f], (0, 0, 1, 1, 2, 1, 0, 0)[f])
    notice = p.q(5, 0, 6)
    support = p.far(5, 3, 7)
    finger = p.near((3, 4, 5, 5, 5, 5, 4, 3)[f], (2, 2, 1, 0, 1, 2, 2, 2)[f],
                    (5, 8, 11, 10, 9, 8, 7, 5)[f])
    p.prop('read_notice', notice, support, finger)


def _draw_read_notice(draw, points, facing, c):
    notice, support, finger = points
    _sheet(draw, notice, facing, c, 6, 6)
    _line(draw, (_at(notice, facing, 0, -2, 5), _at(notice, facing, 0, 2, 5)), c['red'])
    for row, end in ((4, 2), (3, 1), (2, 2), (1, 0)):
        _line(draw, (_at(notice, facing, 0, -2, row), _at(notice, facing, 0, end, row)), c['ink'])
    _line(draw, (_at(notice, facing, 0, 2, 6), _at(notice, facing, 0, 2, 5),
                 _at(notice, facing, 0, 3, 5)), c['sand'])
    _grip(draw, support, c)
    _grip(draw, finger, c)


def _check_meter(p, f):
    p.bend((0, 0, 0, 1, 1, 1, 0, 0)[f], 0,
           (0, 0, 1, 1, 1, 1, 1, 0)[f], (1, 1, 0, 0, 0, 1, 1, 1)[f])
    meter = p.q(4, -p.side * 2, 5)
    support = p.far(4, 3, 7)
    hand = p.near((3, 4, 5, 6, 6, 5, 4, 3)[f], 2, (6, 6, 7, 8, 8, 7, 6, 6)[f])
    tip = p.q((5, 6, 7, 8, 8, 7, 6, 5)[f], p.side * 2, (6, 6, 7, 8, 7, 7, 6, 6)[f])
    cable = p.q(3, 0, 2)
    needle = p.q(4, -p.side * 2 + (0, 0, -1, 0, 1, 1, 0, 0)[f], 8)
    p.prop('check_meter', meter, support, hand, tip, cable, needle)


def _draw_check_meter(draw, points, facing, c):
    meter, support, hand, tip, cable, needle = points
    _line(draw, (meter, cable, _at(hand, facing, -1), hand), c['ink'])
    _box(draw, meter, facing, 3, 1, 5, c, ('stone', 'asphalt', 'ink'))
    _sheet(draw, _at(meter, facing, 0, 0, 2), facing, c, 2, 2, 'mint', 'deep')
    _line(draw, (_at(meter, facing, 0, 0, 2), needle), c['ink'])
    _disc(draw, _at(meter, facing, 0, 0, 1), c['coral'], 0)
    _line(draw, (hand, tip), c['ink'], 2)
    _line(draw, (_at(tip, facing, -1), tip), c['stone'])
    _grip(draw, support, c)
    _grip(draw, hand, c)


def _sort_recycling(p, f):
    p.bend((0, 0, 0, 1, 1, 1, 0, 0)[f], 0,
           (0, 1, 1, 2, 2, 1, 0, 0)[f], (1, 0, 0, 0, 0, 0, 1, 1)[f])
    supply = p.q(1, -p.side * 3, 0)
    support = p.far(1, 3, 7)
    hand = p.near((2, 3, 3, 5, 6, 5, 2, 1)[f], (2, 2, 1, 0, 0, 1, -2, -3)[f],
                  (5, 7, 9, 13, 13, 11, 7, 6)[f])
    can = p.q((2, 3, 3, 5, 7, 7, 7, 7)[f], p.side * (2, 2, 1, 0, 0, 0, 0, 0)[f],
              (4, 6, 8, 12, 12, 10, 7, 7)[f])
    mouth = p.q(7, 0, 11)
    p.prop('sort_recycling', supply, support, hand, can, mouth)


def _draw_sort_recycling(draw, points, facing, c):
    supply, support, hand, can, mouth = points
    _bag(draw, supply, facing, c, 'sand')
    spare = _at(supply, facing, 0, 0, 5)
    _line(draw, ((spare[0] - 1, spare[1]), (spare[0] - 1, spare[1] - 2)), c['blue'], 2)
    rim = tuple(_at(mouth, facing, forward, lateral) for forward, lateral in
                ((-3, -3), (3, -3), (3, 3), (-3, 3)))
    opening = tuple(_at(mouth, facing, forward, lateral) for forward, lateral in
                    ((-2, -2), (2, -2), (2, 2), (-2, 2)))
    draw.polygon(rim, fill=c['mint'], outline=c['deep'])
    draw.polygon(opening, fill=c['ink'])
    bottom = min(can[1], mouth[1]) if can[0] == mouth[0] else can[1]
    if can[1] - 3 <= bottom:
        draw.rectangle((can[0] - 1, can[1] - 3, can[0] + 1, bottom), fill=c['blue'])
        _line(draw, ((can[0] - 1, can[1] - 3), (can[0] + 1, can[1] - 3)), c['light'])
        draw.point((can[0], can[1] - 2), fill=c['deep'])
    front = sorted(range(4), key=lambda i: rim[i][1] + rim[(i + 1) % 4][1])[-2:]
    for index in front:
        a, b = rim[index], rim[(index + 1) % 4]
        draw.polygon((a, b, (b[0], b[1] + 2), (a[0], a[1] + 2)), fill=c['teal'])
        _line(draw, (a, b), c['mint'])
    _grip(draw, support, c)
    _grip(draw, hand, c)


def _water_sample(p, f):
    height = (3, 4, 5, 5, 5, 5, 4, 3)[f]
    p.bend(0, 0, (0, 0, 1, 1, 1, 1, 0, 0)[f], (0, 0, 0, 0, 1, 1, 0, 0)[f])
    vial = p.q(4, 0, height)
    support = p.far(4, 1, height + 2)
    stopper = p.near((4, 4, 4, 5, 4, 4, 4, 4)[f], (0, 0, 0, 2, 0, 0, 0, 0)[f],
                     (8, 10, 13, 13, 13, 11, 9, 8)[f])
    tip = _at(stopper, p.facing, 0, 0, -3)
    p.prop('water_sample', vial, support, stopper, tip)


def _draw_water_sample(draw, points, facing, c):
    vial, support, stopper, tip = points
    x, y = vial
    draw.rectangle((x - 1, y - 4, x + 1, y), fill=c['blue'], outline=c['glass'])
    _line(draw, ((x - 1, y - 2), (x + 1, y - 2)), c['water'])
    _line(draw, ((x - 1, y - 3), (x - 1, y - 1)), c['light'])
    _line(draw, ((x, y - 5), (x, y - 4)), c['glass'])
    _line(draw, ((x - 1, y - 5), (x + 1, y - 5)), c['cream'])
    _line(draw, (stopper, tip), c['cream'])
    draw.point(tip, fill=c['blue'])
    _line(draw, ((stopper[0] - 1, stopper[1] - 1), (stopper[0] + 1, stopper[1] - 1)), c['coral'])
    draw.point((stopper[0], stopper[1] - 2), fill=c['red'])
    _grip(draw, support, c)
    _grip(draw, stopper, c)


def _examine_chart(p, f):
    reach = (0, 2, 3, 2, 0, 0, 3, 0)[f]
    spread = (-3, -2, 0, 2, 3, 3, 0, -3)[f]
    p.bend(0, 0, (0, 0, 1, 1, 2, 1, 0, 0)[f], (1, 0, 0, 1, 1, 2, 1, 1)[f])
    left = p.q(5, -p.side * 1.5, 6)
    hinge = p.q(5, p.side * 1.5, 6)
    edge = p.q(5 + reach, p.side * (1.5 + spread), 6)
    support = p.far(5, 1.5, 6)
    hand = p.near(5 + reach, 1.5 + spread, 7)
    p.prop('examine_chart', left, hinge, edge, support, hand)


def _draw_examine_chart(draw, points, facing, c):
    left, hinge, edge, support, hand = points
    left_top, hinge_top, edge_top = ((point[0], point[1] - 5) for point in (left, hinge, edge))
    draw.polygon((left, hinge, hinge_top, left_top), fill=c['cream'], outline=c['woodD'])
    center = (round((left[0] + hinge[0]) / 2), round((left[1] + hinge[1]) / 2))
    _line(draw, ((left[0], left[1] - 3), (center[0], center[1] - 2),
                 (hinge[0], hinge[1] - 3)), c['blue'])
    _line(draw, ((left[0], left[1] - 1), (center[0], center[1] - 3),
                 (hinge[0], hinge[1] - 2)), c['coral'])
    draw.polygon((hinge, edge, edge_top, hinge_top), fill=c['light'], outline=c['woodD'])
    center = (round((hinge[0] + edge[0]) / 2), round((hinge[1] + edge[1]) / 2))
    _line(draw, ((hinge[0], hinge[1] - 3), (center[0], center[1] - 2),
                 (edge[0], edge[1] - 3)), c['blue'])
    _line(draw, ((hinge[0], hinge[1] - 2), (center[0], center[1] - 3)), c['coral'])
    draw.point((center[0], center[1] - 4), fill=c['deep'])
    _line(draw, (hinge, hinge_top), c['sand'])
    _grip(draw, support, c)
    _grip(draw, hand, c)


def _study_book(p, f):
    p.bend(0, 0, (0, 1, 1, 1, 1, 1, 1, 0)[f], (1, 1, 2, 2, 2, 2, 1, 1)[f])
    book = p.q(5, 0, 6)
    support = p.far(5, 3, 6)
    forward = (3, 4, 5, 5, 5, 6, 4, 3)[f]
    lateral = (2, 2, 1, 1, 2, 2, 2, 2)[f]
    height = (5, 8, 9, 9, 9, 10, 8, 5)[f]
    hand = p.near(forward, lateral, height)
    tip = p.q(forward + 1, p.side * lateral, height - 2)
    p.prop('study_book', book, support, hand, tip)


def _draw_study_book(draw, points, facing, c):
    book, support, hand, tip = points
    side = (-1, 1, -1, 1)[facing]
    _book(draw, book, _at(book, facing, 0, 3), facing, c, 6)
    _line(draw, (_at(book, facing, 0, 0, -1), _at(book, facing, 0, 0, -3)), c['red'])
    _line(draw, (_at(book, facing, 1, side, 1), _at(book, facing, 1, side * 2, 1)), c['ink'])
    _line(draw, (_at(book, facing, 2, side, 1), _at(book, facing, 2, side * 2, 2)), c['stone'])
    _line(draw, (hand, tip), c['woodD'])
    draw.point(tip, fill=c['ink'])
    _grip(draw, support, c)
    _grip(draw, hand, c)


def _teach_board(p, f):
    p.bend(0, 0, (0, 0, 1, 1, 1, 0, 0, 0)[f], (0, 0, 1, 1, 1, 0, -1, 0)[f])
    slate = p.q(6, 0, 5)
    support = p.far(6, 3.5, 6)
    forward = (4, 5, 5, 5, 5, 4, 4, 4)[f]
    lateral = (2, 1, 1, 0, -1, 3, 4, 2)[f]
    height = (6, 8, 9, 9, 8, 8, 10, 6)[f]
    hand = p.near(forward, lateral, height)
    tip = p.q(forward + 1, p.side * lateral, height + 1)
    p.prop('teach_board', slate, support, hand, tip)


def _draw_teach_board(draw, points, facing, c):
    slate, support, hand, tip = points
    _sheet(draw, slate, facing, c, 7, 7, 'deep', 'woodL')
    _line(draw, (_at(slate, facing, 0, -2, 3), _at(slate, facing, 0, 0, 5),
                 _at(slate, facing, 0, 2, 3), _at(slate, facing, 0, -2, 3)), c['cream'])
    _line(draw, (_at(slate, facing, 0, -2, 2), _at(slate, facing, 0, 2, 2)), c['mint'])
    _line(draw, (_at(slate, facing, 0, -1, 6), _at(slate, facing, 0, 1, 6)), c['light'])
    _line(draw, (hand, tip), c['cream'])
    _grip(draw, support, c)
    _grip(draw, hand, c)


def _radio_call(p, f):
    p.bend(0, 0, (0, 0, 1, 1, 1, 1, 0, 0)[f], (0, 0, 0, 0, 1, 0, 0, 0)[f])
    forward = (1, 2, 2, 2, 2, 2, 2, 1)[f]
    lateral = (2, 2.5, 2.5, 2.5, 2.5, 2.5, 2.5, 2)[f]
    height = (4, 6, 8, 8, 8, 8, 6, 4)[f]
    hand = p.near(forward, lateral, height)
    radio = p.q(forward, p.side * lateral, height - 1)
    thumb = p.far((0, 1, 2, 1, 1, 1, 1, 0)[f], (2, 0, -1.5, 1, 2, 2, 1, 2)[f],
                  (4, 6, 7, 6, 5, 5, 5, 4)[f])
    p.prop('radio_call', radio, hand, thumb)


def _draw_radio_call(draw, points, facing, c):
    radio, hand, thumb = points
    side = (-1, 1, -1, 1)[facing]
    _box(draw, radio, facing, 3, 1, 4, c, ('asphalt', 'deep', 'ink'))
    _line(draw, (_at(radio, facing, 0, side, 4), _at(radio, facing, 0, side, 7)), c['ink'])
    _line(draw, (_at(radio, facing, 0, -1, 3), _at(radio, facing, 0, 1, 3)), c['stone'])
    _line(draw, (_at(radio, facing, 0, -1, 2), _at(radio, facing, 0, 1, 2)), c['asphalt'])
    draw.point(_at(radio, facing, 0, -side, 4), fill=c['coral'])
    _grip(draw, thumb, c)
    _grip(draw, hand, c)


def _polish_equipment(p, f):
    p.bend(0, 0, (0, 0, 1, 1, 1, 1, 0, 0)[f], (1, 1, 1, 2, 1, 2, 1, 1)[f])
    equipment = p.q(5, 0, 4)
    support = p.far(5, 2.5, 6)
    cloth = p.near((2, 3, 3.5, 3.5, 3.5, 3.5, 3, 2)[f], (3, 2, 2, 1, 0, 1, 2, 3)[f],
                   (4, 6, 8, 7, 8, 7, 6, 4)[f])
    p.prop('polish_equipment', equipment, support, cloth)


def _draw_polish_equipment(draw, points, facing, c):
    equipment, support, cloth = points
    _box(draw, equipment, facing, 5, 3, 5, c, ('cream', 'stone', 'asphalt'))
    _line(draw, (_at(equipment, facing, 0, -1, 5), _at(equipment, facing, 0, -1, 6),
                 _at(equipment, facing, 0, 1, 6), _at(equipment, facing, 0, 1, 5)), c['ink'])
    dial = _at(equipment, facing, -1.5, 0, 3)
    _disc(draw, dial, c['cream'], 2, 2, c['deep'])
    _line(draw, (dial, _at(dial, facing, 0, 1, 1)), c['red'])
    _line(draw, (_at(equipment, facing, -1.5, -2, 1), _at(equipment, facing, -1.5, 2, 1)), c['deep'])
    _sheet(draw, _at(cloth, facing, 0, 0, -2), facing, c, 3, 3, 'light', 'sand')
    _line(draw, (_at(cloth, facing, 0, -1), _at(cloth, facing, 0, 1, -1)), c['shade'])
    _grip(draw, support, c)
    _grip(draw, cloth, c)


def _file_papers(p, f):
    p.bend(0, 0, (0, 0, 1, 1, 1, 1, 0, 0)[f], (1, 0, 0, 1, 1, 2, 1, 1)[f])
    wallet = p.q(5, 0, 3)
    support = p.far(5, 3, 5)
    forward = (2, 3, 4, 5, 5, 5, 5, 5)[f]
    lateral = (4, 3, 2, 1, 0, 0, 0, 0)[f]
    height = (5, 7, 8, 8, 8, 6, 5, 5)[f]
    skew = (1, 1, 1, .5, 0, 0, 0, 0)[f]
    paper = p.q(forward, p.side * lateral, height)
    middle = p.q(forward, p.side * (lateral - skew), height - 1)
    back = p.q(forward, p.side * (lateral + skew), height - 2)
    hand = p.near((2, 3, 4, 5, 5, 5, 4, 2)[f], (4, 3, 2, 1, 0, 0, 1, 2)[f],
                  (6, 8, 9, 9, 9, 7, 6, 5)[f])
    p.prop('file_papers', wallet, support, hand, paper, middle, back)


def _draw_file_papers(draw, points, facing, c):
    wallet, support, hand, paper, middle, back = points
    _sheet(draw, wallet, facing, c, 6, 6, 'woodL', 'woodD')
    tab = _at(wallet, facing, 0, -1, 6)
    _sheet(draw, tab, facing, c, 2, 1, 'sand', 'woodD')
    inside = paper[0] == wallet[0]
    if not inside:
        _sheet(draw, wallet, facing, c, 6, 5, 'sand', 'woodD')
    _paper(draw, back, facing, c, 4, 5)
    _paper(draw, middle, facing, c, 4, 5)
    _paper(draw, paper, facing, c, 4, 5)
    if inside:
        _sheet(draw, wallet, facing, c, 6, 5, 'sand', 'woodD')
    _line(draw, (_at(wallet, facing, 0, -1, 3), _at(wallet, facing, 0, 1, 3)), c['cream'])
    _grip(draw, support, c)
    _grip(draw, hand, c)


AUTHORS = {
    'read_notice': _read_notice,
    'check_meter': _check_meter,
    'sort_recycling': _sort_recycling,
    'water_sample': _water_sample,
    'examine_chart': _examine_chart,
    'study_book': _study_book,
    'teach_board': _teach_board,
    'radio_call': _radio_call,
    'polish_equipment': _polish_equipment,
    'file_papers': _file_papers,
}

DRAWERS = {
    'read_notice': _draw_read_notice,
    'check_meter': _draw_check_meter,
    'sort_recycling': _draw_sort_recycling,
    'water_sample': _draw_water_sample,
    'examine_chart': _draw_examine_chart,
    'study_book': _draw_study_book,
    'teach_board': _draw_teach_board,
    'radio_call': _draw_radio_call,
    'polish_equipment': _draw_polish_equipment,
    'file_papers': _draw_file_papers,
}
