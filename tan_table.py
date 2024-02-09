#!/bin/python

import math

step = "step: dw "
stepextra = "stepextra: dw "
stepdelta = "stepdelta: dw "
stepdistance = "stepdistance: dw "
for i in range(0, 256):
    normal_theta = i % 64
    if normal_theta > 32:
        normal_theta = 64 - normal_theta
    normal_theta = (normal_theta/256) * 2 * math.pi
    delta = int(math.tan(normal_theta) * 255 + 0.001)
    distance = int(1/math.cos(normal_theta) * 64 + 0.001)
    s = 0
    es = 0
    if i < 32:
        s = 1
        es = 320
    elif i < 64:
        s = 320
        es = 1
    elif i < 96:
        s = 320
        es = -1
    elif i < 128:
        s = -1
        es = 320
    elif i < 160:
        s = -1
        es = -320
    elif i < 192:
        s = -320
        es = -1
    elif i < 224:
        s = -320
        es = 1
    elif i < 256:
        s = 1
        es = -320
    step += f'{s}, '
    stepextra += f'{es}, '
    stepdelta += f'{delta}, '
    stepdistance += f'{distance}, '
print(step)
print(stepextra)
print(stepdelta)
print(stepdistance)
