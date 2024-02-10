#!/bin/python3

import math

a = (100, 50)
theta = 10
normal_theta = (theta + 64) % 256
n = (int(-math.sin(theta/256 * math.pi * 2) * 64), int(math.cos(theta/256 * math.pi * 2) * 64))
p = (int(math.cos(theta/256 * math.pi * 2) * 64), int(math.sin(theta/256 * math.pi * 2) * 64))
print(f'{a[0]}, {a[1]}, {n[0]}, {n[1]}, {p[0]}, {p[1]}, {normal_theta}')
