"""Toy grass clump: tuft_wheat (see _tuft.py)."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import _tuft  # noqa: E402

NAME = "TuftWheat"
HEIGHT = 2.6
BUDGET = 1400
TEX = 512


def build(k):
    return _tuft.build(k, NAME, "wheat", cut=False)
