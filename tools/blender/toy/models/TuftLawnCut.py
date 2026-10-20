"""Toy grass clump: tuft_lawn_cut (see _tuft.py)."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import _tuft  # noqa: E402

NAME = "TuftLawnCut"
HEIGHT = 1.6
BUDGET = 700
TEX = 512


def build(k):
    return _tuft.build(k, NAME, "lawn", cut=True)
