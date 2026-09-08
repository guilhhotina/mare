ACCESSORIES = ('none', 'hockey_mask', 'glasses', 'straw_hat', 'beret', 'flower_crown', 'rain_hood', 'star_cap')


def _at(x, y, facing, offset):
    return (24 - x if facing in (1, 2) else x) + offset[0], y + offset[1]


def _points(points, facing, offset):
    return tuple(_at(x, y, facing, offset) for x, y in points)


def draw_accessory(draw, index, facing, pose, palette):
    offset = pose['head_offset']
    front = facing < 2
    if index == 1:
        draw.line(_points(((10, 9), (14, 9)), facing, offset), fill=palette['woodD'])
        if front:
            draw.polygon(_points(((11, 8), (13, 8), (14, 9), (14, 10), (13, 11), (11, 11), (10, 10), (10, 9)), facing, offset), fill=palette['w'])
            draw.line(_points(((14, 9), (14, 10), (13, 11)), facing, offset), fill=palette['shade'])
            draw.point(_at(11, 8, facing, offset), fill=palette['W'])
            draw.point(_at(11, 10, facing, offset), fill=palette['e'])
            draw.point(_at(13, 10, facing, offset), fill=palette['e'])
            draw.point(_at(12, 8, facing, offset), fill=palette['red'])
            draw.point(_at(12, 11, facing, offset), fill=palette['woodD'])
        else:
            draw.line(_points(((11, 7), (12, 8), (12, 9)), facing, offset), fill=palette['woodD'])
            draw.point(_at(11, 9, facing, offset), fill=palette['shade'])
            draw.line(_points(((14, 9), (14, 10)), facing, offset), fill=palette['w'])
            draw.point(_at(14, 11, facing, offset), fill=palette['shade'])
    elif index == 2:
        if front:
            draw.line(_points(((10, 9), (14, 9)), facing, offset), fill=palette['e'])
            for x in (10, 12, 14):
                draw.point(_at(x, 10, facing, offset), fill=palette['e'])
            for x in (11, 13):
                draw.point(_at(x, 11, facing, offset), fill=palette['e'])
            draw.point(_at(11, 10, facing, offset), fill=palette['glass'])
            draw.point(_at(13, 10, facing, offset), fill=palette['blue'])
            draw.point(_at(13, 9, facing, offset), fill=palette['mint'])
        else:
            draw.line(_points(((12, 9), (14, 9), (14, 10)), facing, offset), fill=palette['e'])
            draw.point(_at(14, 10, facing, offset), fill=palette['glass'])
    elif index == 3:
        draw.polygon(_points(((11, 5), (13, 5), (14, 7), (10, 7)), facing, offset), fill=palette['woodL'])
        draw.line(_points(((11, 5), (12, 5), (13, 6)), facing, offset), fill=palette['lane'])
        draw.point(_at(14, 7, facing, offset), fill=palette['woodD'])
        draw.line(_points(((10, 7), (13, 7)), facing, offset), fill=palette['red'])
        if not front:
            draw.point(_at(10, 7, facing, offset), fill=palette['woodD'])
        draw.line(_points(((9, 8), (15, 8)), facing, offset), fill=palette['woodL'])
        draw.line(_points(((10, 8), (13, 8)), facing, offset), fill=palette['lane'])
        draw.point(_at(9, 8, facing, offset), fill=palette['woodD'])
        draw.point(_at(15, 8, facing, offset), fill=palette['woodD'])
    elif index == 4:
        draw.polygon(_points(((11, 5), (14, 6), (15, 7), (13, 8), (10, 8), (9, 7)), facing, offset), fill=palette['shirt_shadow'])
        draw.polygon(_points(((11, 5), (13, 6), (14, 7), (10, 7)), facing, offset), fill=palette['shirt'])
        draw.line(_points(((11, 6), (12, 6)), facing, offset), fill=palette['shirt_light'])
        draw.point(_at(12, 4, facing, offset), fill=palette['shirt_shadow'])
        if front:
            draw.point(_at(14, 7, facing, offset), fill=palette['lane'])
    elif index == 5:
        draw.line(_points(((10, 7), (12, 6), (14, 7)), facing, offset), fill=palette['grass'])
        if not front:
            draw.line(_points(((10, 8), (14, 8)), facing, offset), fill=palette['grass'])
        draw.point(_at(10, 8, facing, offset), fill=palette['teal'])
        draw.point(_at(14, 8, facing, offset), fill=palette['teal'])
        draw.line(_points(((9, 7), (11, 7)), facing, offset), fill=palette['coral'])
        draw.point(_at(10, 6, facing, offset), fill=palette['coral'])
        draw.point(_at(10, 7, facing, offset), fill=palette['lane' if front else 'woodL'])
        draw.point(_at(12, 6, facing, offset), fill=palette['W'])
        draw.line(_points(((13, 7), (15, 7)), facing, offset), fill=palette['blue'])
        draw.point(_at(14, 6, facing, offset), fill=palette['blue'])
        draw.point(_at(14, 7, facing, offset), fill=palette['lane' if front else 'woodL'])
    elif index == 6:
        if front:
            draw.polygon(_points(((11, 5), (13, 5), (15, 8), (9, 8)), facing, offset), fill=palette['shirt_shadow'])
            draw.polygon(_points(((11, 6), (13, 6), (14, 8), (10, 8)), facing, offset), fill=palette['shirt'])
            draw.line(_points(((9, 8), (9, 10), (10, 11), (11, 12)), facing, offset), fill=palette['shirt_shadow'])
            draw.line(_points(((10, 8), (10, 10), (11, 11)), facing, offset), fill=palette['shirt'])
            draw.line(_points(((15, 8), (15, 11), (14, 12), (13, 12)), facing, offset), fill=palette['shirt_shadow'])
            draw.line(_points(((14, 8), (14, 11), (13, 11)), facing, offset), fill=palette['shirt'])
            draw.point(_at(12, 6, facing, offset), fill=palette['shirt_light'])
            draw.line(_points(((14, 8), (14, 10)), facing, offset), fill=palette['shirt_light'])
        else:
            draw.polygon(_points(((11, 5), (13, 5), (15, 7), (15, 8), (14, 8), (13, 9), (13, 10), (12, 11), (13, 12), (10, 11), (9, 9), (9, 7)), facing, offset), fill=palette['shirt_shadow'])
            draw.polygon(_points(((11, 6), (13, 6), (14, 7), (13, 8), (12, 9), (12, 10), (11, 11), (10, 9), (10, 7)), facing, offset), fill=palette['shirt'])
            draw.line(_points(((11, 6), (12, 7), (12, 8)), facing, offset), fill=palette['shirt_light'])
            draw.point(_at(12, 10, facing, offset), fill=palette['shirt_shadow'])
    elif index == 7:
        draw.polygon(_points(((11, 6), (13, 6), (14, 7), (14, 8), (10, 8), (10, 7)), facing, offset), fill=palette['deep'])
        draw.line(_points(((10, 8), (14, 8)), facing, offset), fill=palette['shirt_shadow'])
        draw.point(_at(12, 5, facing, offset), fill=palette['lane'])
        if front:
            draw.line(_points(((14, 9), (15, 9)), facing, offset), fill=palette['shirt_shadow'])
            draw.line(_points(((11, 7), (13, 7)), facing, offset), fill=palette['lane'])
            draw.line(_points(((12, 6), (12, 8)), facing, offset), fill=palette['lane'])
            draw.point(_at(12, 6, facing, offset), fill=palette['W'])
        else:
            draw.line(_points(((12, 6), (12, 7)), facing, offset), fill=palette['shirt_shadow'])
            draw.point(_at(12, 8, facing, offset), fill=palette['lane'])
    else:
        raise ValueError(f'Unknown actor accessory: {index}')
