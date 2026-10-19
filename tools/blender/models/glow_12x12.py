"""Glowing floor outline, 12 x 12 studs (round the garage turntable). See _glowkit."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _glowkit  # noqa: E402

PREVIEW = dict(dist=20, height=10, target_z=0)


def build(lib):
    _glowkit.outline(lib, 12, 12)
