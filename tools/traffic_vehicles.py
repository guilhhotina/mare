from traffic_pixels import MovingArt


def car(facing, frame):
    art = MovingArt(facing)
    art.block(-.24, -.115, .24, .115, 2, 5, 'coral', 'red', 'red')
    for forward in (-.15, .15):
        for side in (-.135, .135):
            art.poly([(forward - .045, side, 1), (forward + .035, side, 1), (forward + .05, side, 2), (forward + .035, side, 4), (forward - .035, side, 4), (forward - .05, side, 2)], 'ink')
            art.dot(forward, side, 2 + frame, 'stone')
            for edge in (-1, 1):
                art.dot(forward + edge * (.05 - .0075 * frame), side, 2 + frame, 'asphalt')
    art.block(-.14, -.1, .09, .1, 5, 8, 'cream', 'glass', 'glass')
    art.plane(-.12, -.08, .07, .08, 8.1, 'light')
    for side in (-.102, .102):
        art.line([(-.025, side, 5.2), (-.025, side, 7.6)], 'cream')
        art.line([(-.12, side, 5), (.07, side, 5)], 'coral')
    art.plane(.1, -.09, .23, .09, 5.05, 'coral')
    for side in (-.075, .075):
        art.poly([(.242, side - .025, 3.1), (.242, side + .025, 3.1), (.242, side + .025, 4.3), (.242, side - .025, 4.3)], 'light')
        art.dot(-.242, side, 3.4, 'coral')
    art.line([(.244, -.08, 2.5), (.244, .08, 2.5)], 'stone')
    return art
