import math
from traffic_pixels import MovingArt


FISH_SWIM_FRAMES = 4
FISH_JUMP_FRAMES = 32
DOLPHIN_FRAMES = 48
WHALE_FRAMES = 96


def fish(facing, frame):
    art = MovingArt(facing, True)
    rise, pitch = .1, 0
    if frame < FISH_SWIM_FRAMES:
        sway = (0, .018, 0, -.018)[frame]
    else:
        progress = (frame - FISH_SWIM_FRAMES) / (FISH_JUMP_FRAMES - 1)
        rise += 5.4 * math.sin(progress * math.pi) - 3.2 * math.sin(progress * 3 * math.pi)
        pitch = 28 * math.sin(progress * math.tau)
        sway = .018 * math.sin(progress * math.tau * 2)
        splash = progress / .2 if progress < .2 else (progress - .72) / .28
        if 0 < splash < 1:
            art.ripple(0, .13 * math.sin(splash * math.pi), int(splash * 4))
    art.poly([(-.055, 0, rise - .055 * pitch), (-.12, -.025 + sway, rise - .12 * pitch), (-.105, sway, rise - .105 * pitch), (-.12, .025 + sway, rise - .12 * pitch)], 'teal')
    sections = ((-.075, .008, .2), (-.025, .035, .6), (.035, .03, .7), (.095, .006, .25))
    art.body([(forward, width, rise + forward * pitch, height) for forward, width, height in sections], ('mint', 'teal', 'deep'))
    eye = rise + .065 * pitch + .4
    if eye >= 0:
        art.dot(.065, .012 if art.dx >= art.dy else -.012, eye, 'deep')
    return art


def _fluke(art, forward, width, height, pitch, color):
    outline = ((.1, 0), (.025, -width * .45), (-.065, -width),
               (-.1, -width * .8), (-.025, 0), (-.1, width * .8),
               (-.065, width), (.025, width * .45))
    art.poly([(forward + offset, side, height + (forward + offset) * pitch)
              for offset, side in outline], color)


def dolphin(facing, frame):
    art = MovingArt(facing, True)
    progress = frame / (DOLPHIN_FRAMES - 1)
    rise = -7 + 12 * math.sin(progress * math.pi)
    pitch = 12 * math.sin(progress * math.tau)
    ripple_frame = int(progress * 7)
    art.ripple(0, .12 + .06 * abs(progress * 2 - 1), ripple_frame)
    if frame in (0, DOLPHIN_FRAMES - 1):
        art.ripple(-.15, .09, ripple_frame + 1)
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
    progress = frame / (WHALE_FRAMES - 1)
    rise = -10 + 13 * math.sin(progress * math.pi)
    pitch = 7 * math.sin(progress * math.tau)
    ripple_frame = int(progress * 7)
    art.ripple(.22, .27, ripple_frame)
    art.ripple(-.45, .23, ripple_frame + 1)
    if frame in (0, WHALE_FRAMES - 1):
        art.ripple(-.15, .16, ripple_frame + 2)
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
    spray = (progress - .22) / .26
    if 0 < spray < 1:
        height = 6 * math.sin(spray * math.pi)
        top = rise + .4 * pitch + 5.4
        art.line([(.4, 0, top), (.39, 0, top + height * .67), (.36, -.025, top + height)], 'mint')
        art.line([(.39, 0, top + height * .5), (.42, .025, top + height * .83)], 'cream')
    return art
