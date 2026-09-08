import json
from pathlib import Path

from actor_pose_props import draw_props, _DRAWERS
import actor_pose_home
import actor_pose_commerce
import actor_pose_services
import actor_pose_leisure


CANVAS_SIZE = (32, 32)
CANVAS_OFFSET = (4, 4)
PIVOT = (16, 22)
CANONICAL_BOUNDS = (-4, -4, 28, 28)
REST_FRAME = 0
CONTACT_POINTS = {
    'work_edge': (7, 0, 2),
    'work_surface': (7, 0, 4),
    'counter': (5, 0, 12),
    'door': (5, 0, 7),
    'garden': (7, 0, 7),
    'animal': (7, 0, 6),
}
ACTIONS = tuple(json.loads((Path(__file__).resolve().parents[1] / 'art_source' / 'activities.json').read_text()))
ACTION_META = {entry['id']: entry for entry in ACTIONS}
_DIRECTIONS = ((1, 1), (-1, 1), (-1, -1), (1, -1))
_AUTHORS = {}


def _author(function):
    _AUTHORS[function.__name__[1:]] = function
    return function


class _Pose:
    def __init__(self, facing):
        self.facing = facing
        self.dx, self.dy = _DIRECTIONS[facing]
        self.side = -self.dx * self.dy
        self.near_x = 12 if self.dx > 0 else 10
        self.far_x = 10 if self.dx > 0 else 12
        self.data = {
            'near_foot': (self.near_x, 18),
            'far_foot': (self.far_x, 17),
            'near_hand': (14 if self.dx > 0 else 9, 15),
            'far_hand': (9 if self.dx > 0 else 14, 14),
            'head_offset': (0, 0),
            'body_offset': (0, 0),
            'prop': None,
            'prop_points': (),
        }

    def q(self, forward, lateral=0, height=0):
        return (round(12 + self.dx * forward - self.dy * lateral),
                round(18 + (self.dy * forward + self.dx * lateral) / 2 - height))

    def near(self, forward, lateral, height):
        self.data['near_hand'] = self.q(forward, self.side * lateral, height)
        return self.data['near_hand']

    def far(self, forward, lateral, height):
        self.data['far_hand'] = self.q(forward, -self.side * lateral, height)
        return self.data['far_hand']

    def bend(self, forward, lower, head_forward=None, head_lower=None):
        self.data['body_offset'] = (self.dx * forward, round(self.dy * forward / 2) + lower)
        hf = forward if head_forward is None else head_forward
        hl = lower if head_lower is None else head_lower
        self.data['head_offset'] = (self.dx * hf, round(self.dy * hf / 2) + hl)

    def feet(self, stride=0, near_lift=0, far_lift=0):
        self.data['near_foot'] = (self.near_x + self.dx * stride, 18 + round(self.dy * stride / 2) - near_lift)
        self.data['far_foot'] = (self.far_x - self.dx * stride, 17 - round(self.dy * stride / 2) - far_lift)

    def seat(self, swing=0):
        self.data['near_foot'] = self.q(3, self.side, 2 + swing)
        self.data['far_foot'] = self.q(2, -self.side, 3 - swing)
        self.near(2, 2, 4)
        self.far(1, 2, 5)

    def prop(self, name, *points):
        self.data['prop'] = name
        self.data['prop_points'] = tuple(points)


def pose(action, facing, frame):
    metadata = ACTION_META[action]
    if facing not in range(4):
        raise ValueError(f'Unsupported actor facing: {facing}')
    index = REST_FRAME if frame is None or frame < 0 else int(frame)
    index = index % metadata['frames'] if metadata['loop'] else min(index, metadata['frames'] - 1)
    authored = _Pose(facing)
    _AUTHORS[action](authored, index)
    return authored.data


def rest_pose(action, facing):
    return pose(action, facing, REST_FRAME)


@_author
def _walk(p, f):
    stride = (0, 1, 2, 1, 0, -1, -2, -1)[f]
    bob = (0, 0, -1, 0, 0, 0, -1, 0)[f]
    p.feet(stride, (0, 0, 0, 0, 0, 1, 2, 1)[f], (0, 1, 2, 1, 0, 0, 0, 0)[f])
    p.bend(0, bob)
    p.data['near_hand'] = ((14 if p.dx > 0 else 9) - p.dx * stride, 15 - round(p.dy * stride / 2) + bob)
    p.data['far_hand'] = ((9 if p.dx > 0 else 14) + p.dx * stride, 14 + round(p.dy * stride / 2) + bob)


@_author
def _wait(p, f):
    p.data['head_offset'] = (0, (0, 0, 1, 0)[f])
    p.far(0, 2, (5, 5, 4, 5)[f])


@_author
def _enter(p, f):
    p.feet((0, 1, 0, -1, 0, 0)[f], (0, 0, 0, 1, 1, 0)[f], (0, 1, 1, 0, 0, 0)[f])
    p.bend((0, 0, 1, 1, 1, 0)[f], 0)
    p.near((2, 4, 5, 5, 3, 1)[f], 1, (4, 6, 7, 7, 5, 3)[f])
    p.far((0, 0, 1, 2, 1, 0)[f], 2, 4)


@_author
def _exit(p, f):
    p.feet((0, -1, 0, 1, 0, 0)[f], (0, 1, 1, 0, 0, 0)[f], (0, 0, 0, 1, 1, 0)[f])
    p.bend((0, -1, -1, 0, 0, 0)[f], 0, (0, -1, 0, 1, 0, 0)[f])
    p.near((1, 0, -1, 0, 1, 0)[f], 2, (4, 5, 5, 4, 3, 3)[f])
    p.far((1, 3, 4, 3, 1, 0)[f], 1, (4, 6, 7, 6, 5, 4)[f])


@_author
def _survey(p, f):
    aim = (0, 0, 1, 1, 0, -1, -1, 0)[f]
    p.bend((0, 1, 1, 1, 1, 1, 1, 0)[f], 0)
    p.near(5, 1, 8 + aim)
    p.far(5, 1, 7)
    p.prop('survey', p.q(7), p.q(5, 0, 9), p.q(10, 0, 9 + aim), p.q(7, 0, 7), p.q(9, 2, 2))


@_author
def _mark(p, f):
    lean = (0, 1, 2, 2, 1, 0)[f]
    p.bend(lean, (0, 1, 2, 2, 1, 0)[f])
    hand = p.near((3, 5, 6, 6, 5, 3)[f], 1, (5, 4, 3, 3, 4, 5)[f])
    p.far(2, 2, (4, 3, 2, 2, 3, 4)[f])
    tip = p.q((4, 6, 7, 7, 6, 4)[f], (0, 0, -1, 1, 0, 0)[f], (4, 3, 2, 2, 3, 4)[f])
    p.prop('mark', hand, tip, p.q(7, -2, 2), p.q(7, 2, 2))


@_author
def _carry_timber(p, f):
    forward = (3, 4, 5, 7, 7, 5, 3, 2)[f]
    height = (6, 6, 5, 4, 4, 5, 5, 4)[f]
    p.bend((0, 0, 1, 2, 2, 1, 0, 0)[f], (0, 0, 1, 2, 2, 1, 0, 0)[f])
    p.feet(1)
    p.near(forward, 3, height)
    p.far(forward, 3, height)
    p.prop('carry_timber', p.q(forward if f < 4 else 7, 0, height - 1 if f < 4 else 3))


@_author
def _stack_bricks(p, f):
    forward = (3, 3, 4, 5, 7, 7, 5, 3)[f]
    height = (4, 3, 5, 6, 3, 2, 4, 4)[f]
    p.bend((0, 1, 1, 1, 2, 2, 1, 0)[f], (0, 2, 1, 0, 2, 2, 1, 0)[f])
    p.near(forward, 1, height)
    p.far(forward, 1, height)
    brick = p.q(forward if f < 5 else 7, 0, height - 1 if f < 5 else 1)
    p.prop('stack_bricks', brick, p.q(2, -p.side * 4), p.q(7))


@_author
def _mix_mortar(p, f):
    circle = ((0, 0), (1, 0), (1, 1), (0, 1), (-1, 0), (-1, -1), (0, -1), (0, 0))[f]
    p.bend(1, 1, 1, 2)
    grip = p.near(5 + circle[0], 1, 6 + (f in (2, 3)))
    p.far(6, 2, 3)
    p.prop('mix_mortar', p.q(7), grip, p.q(7 + circle[0], circle[1], 2))


@_author
def _lay_bricks(p, f):
    p.bend((0, 1, 1, 2, 2, 2, 1, 0)[f], (0, 0, 1, 2, 2, 2, 1, 0)[f])
    hand = p.near((3, 4, 5, 6, 6, 6, 4, 3)[f], 1, (6, 6, 5, 4, 4, 4, 5, 6)[f])
    p.far((3, 4, 6, 7, 7, 6, 4, 3)[f], 1, (6, 6, 4, 3, 2, 3, 4, 4)[f])
    tip = p.q((4, 5, 6, 7, 7, 7, 5, 4)[f], (0, 0, -2, -2, 0, 2, 1, 0)[f], (5, 5, 2, 2, 2, 2, 4, 5)[f])
    brick = p.q((3, 4, 6, 7, 7, 7, 7, 7)[f], 0, (5, 5, 3, 1, 1, 1, 1, 1)[f])
    p.prop('lay_bricks', hand, tip, brick, p.q(7, 0, 1))


@_author
def _hammer(p, f):
    p.bend((0, 0, 0, 1, 2, 1, 0, 0)[f], (0, 0, -1, 0, 2, 1, 0, 0)[f])
    p.feet(1)
    hand = p.near((3, 2, 1, 3, 4, 5, 4, 3)[f], 1, (7, 10, 12, 9, 7, 6, 8, 7)[f])
    p.far(7, 1, 4)
    tip = p.q((4, 1, 0, 4, 7, 6, 5, 4)[f], 0, (9, 14, 15, 10, 4, 6, 10, 9)[f])
    p.prop('hammer', hand, tip, p.q(7, 0, 4))


@_author
def _saw(p, f):
    stroke = (0, 1, 2, 3, 2, 1, 0, 0)[f]
    p.bend(1 + (stroke == 3), 1)
    p.feet(1)
    hand = p.near(3 + stroke, 1, 5)
    p.far(7, 2, 4)
    p.prop('saw', hand, p.q(7 + stroke, 0, 4), p.q(7, 0, 4))


@_author
def _paint(p, f):
    height = (6, 5, 4, 4, 4, 4, 5, 6)[f]
    forward = (5, 7, 8, 9, 9, 8, 7, 5)[f]
    p.bend((0, 1, 2, 2, 2, 2, 1, 0)[f], (0, 1, 2, 2, 2, 2, 1, 0)[f])
    hand = p.near((3, 4, 5, 5, 5, 5, 4, 3)[f], 1, height + 2)
    p.far(1, 2, 3)
    p.prop('paint', hand, p.q(forward, 0, height), p.q(1, -p.side * 4), p.q(7, 0, 4))


@_author
def _inspect_work(p, f):
    p.bend((0, 0, 1, 1, 1, 1, 0, 0)[f], 0, (0, 0, 1, 2, 2, 1, 0, 0)[f], (0, 1, 1, 2, 2, 1, 0, 0)[f])
    board = p.far(2, 2, 7)
    hand = p.near((2, 3, 4, 4, 4, 4, 3, 2)[f], 1, (7, 8, 7, 6, 6, 7, 8, 7)[f])
    tip = p.q((3, 3, 5, 7, 7, 5, 3, 3)[f], 0, (7, 8, 6, 4, 4, 6, 8, 7)[f])
    p.prop('inspect_work', board, hand, tip)


for _family in (actor_pose_home, actor_pose_commerce, actor_pose_services, actor_pose_leisure):
    _AUTHORS.update(_family.AUTHORS)
    _DRAWERS.update(_family.DRAWERS)
