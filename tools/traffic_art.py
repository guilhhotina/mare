from traffic_vehicles import car
from traffic_boat import boat
from traffic_fauna import FISH_SWIM_FRAMES, FISH_JUMP_FRAMES, DOLPHIN_FRAMES, WHALE_FRAMES, fish, dolphin, whale


def build(add):
    for prefix, name, frames, draw in (('vehicle', 'car', 2, car), ('vehicle', 'boat', 4, boat), ('fauna', 'fish', FISH_SWIM_FRAMES + FISH_JUMP_FRAMES, fish), ('fauna', 'dolphin', DOLPHIN_FRAMES, dolphin), ('fauna', 'whale', WHALE_FRAMES, whale)):
        for facing in range(8):
            for frame in range(frames):
                art = draw(facing, frame)
                add(f'{prefix}_{name}_{facing}_{frame}', art.im, (art.ox, art.oy), art.depth)
