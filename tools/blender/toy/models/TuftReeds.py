"""Toy grass clump: tuft_reeds (see _tuft.py)."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import _tuft  # noqa: E402

NAME = "TuftReeds"
HEIGHT = 2.6
BUDGET = 1400
TEX = 512


def build(k):
    return _tuft.build(k, NAME, "reeds", cut=False)
