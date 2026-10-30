#!/usr/bin/env python3
"""Mow And Grow: the weapon skill trees (src/shared/SkillTrees.luau) in the run economy and the tool order.

The trees are bought per run with coins and replace the Upgrades window's "Tool" section (its Power upgrade,
+20% a level, now only powers ride-on mowers as "Mower Blades"). This plays tools/balance_model.py's run with them
in it. Every number is read from SkillTrees.luau (STATS, the coins rows, MAX_FULL_PER_RUN), so it follows what is
tuned there.

    python3 tools/skilltrees_balance.py        the economy (pacing, who fills which tree where) + the tool order
    python3 tools/skilltrees_balance.py -o     the tool order only (fast)

Players: typical (buys pips for its best weapon like the old Power upgrade: keeps ~40% of its coins for the next
tool), dedicated (fills one weapon's tree before buying the next tool) and greedy (fills every tree before moving on,
ignoring the one-full-tree-a-run rule, to show what the rule stops). Only the best weapon learns, as in the game.
"""
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import balance_model as M  # noqa: E402

# git's Config.TOOLS damage (the model's own table has Studio's copy, which differs for the Push Mower and Weed Whacker)
GIT_DMG = dict(Hands=1, Scissors=3, Sickle=12, PushMower=30, WeedWhacker=140, MegaScythe=2500, LaserMower=4000)
STUDIO_DMG = {t['id']: t['dmg'] for t in M.TOOLS}
NATURAL = dict(Scissors=[0], Sickle=[1], PushMower=[2], WeedWhacker=[3, 4], MegaScythe=[5, 6], LaserMower=[7])
BLADES = (0.20, 100, 3.2, 10)  # the old Power upgrade, now "Mower Blades" (ride-on mowers only)


def read_trees():
    src = open(os.path.join(HERE, '..', 'src', 'shared', 'SkillTrees.luau'), encoding='utf-8').read()
    pips = int(re.search(r'SkillTrees\.PIPS\s*=\s*(\d+)', src).group(1))
    full = int(re.search(r'SkillTrees\.MAX_FULL_PER_RUN\s*=\s*(\d+)', src).group(1))
    per = {k: float(v) for k, v in re.findall(r'\n\t(\w+) = \{ per = ([0-9.]+),', src)}
    prices = {k: [int(x) for x in v.replace(' ', '').split(',')] for k, v in re.findall(r'\n\t(\w+) = \{\n\t\ticon = "\w+",\n\t\tcoins = \{ ([0-9, ]+) \}', src)}
    return pips, full, per, prices


PIPS, MAX_FULL, PER, PRICES = read_trees()


def skills_of(t):
    return ['power', 'speed', 'harvest'] if t['kind'] == 'swing' else ['power', 'width', 'harvest']


def tool(tid):
    return next(x for x in M.TOOLS if x['id'] == tid)


# -------------------------------------------------------------------------------------------------------------
# the tool order
# -------------------------------------------------------------------------------------------------------------
def rate(t, zi, base, levels, dmg):
    """clumps/s of tool t with tree `levels` in area zi, for a player of class + pet power `base` (no tree)"""
    t = dict(t)
    z = M.ZONES[zi]
    pw = base + levels.get('power', 0) * PER['power']  # the tree's power is added, like the old upgrade's levels
    d = dmg[t['id']] * pw
    rho, s = M.density(z)
    if t['kind'] == 'swing':
        cd = 1 - levels.get('speed', 0) * PER['speed']
        return M.swing_rate(t, d, z['hp'], cd, 17, rho, s) * M.EFF['swing']
    r, _ = M.auto_rate(t['r'] * (1 + levels.get('width', 0) * PER['width']), d, z['hp'], 17, rho)
    return r * M.EFF['auto']


def maxed(t):
    return {s: PIPS for s in skills_of(t)}


def order(dmg, label):
    powers = [1 + 0.05 * k for k in range(61)]  # class + pets + VIP: 1.0 .. 4.0
    print('\n%s tool damage, in the next tool\'s own areas, worst case over power 1.0-4.0:' % label)
    print('  %-12s %-12s %10s %10s %10s   %s' % ('tool', 'next tool', 'both 0', 'both max', 'max/0', 'next tool catches up with'))
    for i in range(len(M.TOOLS) - 1):
        a, b = M.TOOLS[i], M.TOOLS[i + 1]
        w0 = wm = wx = 0
        catch = 0
        for zi in NATURAL[b['id']]:
            for p in powers:
                rb0 = rate(b, zi, p, {}, dmg)
                if rb0 < 1e-3:
                    continue
                ra0, ram = rate(a, zi, p, {}, dmg), rate(a, zi, p, maxed(a), dmg)
                w0 = max(w0, ra0 / rb0)
                wm = max(wm, ram / rate(b, zi, p, maxed(b), dmg))
                wx = max(wx, ram / rb0)
                # pips the next tool needs (cheapest first, power before the others) to out-cut the maxed one
                lv = {s: 0 for s in skills_of(b)}
                n = 0
                while rate(b, zi, p, lv, dmg) < ram and n < 3 * PIPS:
                    s = min((x for x in skills_of(b) if x != 'harvest' and lv[x] < PIPS), key=lambda x: (lv[x], x != 'power'), default=None)
                    if s is None:
                        n = 99
                        break
                    lv[s] += 1
                    n += 1
                catch = max(catch, n)
        if catch >= 99:
            needs = 'never (with its own tree full)'
        else:
            lv = {s: 0 for s in skills_of(b)}
            coins = 0
            for _ in range(catch):
                s = min((x for x in skills_of(b) if x != 'harvest' and lv[x] < PIPS), key=lambda x: (lv[x], x != 'power'))
                coins += PRICES[b['id']][lv[s]]
                lv[s] += 1
            whole = 3 * sum(PRICES[a['id']])
            needs = '%d pips, %s coins (%.1f%% of the maxed tree\'s %s)' % (catch, f'{coins:,}', 100 * coins / whole, f'{whole:,}')
        print('  %-12s %-12s %9.2fx %9.2fx %9.2fx   %s' % (a['id'], b['id'], w0, wm, wx, needs))


# -------------------------------------------------------------------------------------------------------------
# the run economy
# -------------------------------------------------------------------------------------------------------------
class TreePlayer(M.Player):
    def __init__(self, mode='typical', target=None, **kw):
        self.mode = mode
        self.target = target
        super().__init__(**kw)

    def reset_run(self):
        super().reset_run()
        self.trees = {t['id']: dict(power=0, speed=0, width=0, harvest=0) for t in M.TOOLS}
        self.blade = 0
        self.filled = {}
        self.tree_spent = 0

    def vip(self):
        return 1.15 if 'VIP' in self.passes else 1

    def power(self):  # what mowers use: class + pets + Mower Blades
        return (1 + self.stat('power') + self.blade * BLADES[0]) * self.vip()

    def tool_power(self, tid):
        return (1 + self.stat('power') + self.trees[tid]['power'] * PER['power']) * self.vip()

    def bundle(self):
        return super().bundle() + self.trees[M.TOOLS[self.tool]['id']]['harvest'] * PER['harvest']


def full(p, tid):
    return all(p.trees[tid][s] >= PIPS for s in skills_of(tool(tid)))


def buy_pip(p, tid, ok):
    best = None
    for s in skills_of(tool(tid)):
        lv = p.trees[tid][s]
        if lv < PIPS:
            c = PRICES[tid][lv]
            key = (c, ['power', 'speed', 'width', 'harvest'].index(s))
            if best is None or key < best[0]:
                best = (key, s, c)
    if not best or p.coins < best[2] or not ok(best[2]):
        return False
    if p.trees[tid] and sum(p.trees[tid].values()) + 1 >= 3 * PIPS and p.mode != 'greedy' and len(p.filled) >= MAX_FULL:
        return False  # one full tree a run
    p.coins -= best[2]
    p.trees[tid][best[1]] += 1
    p.tree_spent += best[2]
    if full(p, tid):
        p.filled.setdefault(tid, p.zi)
    return True


def best_rate(p, z):
    t = M.TOOLS[p.tool]
    tr = p.trees[t['id']]
    rho, s = M.density(z)
    pw = p.tool_power(t['id']) * (1.35 if p.cls == 'LawnLegend' else 1)
    if t['kind'] == 'swing':
        swm = p.swingMult() * (1 - tr['speed'] * PER['speed'])
        r = M.swing_rate(t, t['dmg'] * pw, z['hp'], swm, p.walk(), rho, s, rootRip=(p.cls == 'WeedPuller')) * M.EFF['swing']
        k1 = math.ceil(z['hp'] / (t['dmg'] * pw)) <= 1
        if p.cls == 'HedgeReaper':
            r *= 1.6 if k1 else 1.15
        if p.cls == 'Groundskeeper':
            r *= 1.8 if k1 else 1.2
        if p.cls == 'GrassTitan':
            r += (1.0 if math.ceil(z['hp'] / (t['dmg'] * pw)) <= 2 else 0.1) * M.EFF['swing']
    else:
        r, _ = M.auto_rate(t['r'] * (1 + tr['width'] * PER['width']), t['dmg'] * pw, z['hp'], p.walk(), rho)
        r *= M.EFF['auto']
    if p.cls == 'GoatMan':
        r2, _ = M.auto_rate(7, t['dmg'] * pw * M.TICK / M.GIM['graze_every'], z['hp'], p.walk(), rho)
        r += r2 * M.EFF['auto'] * 0.7
    best = (r, t['id'], None)
    if p.mower:
        m = M.MOWERS[p.mower]
        turbo = M.GIM['turbo'] if p.cls == 'MowerSpecialist' else (1, 1, 1)
        rm, _ = M.auto_rate(m['r'] * m.get('swath', 1) * turbo[0], m['dmg'] * p.power(), z['hp'], m['speed'] * turbo[1], rho)
        if rm * M.EFF['mower'] > best[0]:
            best = (rm * M.EFF['mower'], p.mower, m['speed'] * turbo[1])
    return best


def buy_stuff(p):
    while True:
        tid = M.TOOLS[p.tool]['id']
        nxt = M.TOOLS[p.tool + 1]['cost'] if p.tool + 1 < len(M.TOOLS) else 1e18
        holding = p.mode == 'greedy' or (p.mode == 'dedicated' and tid == p.target)
        if holding and not full(p, tid):
            if buy_pip(p, tid, lambda c: True):
                continue
            if p.mode == 'greedy' or len(p.filled) < MAX_FULL:
                return  # save up: the next tool waits for this tree
        if p.tool + 1 < len(M.TOOLS) and p.coins >= nxt:
            p.coins -= nxt
            p.tool += 1
            continue
        if p.bag + 1 < len(M.BAGS) and p.coins >= M.BAGS[p.bag + 1]['cost'] * 1.2:
            p.coins -= M.BAGS[p.bag + 1]['cost']
            p.bag += 1
            continue
        if not p.up['hold'] and p.coins >= 20:
            p.coins -= 20
            p.up['hold'] = 1
            continue
        bought = False
        for mid in ('RustyRider', 'TurboTractor'):
            m = M.MOWERS[mid]
            if p.mower != mid and (p.mower is None or M.MOWERS[p.mower].get('price', 1e18) < m['price']) and M.MOWERS.get(p.mower or '', {}).get('cur') not in ('gems', 'robux') and p.coins >= m['price'] * 1.3 and p.allow_coin_mower:
                p.coins -= m['price']
                p.mower = mid
                p.coins += M.QUEST_MOWER if mid == 'RustyRider' else 0
                bought = True
                break
        if bought:
            continue

        def spare(c):
            return (p.coins - c) >= 0.4 * min(nxt, p.coins) and c < nxt * 0.5
        if buy_pip(p, tid, spare):
            continue
        if p.mower and p.blade < BLADES[3]:
            c = math.floor(BLADES[1] * BLADES[2] ** p.blade)
            if p.coins >= c and spare(c):
                p.coins -= c
                p.blade += 1
                continue
        for k in ('sell', 'speed', 'swing'):
            per, base, growth, mx = M.UPGRADES[k]
            c = math.floor(base * growth ** p.up[k])
            if p.up[k] < mx and p.coins >= c and spare(c):
                p.coins -= c
                p.up[k] += 1
                bought = True
                break
        if not bought:
            return


def run(p, coin_mowers=True):
    p.reset_run()
    p.allow_coin_mower = coin_mowers
    T = 0
    ev, _ = M.mut_ev(p.luck())
    earned = 0
    for zi, z in enumerate(M.ZONES):
        p.zi = zi
        left = z['n'] * z.get('fill', 1)
        tz = 0
        while left > 0.5:
            buy_stuff(p)
            r, how, mv = best_rate(p, z)
            b = z['drops'] * (1 + p.bundle())
            cap = p.carry()
            chunk = min(left, max(1, cap / b))
            tc = chunk / max(r, 1e-6)
            ttrip = 0 if cap >= 9999 else 2 * z['trip'] / (mv or p.walk()) + 2.0
            tz += tc + ttrip
            left -= chunk
            c = chunk * z['value'] * b * ev * p.sell() * (1 + M.CUT_COINS)
            p.coins += c
            earned += c
            if how in M.MOWERS:
                p.coins -= min(p.coins, tc * M.FUEL_PRICE[zi])
        t = M.TOOLS[p.tool]
        cd = t.get('cd', M.TICK) * ((p.swingMult() * (1 - p.trees[t['id']]['speed'] * PER['speed'])) if t['kind'] == 'swing' else 1)
        tboss = max(1 / (1 / M.GUN_FIGHT + M.BOSS_TOOL_SHARE * t['dmg'] * p.tool_power(t['id']) / cd / z['boss']), 45)
        p.coins += z['bcoins']
        earned += z['bcoins']
        T += tz + tboss + 20
    return T / 60, earned


PLAYERS = [
    ('fresh Weed Puller', dict(), True),
    ('Goat Man', dict(cls='GoatMan'), False),
    ('after ~5 runs: Grass Titan, Moles, Zero-Turn', dict(cls='GrassTitan', pets=dict(power=0.45), mower='GoldenZeroTurn'), True),
    ('2x Coins Goat Man', dict(cls='GoatMan', passes=('DoubleCoins',)), False),
    ('whale: + VIP, perks maxed', dict(cls='GoatMan', passes=('DoubleCoins', 'VIP'), perks=dict(sell=5, bundle=5, luck=5, gem=5)), False),
]


def economy():
    print('trees (coins a pip, one skill; x3 skills = the tree):')
    for t in M.TOOLS:
        print('  %-12s %-44s tree %12s' % (t['id'], ', '.join(f'{c:,}' for c in PRICES[t['id']]), f'{3 * sum(PRICES[t["id"]]):,}'))
    print('\n%-46s %8s %8s   %s' % ('typical run, minutes', 'old', 'trees', 'trees filled'))
    for name, kw, cm in M.SCENARIOS + PLAYERS[3:]:
        old = M.run(M.Player(**kw), allow_coin_mower=cm)[0]
        p = TreePlayer(**kw)
        t, _ = run(p, cm)
        print('%-46s %8.1f %8.1f   %s' % (name, old, t, ', '.join(p.filled) or '-'))
    print('\ndedicated: fills one weapon\'s tree before buying the next tool (where it fills, run minutes)')
    for name, kw, cm in PLAYERS[:3]:
        cells = []
        for t in M.TOOLS:
            p = TreePlayer(mode='dedicated', target=t['id'], **kw)
            minutes, _ = run(p, cm)
            at = p.filled.get(t['id'])
            cells.append('%s %s %.0fm' % (t['id'][:6], M.ZONES[at]['name'].split()[0] if at is not None else 'never', minutes))
        print('  %-44s %s' % (name, ' | '.join(cells)))
    print('\ngreedy: every tree before moving on, WITHOUT the one-full-tree-a-run rule (what the rule stops)')
    for name, kw, cm in PLAYERS:
        p = TreePlayer(mode='greedy', **kw)
        minutes, earned = run(p, cm)
        print('  %-44s %5.1f min  %d trees full  (earned %s, on trees %s)' % (name, minutes, len(p.filled), f'{earned:,.0f}', f'{p.tree_spent:,.0f}'))


if __name__ == '__main__':
    print('a pip: ' + ', '.join(f'{k} {v * 100:+.0f}%' for k, v in PER.items()) + f'; {PIPS} pips a skill; {MAX_FULL} full tree(s) a run')
    if '-o' not in sys.argv:
        economy()
    order(GIT_DMG, 'git\'s')
    order(STUDIO_DMG, 'Studio\'s')
