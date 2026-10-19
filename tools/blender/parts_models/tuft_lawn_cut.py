"""Cut Lawn Grass, low-part version: the crown and four short stubs with pale fresh-cut tops. 9 parts."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _tuftkit as kit  # noqa: E402


def build(lib):
    kit.stubble(lib, 4, 0.55, (52, 120, 40), (84, 168, 52), (214, 240, 160))
