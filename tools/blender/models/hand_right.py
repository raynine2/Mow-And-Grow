"""First-person RIGHT hand: a chunky orange gardening glove (darker padded knuckles) gripping a tool handle, with a
green elastic cuff and a blue-grey shirt sleeve running back toward the camera. The thumb is on the inner side (-X).

ORIGIN = centre of the grip: the tool handle runs straight forward along +Y through the fist. Fist ~1.3 cube around
the origin, cuff y = -0.7 .. -1.1, sleeve 1.05 x 1.05 from y = -1.0 to -3.6. Built by _handkit (mirror: hand_left).
"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import _handkit as hk  # noqa: E402

PREVIEW = dict(dist=7.5, height=4.2, yaw=35)


def build(lib):
    hk.build_hand(lib, "right")
