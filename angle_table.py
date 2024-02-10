#!/bin/python3

import math

cos_table = "cos: dw "
sin_table = "sin: dw "

for i in range(256):
    theta = i/256 * 2 * math.pi
    cos = int(math.cos(theta) * 11 + 0.01)
    sin = int(math.sin(theta) * 11 + 0.01)
    cos_table += f'{cos}'
    sin_table += f'{sin}'
    if i != 255:
        cos_table += ', '
        sin_table += ', '
print(cos_table)
print(sin_table)
