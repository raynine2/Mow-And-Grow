"""Jungle Bush clump, low-part version (~8.5 tall): five huge broad leaves arching up and out of a dark crown with
lighter pointed tips, one young leaf standing upright in the middle, and a bright pink flower with a yellow centre. 15 parts."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _tuftkit as kit  # noqa: E402


def build(lib):
    blades = [(0, 34, 5.6, 1.7), (72, 40, 5.2, 1.7), (144, 30, 5.8, 1.7), (216, 42, 5.0, 1.7), (288, 36, 5.4, 1.7), (40, 6, 4.4, 1.1)]
    kit.clump(lib, blades, (24, 84, 34), [(30, 130, 54), (40, 150, 62)], (110, 200, 90), crown=(1.8, 1.8, 0.7))
    lib.box("petals", (1.2, 1.2, 0.35), (-1.4, 1.2, 2.6), rot=(10, -10, 45), mat=lib.material("SmoothPlastic", (255, 110, 190)))
    lib.box("centre", (0.5, 0.5, 0.4), (-1.4, 1.2, 2.8), rot=(10, -10, 45), mat=lib.material("SmoothPlastic", (255, 214, 60)))
