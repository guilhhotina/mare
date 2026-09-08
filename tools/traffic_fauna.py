from traffic_pixels import MovingArt


def fish(facing, frame):
    art = MovingArt(facing, True)
    sway = (0, .018, 0, -.018)[frame]
    art.poly([(-.055, 0, .1), (-.12, -.025 + sway, .1), (-.105, sway, .1), (-.12, .025 + sway, .1)], 'teal')
    art.body(((-.075, .008, .1, .2), (-.025, .035, .1, .6), (.035, .03, .1, .7), (.095, .006, .1, .25)), ('mint', 'teal', 'deep'))
    art.dot(.065, .012 if art.dx >= art.dy else -.012, .5, 'deep')
    return art


def _fluke(art, forward, width, height, pitch, color):
    outline = ((.1, 0), (.025, -width * .45), (-.065, -width),
               (-.1, -width * .8), (-.025, 0), (-.1, width * .8),
               (-.065, width), (.025, width * .45))
    art.poly([(forward + offset, side, height + (forward + offset) * pitch)
              for offset, side in outline], color)


def dolphin(facing, frame):
    art = MovingArt(facing, True)
    rise = (-7, -3, 1, 5, 5, 1, -3, -8)[frame]
    pitch = (0, 10, 11, 6, -5, -10, -7, 0)[frame]
    art.ripple(0, .18 if frame in (0, 7) else .12, frame)
    if frame in (0, 7):
        art.ripple(-.15, .09, frame + 1)
        return art
    sections = ((-.33, .02, .7), (-.2, .065, 2), (0, .1, 3), (.19, .075, 2.3), (.29, .043, 1.4), (.33, .025, .7), (.43, .012, .45))
    art.body([(forward, width, rise + forward * pitch, height) for forward, width, height in sections], ('blue', 'glass', 'mint'))
    _fluke(art, -.4, .12, rise, pitch, 'glass')
    art.poly([(-.13, 0, rise - .13 * pitch + 2.6), (-.02, 0, rise - .02 * pitch + 7), (.05, 0, rise + .05 * pitch + 2.8)], 'glass')
    for side in (-1, 1):
        art.poly([(.06, side * .075, rise + .06 * pitch), (-.1, side * .18, rise - .1 * pitch - .8), (-.035, side * .065, rise - .035 * pitch)], 'glass')
    eye = rise + .26 * pitch + 1
    if eye >= 0:
        art.dot(.26, .055 if art.dx >= art.dy else -.055, eye, 'ink')
    return art


def whale(facing, frame):
    art = MovingArt(facing, True)
    rise = (-10, -5, -1, 2.5, 3, 0, -4, -10)[frame]
    pitch = (0, 5, 4, 1, -2, -4, -7, 0)[frame]
    art.ripple(.22, .27, frame)
    art.ripple(-.45, .23, frame + 1)
    if frame in (0, 7):
        art.ripple(-.15, .16, frame + 2)
        return art
    sections = ((-.77, .035, 1), (-.58, .1, 2.5), (-.3, .2, 5), (.05, .25, 6), (.42, .235, 5.3), (.67, .16, 3.9), (.84, .07, 2.2), (.9, .015, .8))
    art.body([(forward, width, rise + forward * pitch, height) for forward, width, height in sections], ('teal', 'deep', 'mint'))
    _fluke(art, -.92, .27, rise, pitch, 'deep')
    art.poly([(-.36, 0, rise - .36 * pitch + 4.5), (-.25, 0, rise - .25 * pitch + 8), (-.12, 0, rise - .12 * pitch + 5.4)], 'deep')
    for side in (-1, 1):
        art.poly([(.2, side * .2, rise + .2 * pitch), (-.03, side * .4, rise - .03 * pitch - 1.8), (.06, side * .19, rise + .06 * pitch)], 'deep')
    eye = rise + .65 * pitch + 1.1
    if eye >= 0:
        art.dot(.65, .13 if art.dx >= art.dy else -.13, eye, 'ink')
    if frame in (2, 3):
        top = rise + .4 * pitch + 5.4
        art.line([(.4, 0, top), (.39, 0, top + 4), (.36, -.025, top + 6)], 'mint')
        art.line([(.39, 0, top + 3), (.42, .025, top + 5)], 'cream')
    return art
