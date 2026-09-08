from traffic_vehicles import car
from traffic_boat import boat
from traffic_fauna import fish, dolphin, whale


def build(add):
    for prefix, name, frames, draw in (('vehicle', 'car', 2, car), ('vehicle', 'boat', 4, boat), ('fauna', 'fish', 4, fish), ('fauna', 'dolphin', 8, dolphin), ('fauna', 'whale', 8, whale)):
        for facing in range(8):
            for frame in range(frames):
                art = draw(facing, frame)
                add(f'{prefix}_{name}_{facing}_{frame}', art.im, (art.ox, art.oy), art.depth)
