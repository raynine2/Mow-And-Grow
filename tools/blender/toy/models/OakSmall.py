"""Small oak (toy): a younger, rounder oak. Replaces the game's "oak_small"."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import Oak  # noqa: E402

NAME = "OakSmall"
HEIGHT = 3.8
BUDGET = 4000
TEX = 1024


def build(k):
    Oak.NAME, Oak.SEED, Oak.SCALE = NAME, 7, 0.82
    return Oak.build(k)
