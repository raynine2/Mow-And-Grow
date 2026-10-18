"""Grass clipping for the hit effects (variant c): a chunky cut piece of blade that flies off the clump, tumbles and
bounces. Centred on the origin (it's thrown around, not placed on the ground). The blade body is pure white so
the game can tint it with each zone's grass colour; the fresh-cut end is pale cream."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _fxclipkit import clip

PREVIEW = dict(dist=3.2, height=1.6, target_z=0.6)

def build(lib):
    clip(lib, "c")
