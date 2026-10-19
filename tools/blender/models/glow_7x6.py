"""Glowing floor outline, 7 x 6 studs (each rewards stall bay). See _glowkit."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _glowkit  # noqa: E402

PREVIEW = dict(dist=13, height=7, target_z=0)


def build(lib):
    _glowkit.outline(lib, 7, 6)
