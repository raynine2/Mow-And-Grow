"""Lawn Grass clump, low-part version (~4.3 tall): a crown and six chunky blades with pointed tips, three standing
nearly upright in the middle and three arching out, in two lawn greens with lime tips. 13 parts."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _tuftkit as kit  # noqa: E402


def build(lib):
    blades = [(0, 8, 3.4, 0.7), (120, 10, 3.2, 0.7), (240, 9, 3.5, 0.7),
              (60, 34, 3.0, 0.75), (180, 32, 2.8, 0.75), (300, 36, 3.0, 0.75)]
    kit.clump(lib, blades, (52, 120, 40), [(84, 168, 52), (104, 186, 60)], (170, 222, 90))
