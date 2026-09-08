from PIL import Image, ImageDraw
from primitives import C
from actor_poses import ACTIONS, CANVAS_SIZE, CANVAS_OFFSET, PIVOT, draw_props, pose
from actor_clothing import OUTFITS, draw_legs, draw_arm, draw_back_hair, draw_body, draw_head, shoulder, arm_points
from actor_accessories import ACCESSORIES, draw_accessory


SKIN_MARKERS = ((250, 1, 250, 255), (251, 1, 251, 255), (252, 1, 252, 255))
SHIRT_MARKERS = ((1, 250, 250, 255), (1, 251, 251, 255), (1, 252, 252, 255))
HAIR_MARKERS = ((250, 250, 1, 255), (251, 251, 1, 255), (252, 252, 1, 255))
SKIN_PALETTES = (
    ('#bc8465', '#e4b38d', '#f7d2aa'),
    ('#c7927c', '#efc4ac', '#ffe1c2'),
    ('#9f684b', '#ca9167', '#e5b58a'),
    ('#815038', '#b17b53', '#d29a6c'),
    ('#573c31', '#82563f', '#ab7958'),
    ('#372b29', '#594033', '#855c46'),
    ('#9a795a', '#bea078', '#dec39d'),
    ('#a86855', '#ce957a', '#edb9a0'),
)
SHIRT_PALETTES = (
    ('#245958', '#337c77', '#74afa0'),
    ('#822e3f', '#c44853', '#ec7b7a'),
    ('#9b652f', '#d59a49', '#f1c97c'),
    ('#625875', '#9789b0', '#c1b4d4'),
    ('#3f5876', '#647fa7', '#9ab1d0'),
    ('#4a644a', '#769363', '#a8be84'),
    ('#ada080', '#dfd3b1', '#fff0cf'),
    ('#38494e', '#5c6c6a', '#94a59c'),
)
HAIR_PALETTES = (
    ('#2d292b', '#493a33', '#72604a'),
    ('#533c32', '#79513b', '#ae7851'),
    ('#977245', '#c7a365', '#ead094'),
    ('#693f33', '#9d5d3f', '#ce8f57'),
    ('#697779', '#9ba7a1', '#d3d7c6'),
    ('#25272b', '#383338', '#5a5050'),
    ('#46342f', '#6a4c3c', '#a27758'),
    ('#4b3d50', '#755879', '#aa88a4'),
)
MARKERS = {'skin': SKIN_MARKERS, 'shirt': SHIRT_MARKERS, 'hair': HAIR_MARKERS}
PALETTES = {'skin': SKIN_PALETTES, 'shirt': SHIRT_PALETTES, 'hair': HAIR_PALETTES}
PALETTE = {
    **C,
    'skin_shadow': SKIN_MARKERS[0], 'skin': SKIN_MARKERS[1], 'skin_light': SKIN_MARKERS[2],
    'shirt_shadow': SHIRT_MARKERS[0], 'shirt': SHIRT_MARKERS[1], 'shirt_light': SHIRT_MARKERS[2],
    'hair_shadow': HAIR_MARKERS[0], 'hair': HAIR_MARKERS[1], 'hair_light': HAIR_MARKERS[2],
    'd': SKIN_MARKERS[0], 's': SKIN_MARKERS[1], 'S': SKIN_MARKERS[2],
    't': SHIRT_MARKERS[0], 'T': SHIRT_MARKERS[1], 'L': SHIRT_MARKERS[2],
    'h': HAIR_MARKERS[0], 'H': HAIR_MARKERS[1], 'K': HAIR_MARKERS[2],
    'e': C['ink'], 'w': C['cream'], 'W': C['light'], 'a': C['shade'], 'A': C['cream'],
    'b': '#3d5b63', 'B': '#648591',
}


def _shift(xy):
    ox, oy = CANVAS_OFFSET
    if isinstance(xy[0], (tuple, list)):
        return tuple((x + ox, y + oy) for x, y in xy)
    return tuple(value + (ox if i % 2 == 0 else oy) for i, value in enumerate(xy))


class _OffsetDraw:
    __slots__ = ('_draw',)

    def __init__(self, image):
        self._draw = ImageDraw.Draw(image)

    def point(self, xy, fill=None):
        self._draw.point(_shift(xy), fill=fill)

    def line(self, xy, fill=None, width=1, joint=None):
        self._draw.line(_shift(xy), fill=fill, width=width, joint=joint)

    def polygon(self, xy, fill=None, outline=None, width=1):
        self._draw.polygon(_shift(xy), fill=fill, outline=outline, width=width)

    def rectangle(self, xy, fill=None, outline=None, width=1):
        self._draw.rectangle(_shift(xy), fill=fill, outline=outline, width=width)

    def ellipse(self, xy, fill=None, outline=None, width=1):
        self._draw.ellipse(_shift(xy), fill=fill, outline=outline, width=width)

    def arc(self, xy, start, end, fill=None, width=1):
        self._draw.arc(_shift(xy), start, end, fill=fill, width=width)


def _prop_layers(posed, facing):
    back = Image.new('RGBA', CANVAS_SIZE)
    front = Image.new('RGBA', CANVAS_SIZE)
    draw_props(_OffsetDraw(back), posed, facing, PALETTE, 'back')
    draw_props(_OffsetDraw(front), posed, facing, PALETTE, 'front')
    occlusion = front.getchannel('A')
    mask = _OffsetDraw(occlusion)
    for point in arm_points(shoulder(facing, posed['body_offset'], True), posed['near_hand']):
        mask.point(point, fill=255)
    return back, front, occlusion


def _actor(outfit, facing, posed, back, front):
    image = Image.new('RGBA', CANVAS_SIZE)
    image.alpha_composite(back)
    draw = _OffsetDraw(image)
    draw_legs(draw, outfit, facing, posed, PALETTE)
    if facing < 2:
        draw_back_hair(draw, outfit, facing, posed, PALETTE)
    draw_arm(draw, outfit, facing, posed, PALETTE, False)
    draw_body(draw, outfit, facing, posed, PALETTE)
    if facing > 1:
        draw_back_hair(draw, outfit, facing, posed, PALETTE)
    draw_head(draw, outfit, facing, posed, PALETTE)
    draw_arm(draw, outfit, facing, posed, PALETTE, True)
    image.alpha_composite(front)
    return image


def _accessory(index, facing, posed, occlusion):
    image = Image.new('RGBA', CANVAS_SIZE)
    draw_accessory(_OffsetDraw(image), index, facing, posed, PALETTE)
    image.paste((0, 0, 0, 0), (0, 0), occlusion)
    return image


def build(add):
    for action in ACTIONS:
        action_id = action['id']
        for facing in range(4):
            for frame in range(action['frames']):
                posed = pose(action_id, facing, frame)
                back, front, occlusion = _prop_layers(posed, facing)
                for outfit in OUTFITS:
                    add(f'actor_{outfit}_{facing}_{action_id}_{frame}', _actor(outfit, facing, posed, back, front), PIVOT)
                for index in range(1, len(ACCESSORIES)):
                    image = _accessory(index, facing, posed, occlusion)
                    if image.getbbox():
                        add(f'actor_accessory_{index}_{facing}_{action_id}_{frame}', image, PIVOT)
