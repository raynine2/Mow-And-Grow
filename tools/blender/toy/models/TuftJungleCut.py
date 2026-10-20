"""Toy grass clump: tuft_jungle_cut (see _tuft.py)."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import _tuft  # noqa: E402

NAME = "TuftJungleCut"
HEIGHT = 1.6
BUDGET = 700
TEX = 512


def build(k):
    return _tuft.build(k, NAME, "jungle", cut=True)
