from math import hypot
from traffic_pixels import MovingArt


_OUTLINE = ((-.39, -.14), (.2, -.16), (.38, -.1), (.46, 0),
            (.38, .1), (.2, .16), (-.39, .14))


def _band(art, lower, upper, colors):
    for i, point in enumerate(lower):
        j = (i + 1) % len(lower)
        following = lower[j]
        nx, ny = art.rotate(following[1] - point[1], point[0] - following[0])
        light = (ny - nx * .6) / hypot(nx, ny)
        shade = colors[0] if light > .35 else colors[1] if light > -.35 else colors[2]
        art.poly((point, following, upper[j], upper[i]), shade)


def _hull(art, lift):
    keel = tuple((f * .88, s * .65, .1 + lift) for f, s in _OUTLINE)
    chine = tuple((f * .97, s * .9, 2 + lift) for f, s in _OUTLINE)
    sheer = tuple((f, s, 5 + max(0, f) * 2 + lift) for f, s in _OUTLINE)
    _band(art, keel, chine, ('coral', 'red', '#763e39'))
    _band(art, chine, sheer, ('cream', 'shade', '#83928a'))
    art.poly(sheer, 'light')
    deck = tuple((f * .92, s * .72, 5 + max(0, f * .92) * 2 + lift) for f, s in _OUTLINE)
    art.poly(deck, 'woodL')
    for side in (-.065, 0, .065):
        art.line([(-.35, side, 5.05 + lift), (.32, side, 5.69 + lift)], 'wood')
    art.line([(*point[:2], point[2] + .1) for point in sheer] + [sheer[0]], 'cream')
    for side in (-1, 1):
        art.line([(-.32, side * .144, 3 + lift), (.19, side * .162, 3 + lift),
                  (.37, side * .103, 3.5 + lift)], 'teal')
        art.block(-.31, side * .085 - .02, -.24, side * .085 + .02,
                  5 + lift, 6 + lift, 'woodL', 'wood', 'woodD')


def _cabin(art, lift):
    lower = ((-.18, -.105, 5.1 + lift), (.17, -.105, 5.1 + lift),
             (.17, .105, 5.1 + lift), (-.18, .105, 5.1 + lift))
    upper = ((-.17, -.095, 10.4 + lift), (.105, -.095, 10.4 + lift),
             (.105, .095, 10.4 + lift), (-.17, .095, 10.4 + lift))
    _band(art, lower, upper, ('light', 'cream', 'shade'))
    for side in (-1, 1):
        y0, y1 = side * .1055, side * .096
        art.poly([(-.145, y0, 6.5 + lift), (.145, y0, 6.5 + lift),
                  (.087, y1, 9.6 + lift), (-.14, y1, 9.6 + lift)], 'glass')
        art.line([(-.13, y1, 9.4 + lift), (.08, y1, 9.4 + lift)], 'blue')
        art.line([(-.035, y0, 6.5 + lift), (-.035, y1, 9.6 + lift)], 'cream')
        art.line([(-.145, y0, 6.1 + lift), (.145, y0, 6.1 + lift)], 'teal')
    art.poly([(.16, -.075, 6.3 + lift), (.16, .075, 6.3 + lift),
              (.113, .075, 9.7 + lift), (.113, -.075, 9.7 + lift)], 'glass')
    art.line([(.115, -.067, 9.5 + lift), (.115, .067, 9.5 + lift)], 'blue')
    art.line([(.16, 0, 6.3 + lift), (.111, 0, 9.8 + lift)], 'cream')
    art.poly([(-.181, -.065, 6 + lift), (-.181, .045, 6 + lift),
              (-.173, .045, 9.5 + lift), (-.173, -.065, 9.5 + lift)], 'deep')
    art.line([(-.174, -.055, 9 + lift), (-.174, .035, 9 + lift)], 'blue')
    rim = ((-.205, -.125, 10.4 + lift), (.15, -.125, 10.4 + lift),
           (.15, .125, 10.4 + lift), (-.205, .125, 10.4 + lift))
    crown = tuple((f, s, 11.4 + lift) for f, s, _ in rim)
    _band(art, rim, crown, ('coral', 'red', '#763e39'))
    for side in (-1, 1):
        art.poly([(-.205, side * .125, 11.4 + lift), (.15, side * .125, 11.4 + lift),
                  (.13, 0, 12.1 + lift), (-.185, 0, 12.1 + lift)], 'coral' if side == 1 else '#edaa7b')
    art.line([(-.185, 0, 12.15 + lift), (.13, 0, 12.15 + lift)], 'sand')
    art.block(-.105, -.045, -.015, .045, 12 + lift, 12.8 + lift, 'cream', 'shade', 'red')
    art.line([(.075, 0, 12 + lift), (.075, 0, 15 + lift)], 'deep')
    art.dot(.075, 0, 15 + lift, 'light')


def _fittings(art, lift):
    art.block(-.425, -.048, -.355, .048, .6 + lift, 4.5 + lift, 'stone', 'deep', 'ink')
    art.plane(-.42, -.043, -.365, .043, 4.6 + lift, 'blue')
    for side in (-1, 1):
        rail = [(.22, side * .125, 5.5 + lift), (.22, side * .125, 7.6 + lift),
                (.36, side * .08, 8 + lift), (.415, 0, 8.2 + lift)]
        art.line(rail, 'cream' if side == 1 else 'shade')
        art.line([(.36, side * .08, 5.9 + lift), (.36, side * .08, 8 + lift)], 'cream')
    art.line([(.31, -.035, 6 + lift), (.31, .035, 6 + lift)], 'deep')
    art.dot(.31, 0, 6.6 + lift, 'stone')


def boat(facing, frame):
    art = MovingArt(facing, True)
    art.ripple(-.52, .14, frame)
    art.ripple(-.4, .18, frame + 2)
    lift = (0, .3, 0, -.3)[frame]
    _hull(art, lift)
    _cabin(art, lift)
    _fittings(art, lift)
    return art
