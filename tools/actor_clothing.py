OUTFITS = ('casual', 'worker', 'maid', 'bunny', 'dress', 'suit', 'coat', 'overalls')
DIRECTIONS = ((1, 1), (-1, 1), (-1, -1), (1, -1))


def _views(front, back):
    return front, tuple(row[::-1] for row in front), tuple(row[::-1] for row in back), back


_BODIES = {
    'casual': _views(('tTsL', 'tTTL', 'tTTL', 'ttTL'), ('ttTL', 'ttTL', 'ttTL', 'tttt')),
    'worker': _views(('tWsT', 'tWWT', 'tWtT', 'bbbb'), ('tWWT', 'tWtT', 'tWWT', 'bbbb')),
    'maid': _views(('tWsW', 'tWAt', 'tAWt', 'tAAW'), ('ttTL', 'tTTL', 'tTTL', 'tWWt')),
    'bunny': _views(('tWsW', 'tTTL', 'tTTL', 'ttTL'), ('ttTL', 'tTTL', 'tTTL', 'tttW')),
    'dress': _views(('tTsL', 'tTTL', 'tTTL', 'tTTL'), ('ttTL', 'tTTL', 'tTTL', 'tTTL')),
    'suit': _views(('tWsW', 'tWLL', 'tTeL', 'ttTL'), ('ttTL', 'tTTL', 'tTTL', 'ttTL')),
    'coat': _views(('tWsT', 'tWTL', 'tTeL', 'tTeL'), ('ttTL', 'tTTL', 'tTTL', 'ttTL')),
    'overalls': _views(('LsLT', 'tbbL', 'tBbL', 'tBbL'), ('LbLT', 'tbbL', 'tBbL', 'tbbL')),
}
_HEADS = {
    'casual': _views((' hHh ', 'hHKHh', 'hdsS ', '  se '), (' hHh ', 'hHKHh', 'hHHHh', '  hs ')),
    'worker': _views((' hh  ', 'hHKhh', ' dsS ', '  se '), (' hh  ', 'hHKhh', ' hhh ', '  hs ')),
    'maid': _views((' hh  ', 'hHKh ', 'hdsS ', ' hse '), (' hh  ', 'hHKh ', 'hHHh ', ' hhs ')),
    'bunny': _views((' hh  ', 'hHKh ', ' dsS ', '  se '), (' hh  ', 'hHKh ', ' hhh ', '  hs ')),
    'dress': _views((' hhh ', 'hHKhh', 'hdsS ', 'hhse '), (' hhh ', 'hHKhh', 'hHHhh', ' hhhs')),
    'suit': _views((' hhh ', 'hKKhh', ' dsS ', ' hse '), (' hhh ', 'hKKhh', ' hHh ', '  hs ')),
    'coat': _views((' hh  ', 'hHKh ', 'hdsS ', '  se '), (' hh  ', 'hHKh ', 'hHHh ', '  hs ')),
    'overalls': _views(('  h  ', 'hHKh ', ' hss ', '  se '), ('  h  ', 'hHKh ', ' hHh ', '  hs ')),
}
_LEGS = {
    'casual': ('b', 'B', 'e'),
    'worker': ('woodD', 'wood', 'e'),
    'maid': ('a', 'w', 'e'),
    'bunny': ('t', 'T', 'w'),
    'dress': ('d', 's', 'e'),
    'suit': ('t', 'T', 'e'),
    'coat': ('b', 'B', 'woodD'),
    'overalls': ('b', 'B', 'woodD'),
}
_SLEEVES = {'casual': 1, 'worker': 2, 'maid': 3, 'bunny': 3, 'dress': 1, 'suit': 3, 'coat': 3, 'overalls': 1}


def _stamp(draw, rows, x, y, palette):
    for j, row in enumerate(rows):
        for i, key in enumerate(row):
            if key != ' ':
                draw.point((x + i, y + j), fill=palette[key])


def shoulder(facing, body_offset, near):
    dx = DIRECTIONS[facing][0]
    x = (14 if dx > 0 else 9) if near else (9 if dx > 0 else 14)
    return x + body_offset[0], (12 if near else 11) + body_offset[1]


def draw_legs(draw, outfit, facing, pose, palette):
    dx = DIRECTIONS[facing][0]
    bx, by = pose['body_offset']
    far_color, near_color, shoe = _LEGS[outfit]
    for near, key in ((False, far_color), (True, near_color)):
        x = (12 if dx > 0 else 10) if near else (10 if dx > 0 else 12)
        hip = (x + bx, 14 + by)
        foot = pose['near_foot' if near else 'far_foot']
        knee = ((hip[0] * 2 + foot[0]) // 3, (hip[1] + foot[1]) // 2)
        draw.line((hip, knee, foot), fill=palette[key])
        draw.line((foot, (foot[0] + dx, foot[1])), fill=palette[shoe])
        if outfit in ('bunny', 'worker', 'overalls'):
            draw.point((foot[0], foot[1] - 1), fill=palette['w' if outfit == 'bunny' else key])


def arm_points(start, hand):
    dx, dy = hand[0] - start[0], hand[1] - start[1]
    ax, ay = abs(dx), abs(dy)
    steps = max(ax, ay)
    if steps == 0:
        yield start
        return
    sx, sy = (1 if dx >= 0 else -1), (1 if dy >= 0 else -1)
    half = steps // 2
    for step in range(steps + 1):
        yield start[0] + sx * ((ax * step + half) // steps), start[1] + sy * ((ay * step + half) // steps)


def draw_arm(draw, outfit, facing, pose, palette, near):
    start = shoulder(facing, pose['body_offset'], near)
    hand = pose['near_hand' if near else 'far_hand']
    dx, dy = hand[0] - start[0], hand[1] - start[1]
    steps = max(abs(dx), abs(dy))
    sleeve_end = steps * _SLEEVES[outfit] // 4
    skin = palette['skin' if near else 'skin_shadow']
    shirt = palette['shirt' if near else 'shirt_shadow']
    hand_color = palette['skin_light' if near else 'skin']
    cuff = outfit in ('maid', 'bunny', 'suit') and abs(dx) + abs(dy) > 2
    for step, point in enumerate(arm_points(start, hand)):
        if step == steps:
            color = hand_color
        elif step == sleeve_end and cuff:
            color = palette['w']
        else:
            color = shirt if step <= sleeve_end else skin
        draw.point(point, fill=color)


def draw_back_hair(draw, outfit, facing, pose, palette):
    hx, hy = pose['head_offset']
    right = facing in (0, 3)
    if outfit == 'coat':
        x = (10 if right else 14) + hx
        side = -1 if right else 1
        draw.line(((x, 9 + hy), (x + side, 10 + hy), (x + side, 12 + hy)), fill=palette['hair_shadow'])
        draw.point((x + side, 10 + hy), fill=palette['hair'])
        draw.point((x + side, 11 + hy), fill=palette['shirt_light'])
    elif outfit == 'maid':
        x = (9 if right else 14) + hx
        draw.rectangle((x, 8 + hy, x + 1, 9 + hy), fill=palette['hair_shadow'])
        draw.point((x, 8 + hy), fill=palette['hair_light'])
    elif outfit == 'dress':
        x = (10 if right else 14) + hx
        side = -1 if right else 1
        if facing < 2:
            draw.line(((x, 9 + hy), (x + side, 10 + hy), (x + side, 12 + hy)), fill=palette['hair_shadow'])
            draw.point((x + side, 11 + hy), fill=palette['hair'])
        else:
            draw.line(((x, 9 + hy), (x, 12 + hy)), fill=palette['hair_shadow'])
            draw.line(((24 + 2 * hx - x, 9 + hy), (24 + 2 * hx - x, 11 + hy)), fill=palette['hair'])
            draw.point((x, 10 + hy), fill=palette['hair_light'])


def draw_body(draw, outfit, facing, pose, palette):
    bx, by = pose['body_offset']
    hx, hy = pose['head_offset']
    draw.line(((12 + bx, 11 + by), (12 + hx, 10 + hy)), fill=palette['s'])
    _stamp(draw, _BODIES[outfit][facing], 10 + bx, 11 + by, palette)
    if outfit in ('dress', 'maid'):
        foot_dx = pose['near_foot'][0] + pose['far_foot'][0] - 22 - 2 * bx
        sway = 1 if foot_dx > 1 else -1 if foot_dx < -1 else 0
        left, right = 9 + bx + sway, 14 + bx + sway
        hem = min(16 + by, max(14 + by, max(pose['near_foot'][1], pose['far_foot'][1]) - 1))
        highlight = right - 1 if facing in (0, 3) else left + 1
        waist = (13 if facing in (0, 3) else 10) + bx
        draw.polygon(((10 + bx, 14 + by), (13 + bx, 14 + by), (right, hem), (left, hem)), fill=palette['shirt_shadow'])
        draw.polygon(((11 + bx, 14 + by), (12 + bx, 14 + by), (right - 1, hem), (left + 1, hem)), fill=palette['shirt'])
        draw.line(((waist, 14 + by), (highlight, hem)), fill=palette['shirt_light'])
        if outfit == 'maid':
            if facing < 2:
                apron_left = left + (2 if facing == 0 else 1)
                apron_right = right - (1 if facing == 0 else 2)
                draw.polygon(((11 + bx, 13 + by), (12 + bx, 13 + by), (apron_right, hem), (apron_left, hem)), fill=palette['w'])
                draw.point((highlight, hem - 1), fill=palette['W'])
            else:
                draw.line(((10 + bx, 14 + by), (13 + bx, 14 + by)), fill=palette['w'])
                draw.point(((11 if facing == 3 else 12) + bx, min(15 + by, hem)), fill=palette['W'])
            draw.line(((left + 1, hem), (right - 1, hem)), fill=palette['w'])
            draw.point((highlight, hem), fill=palette['W'])
        else:
            draw.line(((10 + bx, 14 + by), (13 + bx, 14 + by)), fill=palette['shirt_shadow'])
            if facing < 2:
                draw.point(((12 if facing == 0 else 11) + bx, 14 + by), fill=palette['lane'])
    elif outfit == 'coat':
        hem = min(16 + by, max(14 + by, max(pose['near_foot'][1], pose['far_foot'][1]) - 1))
        dark, light = ((10, 13) if facing in (0, 3) else (13, 10))
        draw.rectangle((10 + bx, 14 + by, 13 + bx, hem), fill=palette['shirt'])
        draw.line(((dark + bx, 14 + by), (dark + bx, hem)), fill=palette['shirt_shadow'])
        draw.line(((light + bx, 14 + by), (light + bx, hem)), fill=palette['shirt_light'])
        if facing < 2:
            x = (12 if facing == 0 else 11) + bx
            draw.line(((x, 13 + by), (x, hem)), fill=palette['b'])
            draw.line(((11 + bx, 11 + by), (12 + bx, 11 + by), (x - (1 if facing == 0 else -1), 13 + by)), fill=palette['lane'])
        else:
            draw.point(((11 if facing == 3 else 12) + bx, hem), fill=palette['shirt_shadow'])
    elif outfit == 'worker':
        draw.point(((12 if facing in (0, 3) else 11) + bx, 14 + by), fill=palette['lane'])
    elif outfit == 'overalls':
        draw.point((10 + bx, 12 + by), fill=palette['lane'])
        draw.point((13 + bx, 12 + by), fill=palette['lane'])
        draw.line(((11 + bx, 14 + by), (12 + bx, 14 + by)), fill=palette['b'])
    elif outfit == 'bunny':
        if facing > 1:
            x = (13 if facing == 2 else 9) + bx
            draw.ellipse((x, 13 + by, x + 1, 15 + by), fill=palette['w'])
            draw.point((x, 13 + by), fill=palette['W'])
        else:
            draw.point(((12 if facing == 0 else 11) + bx, 11 + by), fill=palette['red'])
    elif outfit == 'suit' and facing < 2:
        x = (12 if facing == 0 else 11) + bx
        draw.point((x, 12 + by), fill=palette['red'])
        draw.point((x, 13 + by), fill=palette['e'])


def draw_head(draw, outfit, facing, pose, palette):
    hx, hy = pose['head_offset']
    _stamp(draw, _HEADS[outfit][facing], 10 + hx, 7 + hy, palette)
    if facing < 2:
        eye = (13 if facing == 0 else 11) + hx
        draw.point((eye, 9 + hy), fill=palette['w'])
        draw.point((12 + hx, 10 + hy), fill=palette['skin_light'])
    if outfit == 'worker':
        draw.line(((11 + hx, 7 + hy), (13 + hx, 7 + hy)), fill=palette['woodL'])
        draw.line(((10 + hx, 8 + hy), (14 + hx, 8 + hy)), fill=palette['lane'])
        draw.point((12 + hx, 7 + hy), fill=palette['W'])
        draw.point((12 + hx, 6 + hy), fill=palette['woodL'])
        draw.point(((14 if facing in (0, 3) else 10) + hx, 8 + hy), fill=palette['woodL'])
    elif outfit == 'maid':
        draw.line(((10 + hx, 7 + hy), (14 + hx, 7 + hy)), fill=palette['w'])
        draw.point((11 + hx, 6 + hy), fill=palette['W'])
        draw.point((13 + hx, 6 + hy), fill=palette['W'])
        if facing > 1:
            draw.line(((11 + hx, 8 + hy), (13 + hx, 8 + hy)), fill=palette['w'])
    elif outfit == 'bunny':
        draw.line(((10 + hx, 4 + hy), (10 + hx, 7 + hy)), fill=palette['w'])
        draw.line(((11 + hx, 5 + hy), (11 + hx, 7 + hy)), fill=palette['W'])
        draw.line(((14 + hx, 4 + hy), (14 + hx, 7 + hy)), fill=palette['w'])
        draw.line(((13 + hx, 5 + hy), (13 + hx, 7 + hy)), fill=palette['W'])
        if facing < 2:
            draw.line(((10 + hx, 5 + hy), (10 + hx, 6 + hy)), fill=palette['coral'])
            draw.line(((14 + hx, 5 + hy), (14 + hx, 6 + hy)), fill=palette['coral'])
        draw.point((10 + hx, 8 + hy), fill=palette['shirt_light'])
        draw.point((14 + hx, 8 + hy), fill=palette['shirt_light'])
    elif outfit == 'overalls':
        draw.point(((11 if facing in (0, 3) else 13) + hx, 6 + hy), fill=palette['hair'])
    elif outfit == 'casual':
        draw.point(((10 if facing in (0, 3) else 14) + hx, 8 + hy), fill=palette['hair_light'])
