"""Glowing floor outline, 16 x 6 studs (the classes cabin porch). See _glowkit."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _glowkit  # noqa: E402

PREVIEW = dict(dist=22, height=10, target_z=0)


def build(lib):
    _glowkit.outline(lib, 16, 6)
