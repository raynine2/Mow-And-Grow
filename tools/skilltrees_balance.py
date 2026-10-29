#!/usr/bin/env python3
"""Mow And Grow: does a maxed weapon skill tree (shared/SkillTrees) keep the tool order?

For every pair of tools in shop order it compares the cutting rate (clumps a second, tools/balance_model.py) of the
first tool with its whole tree maxed against the next tool with no skills, in the areas the next tool is made for,
at every player power from 1.0 to 4.0. A ratio over 1 means the maxed tool out-cuts the next one there. The skills'
numbers are read from src/shared/SkillTrees.luau (STATS), so this follows whatever is tuned there.

    python3 tools/skilltrees_balance.py
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import balance_model as M  # noqa: E402

# git's Config.TOOLS damage (the model's own table has Studio's copy, which differs for the Push Mower and Weed Whacker)
GIT_DMG = dict(Hands=1, Scissors=3, Sickle=12, PushMower=30, WeedWhacker=140, MegaScythe=2500, LaserMower=4000)
STUDIO_DMG = {t['id']: t['dmg'] for t in M.TOOLS}
# the areas (indexes into M.ZONES) each tool is made for
NATURAL = dict(Scissors=[0], Sickle=[1], PushMower=[2], WeedWhacker=[3, 4], MegaScythe=[5, 6], LaserMower=[7])


def read_stats():
    src = open(os.path.join(HERE, '..', 'src', 'shared', 'SkillTrees.luau'), encoding='utf-8').read()
    pips = int(re.search(r'SkillTrees\.PIPS\s*=\s*(\d+)', src).group(1))
    per = {k: float(v) for k, v in re.findall(r'\n\t(\w+) = \{ per = ([0-9.]+),', src)}
    return {k: v * pips for k, v in per.items()}


def rate(t, zi, power, caps, dmg, maxed):
    t = dict(t)
    z = M.ZONES[zi]
    t['dmg'] = dmg[t['id']]
    if maxed:
        t['dmg'] *= 1 + caps.get('power', 0)
        if t['kind'] == 'swing':
            t['cd'] *= 1 - caps.get('speed', 0)
        else:
            t['r'] *= 1 + caps.get('width', 0)
    rho, s = M.density(z)
    if t['kind'] == 'swing':
        return M.swing_rate(t, t['dmg'] * power, z['hp'], 1, 17, rho, s) * M.EFF['swing']
    r, _ = M.auto_rate(t['r'], t['dmg'] * power, z['hp'], 17, rho)
    return r * M.EFF['auto']


def main():
    caps = read_stats()
    print('maxed tree:', ', '.join('%s %+.0f%%' % (k, v * 100 * (-1 if k == 'speed' else 1)) for k, v in caps.items()))
    powers = [1 + 0.05 * k for k in range(61)]
    for label, dmg in (('git', GIT_DMG), ('Studio', STUDIO_DMG)):
        print('\n%s tool damage: maxed tool / plain next tool, worst case in the next tool\'s areas' % label)
        for i in range(len(M.TOOLS) - 1):
            a, b = M.TOOLS[i], M.TOOLS[i + 1]
            worst, worst0, beat, beat0, n = 0, 0, 0, 0, 0
            for zi in NATURAL[b['id']]:
                for pw in powers:
                    rb = rate(b, zi, pw, caps, dmg, False)
                    if rb < 1e-3:
                        continue
                    n += 1
                    ra = rate(a, zi, pw, caps, dmg, True) / rb
                    r0 = rate(a, zi, pw, caps, dmg, False) / rb
                    worst, worst0 = max(worst, ra), max(worst0, r0)
                    beat += ra > 1.0001
                    beat0 += r0 > 1.0001
            print('  %-12s vs %-12s %5.2fx (ahead at %3d%% of powers)   no skills: %5.2fx (%3d%%)' % (
                a['id'], b['id'], worst, 100 * beat / max(n, 1), worst0, 100 * beat0 / max(n, 1)))


if __name__ == '__main__':
    main()
