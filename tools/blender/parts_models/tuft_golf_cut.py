"""Cut Golf Grass, low-part version: crown and four neat stubs with pale cut tops. 9 parts."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _tuftkit as kit  # noqa: E402


def build(lib):
    kit.stubble(lib, 4, 0.45, (60, 150, 64), (96, 196, 90), (220, 246, 200), height=0.5, crown=(1.1, 1.1, 0.35))
