#!/bin/python3

import math

tan = "tan: dw "
for i in range(0, 55):
    t = int(math.tan(i/256 * 2 * math.pi) * 64 + 0.001)
    tan += f'{t}'
    if i != 54:
        tan += ', '

print(tan)

