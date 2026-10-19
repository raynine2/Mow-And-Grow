"""Golf Grass clump, low-part version (~3 tall): a neat tight tuft of six narrow straight blades in bright golf
greens with pale mint tips, and a little clover at its foot. 14 parts."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _tuftkit as kit  # noqa: E402


def build(lib):
    blades = [(0, 6, 2.6, 0.5), (120, 6, 2.5, 0.5), (240, 6, 2.7, 0.5),
              (60, 22, 2.2, 0.55), (180, 22, 2.3, 0.55), (300, 22, 2.1, 0.55)]
    kit.clump(lib, blades, (60, 150, 64), [(96, 196, 90), (118, 210, 104)], (190, 240, 190), crown=(1.1, 1.1, 0.4))
    lib.box("clover", (0.7, 0.7, 0.18), (1.2, 0.6, 0.09), rot=(0, 0, 30), mat=lib.material("Grass", (70, 170, 70)))
