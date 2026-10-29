#!/usr/bin/env python3
"""Mow And Grow: a model of one run's economy (29 Oct, the "balance 2" pass).

Not a replay of the game: it estimates how fast each way of cutting (hand tools, auto tools, ride-on mowers, the
class gimmicks) clears each area, how long the sell trips and the boss fights take, and where the coins come
from, so a change to shared/Config can be judged before a play test. The tables below are the numbers in
shared/Config (Studio's copy) after the pass; OLD holds the ones before it, for the comparison it prints.

    python3 tools/balance_model.py        run times now vs before, per class
    python3 tools/balance_model.py -v     the shopping and the time per area for a fresh run
    python3 tools/balance_model.py -k     clumps per second for every tool and mower in every area

Calibrated loosely: the 29 Oct morning pass aimed at a 25-30 min first run and this model gives 26 for those
numbers. EFF (how well a player sweeps a field) is the knob to re-fit after a timed play test. The clump counts
per area were measured in Studio (RunWorld.patches) before the grass was packed tighter; `fill` multiplies them.
"""
import math, copy, sys

TICK = 0.25
ZONES = [  # name, clumps (measured in Studio), hp, value, drops, spacing, sell-trip distance (studs, one way, avg)
    dict(name='Backyard', fill=1.35, n=96, hp=2, value=3, drops=1, spacing=11, trip=83, boss=150, bcoins=150, bgems=10),
    dict(name='Meadow', fill=1.35, n=106, hp=9, value=12, drops=1, spacing=11.5, trip=152, boss=900, bcoins=500, bgems=15),
    dict(name='Golf', fill=1.35, n=109, hp=40, value=45, drops=1, spacing=12.5, trip=122, boss=5800, bcoins=1500, bgems=20),
    dict(name='Wheat', fill=1.35, n=126, hp=180, value=80, drops=1, spacing=11, trip=120, boss=44000, bcoins=12000, bgems=35),
    dict(name='Blossom', fill=1.35, n=82, hp=1000, value=300, drops=2, spacing=13.5, trip=109, boss=61000, bcoins=40000, bgems=45),
    dict(name='Swamp', fill=1.35, n=74, hp=7000, value=1100, drops=2, spacing=12, trip=140, boss=400000, bcoins=150000, bgems=55),
    dict(name='Prairie', fill=1.35, n=111, hp=30000, value=2400, drops=2, spacing=11.5, trip=163, boss=1600000, bcoins=500000, bgems=65),
    dict(name='Jungle', fill=1.5, n=45, hp=100000, value=12000, drops=4, spacing=21, trip=72, boss=2200000, bcoins=2000000, bgems=80),
]
TOOLS = [
    dict(id='Hands', cost=0, kind='swing', dmg=1, cd=0.45, r=5, t=1),
    dict(id='Scissors', cost=50, kind='swing', dmg=3, cd=0.4, r=6, t=2),
    dict(id='Sickle', cost=600, kind='swing', dmg=12, cd=0.45, r=8, t=4),
    dict(id='PushMower', cost=2500, kind='auto', dmg=38, r=6),
    dict(id='WeedWhacker', cost=14000, kind='auto', dmg=220, r=9),
    dict(id='MegaScythe', cost=300000, kind='swing', dmg=2500, cd=0.5, r=13, t=12),
    dict(id='LaserMower', cost=1600000, kind='auto', dmg=4000, r=11),
]
MOWERS = {
    'RustyRider': dict(cur='coins', price=700, dmg=7, r=6, speed=26, fuel=60),
    'TurboTractor': dict(cur='coins', price=15000, dmg=110, r=8, speed=34, fuel=90),
    'GoldenZeroTurn': dict(cur='gems', price=900, dmg=90, r=8, speed=40, fuel=120, swath=1.3),
    'MonsterMulcher': dict(cur='gems', price=2500, dmg=320, r=9, speed=44, fuel=150),
    'TrialMower': dict(cur='trial', dmg=260, r=9, speed=44, fuel=140),
    'RocketMower': dict(cur='robux', dmg=900, r=10, speed=48, fuel=200),
}
FUEL_PRICE = [2, 4, 10, 30, 90, 250, 700, 2000]
UPGRADES = dict(  # per, base, growth, max
    swing=(0.06, 30, 2.6, 10), grasp=(1.5, 60, 2.5, 10), power=(0.20, 100, 3.2, 10),
    speed=(0.06, 250, 3.0, 10), sell=(0.15, 300, 3.4, 10), hold=(1, 20, 1, 1))
BAGS = [dict(cost=60, carry=15), dict(cost=900, carry=40), dict(cost=6000, carry=90)]
BASE_CARRY = 10
CUT_COINS = 0.25
QUEST_MOWER = 200  # the "Get a ride-on mower" quest's reward
MUTS = [(860, 1, 0), (80, 2, 1), (35, 3, 2), (15, 5, 4), (7, 7, 8), (3, 10, 20)]
CLASSES = {
    'WeedPuller': dict(power=0.05),
    'Gardener': dict(power=0.12, carry=1),
    'Groundskeeper': dict(power=0.18, sell=0.10, carry=2),
    'LawnBaron': dict(power=0.15, sell=0.30, carry=2),
    'HedgeReaper': dict(power=0.30, sell=0.12, luck=0.25, carry=3),
    'MowerSpecialist': dict(power=0.40, speed=0.12, sell=0.15, carry=3),
    'GrassTitan': dict(power=0.65, speed=0.15, sell=0.20, luck=0.25, carry=4),
    'UltimateGardener': dict(power=0.75, speed=0.20, sell=0.30, luck=0.30, carry=5),
    'LawnLegend': dict(power=1.10, speed=0.28, sell=0.55, luck=0.60, carry=7),
    'GoatMan': dict(power=1.5, speed=0.40, sell=0.7, luck=1.0, carry=10),
}
GUN_FIGHT = 90.0  # seconds a boss takes with the free gun (2% of max HP a second, ~70% of shots landing) ...
BOSS_TOOL_SHARE = 0.5  # ... less what your tool adds (tool DPS on the boss, half the time in reach)

# the class gimmicks' numbers (server/ClassPerks)
GIM = dict(rip_every=6, rip_mult=8, courier_cut=0.6, courier_cd=60, graze_every=0.75, turbo=(1.25, 1.15, 0.6))

# how well a player actually sweeps a field (turning, gaps between patches, aiming): calibrated, see calibrate()
EFF = dict(swing=0.6, auto=0.45, mower=0.4)


def density(z):
    # server/RunWorld.patches: a hex grid `spacing` x 0.9 apart (7..13 studs), packed tighter by sqrt(fill)
    s = min(max(z['spacing'] * 0.9, 7), 13) / math.sqrt(z.get('fill', 1))
    return 1 / (0.866 * s * s), s


def mut_ev(luck):
    tot = sum(w * (1 if m == 1 else luck) for w, m, g in MUTS)
    ev = sum(w * (1 if m == 1 else luck) * m for w, m, g in MUTS) / tot
    gems = sum(w * (1 if m == 1 else luck) * g for w, m, g in MUTS) / tot
    return ev, gems


def auto_rate(R, D, hp, vmax, rho):
    """clumps/s for something that hits everything within R every tick while moving through the field"""
    k = max(1, math.ceil(hp / max(D, 1e-9)))
    c = 0.125 * k * 1.15  # (dwell must cover k ticks; +15% for the tick phase)
    vstar = R / (c * math.sqrt(2))
    v = min(vmax, vstar)
    width = 2 * math.sqrt(max(R * R - (c * v) ** 2, 0))
    return width * v * rho, v


def swing_rate(tool, D, hp, swingMult, walk, rho, spacing, rootRip=False):
    k = max(1, math.ceil(hp / max(D, 1e-9)))
    reach = tool['r']
    near = 1 + 0.386 * math.pi * reach * reach * rho * 1.3
    T = min(tool['t'], near)
    ts = tool['cd'] * swingMult
    if rootRip and k > 1:  # every Nth landed swing kills everything it hits (or hits rip_mult x as hard)
        n = GIM['rip_every']
        if GIM['rip_mult'] is None or k <= GIM['rip_mult']:
            k = n / ((n - 1) / k + 1)  # the rip finishes the group it lands on
        else:
            k = k * n / (n - 1 + GIM['rip_mult'])  # n swings deal (n - 1) + rip_mult hits' worth
    per = k * ts + spacing / walk
    return T / per


class Player:
    def __init__(self, cls='WeedPuller', pets=None, perks=None, mower=None, passes=(), gems=0):
        self.cls = cls
        self.c = CLASSES[cls]
        self.pet = pets or {}
        self.perks = perks or dict(sell=0, bundle=0, luck=0, gem=0)
        self.owned_mower = mower  # a gem/robux mower owned forever
        self.passes = set(passes)
        self.reset_run()

    def reset_run(self):
        self.coins = 0
        self.tool = 0
        self.up = {k: 0 for k in UPGRADES}
        self.bag = -1
        self.vacuum = False
        self.mower = self.owned_mower
        self.gems = 0
        self.spent = {}

    def stat(self, k):
        return self.c.get(k, 0) + self.pet.get(k, 0)

    def power(self):
        return (1 + self.stat('power') + self.up['power'] * 0.2) * (1.15 if 'VIP' in self.passes else 1)

    def sell(self):
        s = 1 + self.stat('sell') + self.perks['sell'] * 0.1 + self.up['sell'] * 0.15
        return s * (2 if 'DoubleCoins' in self.passes else 1) * (1.15 if 'VIP' in self.passes else 1)

    def luck(self):
        return 1 + self.stat('luck') + self.perks['luck'] * 0.2

    def walk(self):
        return 16 * (1 + self.stat('speed') + self.up['speed'] * 0.06)

    def swingMult(self):
        return max(0.4, 1 - self.up['swing'] * 0.06)

    def carry(self):
        if 'BigBag' in self.passes:
            return 9999
        return BASE_CARRY + self.c.get('carry', 0) + (BAGS[self.bag]['carry'] if self.bag >= 0 else 0)

    def bundle(self):
        return self.perks['bundle'] * 0.1 + (1 if 'DoubleClippings' in self.passes else 0)


def best_rate(p, z, zi):
    """the fastest way this player can cut zone zi right now: (clumps/s, how, mower speed if driving)"""
    rho, s = density(z)
    best = (0, None, None)
    pw = p.power()
    if p.cls == 'LawnLegend':
        pw *= 1.35  # Hot Streak, averaged
    t = TOOLS[p.tool]
    if t['kind'] == 'swing':
        r = swing_rate(t, t['dmg'] * pw, z['hp'], p.swingMult(), p.walk(), rho, s, rootRip=(p.cls == 'WeedPuller')) * EFF['swing']
        k1 = math.ceil(z['hp'] / (t['dmg'] * pw)) <= 1
        if p.cls == 'HedgeReaper':  # Reap Wave: every 8th swing hits all within 14 studs
            r *= 1.6 if k1 else 1.15
        if p.cls == 'Groundskeeper':  # Tidy Up: a fall hits the 2 nearest (kills them too on one-hit grass)
            r *= 1.8 if k1 else 1.2
        if p.cls == 'GrassTitan':  # Titan Stomp: 2 hits within 12 studs every ~4 s
            r += (1.0 if math.ceil(z['hp'] / (t['dmg'] * pw)) <= 2 else 0.1) * EFF['swing']
        best = max(best, (r, t['id'], None), key=lambda x: x[0])
    else:
        r, v = auto_rate(t['r'], t['dmg'] * pw, z['hp'], p.walk(), rho)
        best = max(best, (r * EFF['auto'], t['id'], None), key=lambda x: x[0])
    if p.cls == 'GoatMan':  # Graze: the best tool's hit every 0.5 s within 7 studs while walking
        r2, v = auto_rate(7, t['dmg'] * pw * TICK / GIM['graze_every'], z['hp'], p.walk(), rho)
        best = (best[0] + r2 * EFF['auto'] * 0.7, best[1] + '+graze', None)
    if p.mower:
        m = MOWERS[p.mower]
        turbo = GIM['turbo'] if p.cls == 'MowerSpecialist' else (1, 1, 1)
        R = m['r'] * m.get('swath', 1) * turbo[0]
        vmax = m['speed'] * turbo[1]
        r, v = auto_rate(R, m['dmg'] * pw, z['hp'], vmax, rho)
        if r * EFF['mower'] > best[0]:
            best = (r * EFF['mower'], p.mower, vmax)
    return best


def buy_stuff(p, zi, log):
    """greedy shopping between areas and mid-area: next tool when affordable, bag, mower, then power/sell upgrades"""
    bought = True
    while bought:
        bought = False
        # the next tool
        if p.tool + 1 < len(TOOLS) and p.coins >= TOOLS[p.tool + 1]['cost']:
            p.coins -= TOOLS[p.tool + 1]['cost']
            p.tool += 1
            log.append(f'  buy {TOOLS[p.tool]["id"]}')
            bought = True
            continue
        if p.bag + 1 < len(BAGS) and p.coins >= BAGS[p.bag + 1]['cost'] * 1.2:
            p.coins -= BAGS[p.bag + 1]['cost']
            p.bag += 1
            log.append(f'  buy bag {p.bag + 1}')
            bought = True
            continue
        if not p.up['hold'] and p.coins >= 20:
            p.coins -= 20
            p.up['hold'] = 1
            bought = True
            continue
        # coin mowers when they beat what we have
        for mid in ('RustyRider', 'TurboTractor'):
            m = MOWERS[mid]
            if p.mower != mid and (p.mower is None or MOWERS[p.mower].get('price', 1e18) < m['price']) and MOWERS.get(p.mower or '', {}).get('cur') not in ('gems', 'robux') and p.coins >= m['price'] * 1.3 and p.allow_coin_mower:
                p.coins -= m['price']
                p.mower = mid
                p.coins += QUEST_MOWER if mid == 'RustyRider' else 0  # the "Get a ride-on mower" quest
                log.append(f'  buy {mid}')
                bought = True
                break
        if bought:
            continue
        # upgrades: keep ~40% of coins for the next tool
        nxt = TOOLS[p.tool + 1]['cost'] if p.tool + 1 < len(TOOLS) else 1e18
        for k in ('power', 'sell', 'speed', 'swing'):
            per, base, growth, mx = UPGRADES[k]
            lv = p.up[k]
            if lv >= mx:
                continue
            cost = math.floor(base * growth ** lv)
            if p.coins - cost >= 0 and (p.coins - cost) >= 0.4 * min(nxt, p.coins) and cost < nxt * 0.5:
                p.coins -= cost
                p.up[k] += 1
                bought = True
                break


def run(p, verbose=False, allow_coin_mower=True, zones=None):
    zones = zones or ZONES
    p.reset_run()
    p.allow_coin_mower = allow_coin_mower
    log = []
    T = 0
    ev, gemPer = mut_ev(p.luck())
    for zi, z in enumerate(zones):
        n = z['n'] * z.get('fill', 1) * z.get('nmult', 1)
        left = n
        tz = 0
        trips = 0
        while left > 0.5:
            buy_stuff(p, zi, log)
            rate, how, mv = best_rate(p, z, zi)
            # cut a bag's worth (bag + 60 on the ground, but you can only sell what you carry: each trip = a bag)
            b = z['drops'] * (1 + p.bundle())
            cap = p.carry()
            chunk = min(left, max(1, cap / b))
            tcut = chunk / rate
            # the trip to the drop-off and back (on the mower if you're driving one)
            v = mv or p.walk()
            ttrip = 0 if cap >= 9999 else 2 * z['trip'] / v + 2.0
            courier = 0
            if p.cls == 'LawnBaron' and cap < 9999:
                # Courier: a full bag sells itself (80%) every 45 s; a trip only for the bags filled faster than that
                courier = min(1, tcut / GIM['courier_cd'])
                ttrip *= 1 - courier
            tz += tcut + ttrip
            trips += 1
            left -= chunk
            coins = chunk * z['value'] * b * ev * p.sell() * (1 + CUT_COINS - (1 - GIM['courier_cut']) * courier)
            p.coins += coins
            if how in MOWERS:
                p.coins -= min(p.coins, tcut * FUEL_PRICE[zi] * (GIM['turbo'][2] if p.cls == 'MowerSpecialist' else 1))
            p.gems += chunk * (gemPer + 0.07)
        # the boss: the gun does most of it; your tool shortens it
        t = TOOLS[p.tool]
        dps = t['dmg'] * p.power() * (1 / (t.get('cd', TICK) * (p.swingMult() if t['kind'] == 'swing' else 1)))
        tboss = 1 / (1 / GUN_FIGHT + BOSS_TOOL_SHARE * dps / z['boss'])
        tboss = max(tboss, 45)
        p.coins += z['bcoins']
        p.gems += z['bgems']
        T += tz + tboss + 20  # (+20 s: walking to the next area, the gate, the shop)
        if verbose:
            log.append(f"{zi+1} {z['name']:9s} {tz/60:5.1f} min cutting ({trips:3d} bags, {how}) + boss {tboss:4.0f}s | tool {TOOLS[p.tool]['id']:11s} pow {p.power():4.2f} coins {p.coins:12,.0f}")
    if verbose:
        print('\n'.join(log))
    return T / 60, p


def kill_table(power=1.0, walk=16, fills=None):
    print('clumps/s at power %.1f (walk %d), before efficiency:' % (power, walk))
    names = [t['id'] for t in TOOLS] + list(MOWERS)
    print('%-15s' % '' + ''.join('%9s' % z['name'][:8] for z in ZONES))
    for t in TOOLS:
        row = []
        for z in ZONES:
            rho, s = density(z)
            if t['kind'] == 'swing':
                r = swing_rate(t, t['dmg'] * power, z['hp'], 1, walk, rho, s)
            else:
                r, v = auto_rate(t['r'], t['dmg'] * power, z['hp'], walk, rho)
            row.append(r)
        print('%-15s' % t['id'] + ''.join('%9.2f' % r for r in row))
    for mid, m in MOWERS.items():
        row = []
        for z in ZONES:
            rho, s = density(z)
            r, v = auto_rate(m['r'] * m.get('swath', 1), m['dmg'] * power, z['hp'], m['speed'], rho)
            row.append(r)
        print('%-15s' % mid + ''.join('%9.2f' % r for r in row))


# the numbers before the pass (Studio's Config at 87923 bytes, 29 Oct ~16:30), for the comparison
OLD = dict(
    zones={'Backyard': dict(fill=1, hp=2, bcoins=150), 'Meadow': dict(fill=1, hp=6, bcoins=600), 'Golf': dict(fill=1, hp=25, bcoins=2000),
           'Wheat': dict(fill=1, hp=130, bcoins=25000), 'Blossom': dict(fill=1, hp=750, bcoins=80000), 'Swamp': dict(fill=1, hp=2300, bcoins=300000),
           'Prairie': dict(fill=1, hp=12000, bcoins=1000000), 'Jungle': dict(fill=1, hp=50000, bcoins=4000000)},
    tools={'Sickle': 500, 'PushMower': 1800, 'WeedWhacker': 4700, 'MegaScythe': 78000, 'LaserMower': 240000},
    mowers={'RustyRider': dict(price=350, dmg=6, r=6, speed=30), 'TurboTractor': dict(price=40000, dmg=120, r=9, speed=38),
            'GoldenZeroTurn': dict(dmg=400, r=10, speed=42), 'MonsterMulcher': dict(dmg=3000, r=12, speed=46),
            'TrialMower': dict(dmg=800, r=11), 'RocketMower': dict(dmg=2000, r=12, speed=50)},
    gim=dict(rip_mult=None, courier_cut=0.8, courier_cd=45, graze_every=0.5, turbo=(1.4, 1.2, 0.5)),
    quest_mower=500,
)

SCENARIOS = [
    ('fresh Weed Puller', dict(), True),
    ('+ Golden Zero-Turn (900 gems)', dict(mower='GoldenZeroTurn'), True),
    ('+ Monster Mulcher (2500 gems)', dict(mower='MonsterMulcher'), True),
    ('+ Rocket Mower (Robux)', dict(mower='RocketMower'), True),
    ('Mower Specialist + Monster Mulcher', dict(cls='MowerSpecialist', mower='MonsterMulcher'), True),
    ('Lawn Baron', dict(cls='LawnBaron'), False),
    ('Goat Man', dict(cls='GoatMan'), False),
    ('Goat Man, 3 Golden Gnomes, Monster Mulcher', dict(cls='GoatMan', pets=dict(power=1.5, speed=0.45), mower='MonsterMulcher'), True),
    ('after ~5 runs: Grass Titan, 3 Moles, Zero-Turn', dict(cls='GrassTitan', pets=dict(power=0.45), mower='GoldenZeroTurn'), True),
]


def use_old():
    """switch the tables to the numbers before the pass"""
    global QUEST_MOWER
    for z in ZONES:
        z.update(OLD['zones'][z['name']])
    for t in TOOLS:
        if t['id'] in OLD['tools']:
            t['cost'] = OLD['tools'][t['id']]
    for mid, d in OLD['mowers'].items():
        MOWERS[mid].update(d)
    GIM.update(OLD['gim'])
    QUEST_MOWER = OLD['quest_mower']


def table():
    import copy
    keep = copy.deepcopy((ZONES, TOOLS, MOWERS, GIM))
    rows = {}
    for label in ('new', 'old'):
        if label == 'old':
            use_old()
        for name, kw, coinMowers in SCENARIOS:
            rows.setdefault(name, {})[label] = run(Player(**kw), allow_coin_mower=coinMowers)[0]
        for c in CLASSES:
            rows.setdefault('class ' + c, {})[label] = run(Player(cls=c), allow_coin_mower=False)[0]
    ZONES[:], TOOLS[:] = keep[0], keep[1]
    MOWERS.clear(); MOWERS.update(keep[2]); GIM.clear(); GIM.update(keep[3])
    print('%-48s %8s %8s' % ('run time, minutes (model)', 'before', 'now'))
    for name, r in rows.items():
        print('%-48s %8.1f %8.1f' % (name, r['old'], r['new']))


if __name__ == '__main__':
    if '-k' in sys.argv:
        kill_table(power=1.6, walk=17)
    elif '-v' in sys.argv:
        run(Player(), verbose=True)
    else:
        table()
