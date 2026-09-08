from primitives import Art
from actor_wardrobe import build as build_wardrobe


def _site(stage):
    art = Art(1, 1, 18)
    if stage == 'reserved':
        art.plane(.16, .16, .84, .84, 0, 'soil')
        for u, v in ((.24, .3), (.6, .22), (.4, .67), (.7, .58)):
            art.line([(u, v, .2), (u + .08, v, .2)], 'sand')
        art.line([(.14, .14, 2), (.86, .14, 2), (.86, .86, 2), (.14, .86, 2), (.14, .14, 2)], 'lane')
        for u, v in ((.14, .14), (.86, .14), (.14, .86), (.86, .86)):
            art.block(u - .018, v - .018, u + .018, v + .018, 0, 5, 'woodL', 'wood', 'woodD')
            art.line([(u, v, 4), (u, v, 5)], 'cream')
    else:
        art.block(.13, .13, .87, .87, 0, 2, 'stone', 'shade', 'woodD')
        art.plane(.23, .23, .77, .77, 2.1, 'soil')
        for u in (.13, .8):
            art.block(u, .13, u + .07, .87, 2, 4, 'cream', 'shade', 'stone')
        for v in (.13, .8):
            art.block(.13, v, .87, v + .07, 2, 4, 'cream', 'shade', 'stone')
        for u in (.34, .59):
            art.line([(u, .81, 2), (u, .87, 2)], 'woodD')
        if stage == 'foundation':
            for v in (.35, .44, .53):
                art.block(.35, v, .69, v + .055, 2, 3, 'woodL', 'wood', 'woodD')
        else:
            for u, v in ((.18, .18), (.82, .18), (.18, .82), (.82, .82)):
                art.block(u - .025, v - .025, u + .025, v + .025, 4, 15, 'woodL', 'wood', 'woodD')
            art.block(.16, .16, .84, .21, 14, 16, 'woodL', 'wood', 'woodD')
            art.block(.16, .16, .21, .84, 14, 16, 'woodL', 'wood', 'woodD')
            art.line([(.2, .18, 4), (.72, .18, 14)], 'woodL', 2)
            art.line([(.18, .22, 4), (.18, .72, 14)], 'wood', 2)
            art.block(.79, .16, .84, .84, 14, 16, 'woodL', 'wood', 'woodD')
            art.block(.16, .79, .84, .84, 14, 16, 'woodL', 'wood', 'woodD')
            art.block(.3, .3, .72, .37, 2, 4, 'woodL', 'wood', 'woodD')
    return art


def build(add, save):
    build_wardrobe(add)
    for stage in ('reserved', 'foundation', 'frame'):
        save(f'site_{stage}', _site(stage))
