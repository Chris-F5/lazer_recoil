#!/bin/sh
set -e
nasm -f bin -o lr.com lazer_recoil.asm
#nasm -f obj -o lr.obj lazer_recoil.asm
dosbox lr.com
