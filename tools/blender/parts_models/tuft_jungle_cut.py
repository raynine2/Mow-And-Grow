"""Cut Jungle Bush, low-part version: the dark crown and five chunky leaf-stalk stubs with pale cut tops. 11 parts."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _tuftkit as kit  # noqa: E402


def build(lib):
    kit.stubble(lib, 5, 0.75, (24, 84, 34), (30, 130, 54), (190, 230, 170), height=1.1, crown=(1.8, 1.8, 0.6))
