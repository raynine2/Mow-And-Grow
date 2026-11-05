# Films v2: the opening and the finale (5 Nov 2026)

The owner scrapped the old opening (`client/Intro`) and ending (`client/Ending`) and asked for new ones built from
scratch, "like an anime fight, Sukuna vs Mahoraga", with the end boss arriving "like Toji in the domain", the Mayor
replaced by his own avatar (RayanPoepHoof) as the town's owner, and a cool moment for the player. The old films stay
in the code: `Config.FILMS_V2 = false` brings them back.

References the owner sent (all by the Roblox animator Ultik): the Anime Vanguards "Sukuna Raid Intro" (most
important), "Unlimited Flexworks" (TSB) and his Blue Lock cutscenes. Measured breakdown and research:
`reports/Anime cutscene craft for Roblox.md` (outside the repo) and the notes below.

## Owner's answers (5 Nov)
- Story: build it (below). Rayan's card: "RAYAN — Owner of the Valley". The player's hero move: the bare fist.
- End boss: the player's own dark copy ("a fight against yourself").
- Lengths: opening ~45 s, finale ~60 s. Skippable. Subtitles in [brackets], no voices.
- Title at the end of the opening: the loading screen's MOW A LAWN logo, slammed in on the beat.

## Rules taken from the references
- Letterbox. Night palettes with one hot accent per beat (white cuts = Rayan, gold/orange = the player, magenta = glitch).
- Shots 0.2–1.0 s in the exchanges; 1.5–2 s holds only for menace, resets and aftermaths.
- Impact frames 1–2 frames (~0.05–0.1 s per state) on the hit; a 3–5 state strobe only for the 2–3 biggest hits.
- Silence before the biggest hits (music out 0.5–1 s, a thin wind bed stays). Cut on every sharp sound in the walk-outs.
- Escalation ladder (the giant fight): hit → enemy regrows and adapts (the "reset tell": its cut pieces fly back with a
  pink flicker and their own sound) → the old attack fails → bigger attack → it adapts again → a NEW category of
  attack finishes it (white cuts → the player's gold fist).
- Entrance ladder (the finale): calm → cue (music fades) → breach (the door the heroes made) → partial reveal (feet,
  silhouette) → reaction → failed read → proof on the strongest thing ("bigger fish") → bare name card.
- Never JJK names, designs or music; never a "domain": Rayan's is a "realm", the demon's tears are "tears".

## THE OPENING "First Cut" (~45 s)
Set: a moonlit meadow outside the town, built locally far from the map (client/FilmSet): wild grass, fences, a shed,
lanterns, oaks, the town and the windmill on the horizon, pink cracks in the sky.
| t | Shot |
|---|---|
| 0–4 | Wide, low in the grass: the valley at night, the sky cracking pink. The ground splits; the Glitch Demon heaves up. |
| 4–8 | Feet: Rayan walks in, the giant gold shears dragging a spark. Behind him, small before the colossus: card RAYAN — Owner of the Valley. [You're on my lawn.] Demon roar. |
| 8–12 | Exchange: a claw slams down, Rayan is gone; three snips from three angles (white cut wedges), the demon's arm falls off. |
| 12–14 | RESET TELL: the pieces stop in the air, fly back, snap on with a pink flicker. [...It grows back.] |
| 14–17 | Snip again — CLANG, it has adapted; slow-mo backhand, impact frame, Rayan flies through the shed. |
| 17–24 | Rayan gets up, cracks his neck. [Fine. Let's mow.] Music out. A gold ring on the ground. SNIP: white-out, everything in the circle cut at one height, a beat later it all slides apart; the demon's top half falls. It regrows BIGGER. |
| 24–31 | Its fists come down on Rayan → BLACK, silence, a heartbeat → a streak from the sky: the player lands between them (crater). Close: the player's eyes; fist back (hold). PUNCH: gold strobe impact frames, the fists burst. |
| 31–37 | The demon shatters from the core; pink shards streak to the 8 lands (pink pillars on the horizon). Its last eye hovers before the player, studies them, zips away. |
| 37–45 | Rayan: [Not bad, rookie.] [It's in the guardians now.] [Free them. Mow it ALL.] TITLE: the logo slams in on the beat. |

## THE FINALE "You" (~60 s)
| t | Shot |
|---|---|
| 0–10 | Sunrise over the meadow, the guardians free. The player walks out of the gold dust, a hard cut on every beat. Rayan: [Every last blade.] |
| 10–22 | A last pink shard twitches. [One left.] Rayan opens his realm: white-out → an endless gold lawn under a gold sky, the eight guardians in a ring. [Nowhere to run.] The shard rips a tear in the realm's sky to escape; the music fades. |
| 22–38 | Nothing comes out. A footstep from inside. A foot steps onto the gold, pink pixels ripple out. The player's DARK COPY walks in, backlit, calm (cut on each step, mirroring the player's walk). The player's face. The copy's face: the player's own, black, magenta eyes. Rayan: [There's no glitch in it.] [It's just... you?] |
| 38–50 | Rayan attacks — the copy catches the blade bare-handed, takes the shears, one snip: the realm's sky breaks like glass, the strongest guardian falls, Rayan thrown back. |
| 50–60 | The copy turns to the camera: [Thanks for the lesson.] Card: YOU. → THE FINAL FIGHT — COMING SOON. |

## Build
- `client/Puppet`: R15 actors driven by code (anchored parts, forward kinematics from the joints' attachments, pose
  keyframes, FaceControls). Works with Motor6D and AnimationConstraint rigs; no animation assets.
- `client/AnimeUi`: subtitles, name card, logo slam, boss card, slash wedges, speed lines, impact strobes.
- `client/FilmSet`: the night meadow and the gold realm.
- `client/Opening`, `client/Finale`: the films. `Config.FILMS_V2` routes `Intro`/`Ending` to them.
- Server `FilmCast`: builds the owner's avatar (Config.OWNER.userId) into `ReplicatedStorage.FilmCast`.
