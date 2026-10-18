# Mow A Lawn: rules for Claude

A Roblox game built with Rojo, modelled on Chop A Forest with grass instead of trees. Code is in `src/`:
`src/shared` → ReplicatedStorage.MowALawn, `src/server` → ServerScriptService.MowALawn,
`src/client` → StarterPlayer.StarterPlayerScripts.MowALawnClient. The design notes are in `README.md`.
Two people work on it, each with their own Claude sessions. **Losing someone's work is the worst thing that can
happen here.**

## Never lose a teammate's work

1. **Read the TEAM SAFETY CHECK** that the session start hook prints. It lists branches with recent work that
   isn't on your branch. If a file you're about to change is on that list, tell the user and ask whether to
   merge that branch in first. Never quietly build on an old copy.
2. **Never revert, reset or overwrite.** No `git reset --hard`, `git push --force`, `git checkout -- <file>`,
   `git restore`, `git stash drop` or `git clean`. Never copy an older version of a file over a newer one. If
   something has to be undone, use a new commit (`git revert <commit>`) and say what it removes.
3. **Merge, don't replace.** Combine branches with `git merge` and keep both sides' features in a conflict.
   Merging a teammate's branch counts as touching their work: ask the user first.
4. **Edit, don't rewrite.** Change the lines you need; don't regenerate whole files. Before editing a shared file
   (`Config`, `Main.server`, `PlayerData`, `Net`, `Hud`), check `git log -3 -- <file>` for recent work by others.
5. **Rojo overwrites Studio.** Synced scripts replace the ones in Studio. Before telling the user to sync, check
   the branch has everyone's recent work, and tell them to save a backup first (File → Save to File As).
6. **Commit and push often** to the branch you were given. Don't open a pull request unless asked.

## Talking to the user

The user isn't a git expert and works on Windows. Give exact PowerShell commands, explain each in plain words,
and say clearly whether a step can lose anything.

## Game rules (from the owner)

- No cash packs. Licensed audio only. No look-alikes of other games' characters, names or art.
- Any Robux purchase with a random result must show its odds and be hidden where
  `PolicyService.ArePaidRandomItemsRestricted` is true.
- Never spend Robux or publish without asking. The owner saves and publishes.
- Studio tests: the profile gets `_dryRun = true` automatically in Studio, so tests never save.

## Checks before every commit

```bash
lune run tools/compile-check.luau $(find src -name "*.luau")   # syntax + Luau's 200-local limit
rojo build default.project.json -o /tmp/test.rbxlx             # the project builds
```

The session start hook installs `rojo` and `lune` in cloud sessions.

## Code notes

- All tuning lives in `src/shared/Config.luau`. Add content there first; systems read from it.
- Every RemoteEvent is created in `src/server/Net.luau`. The server checks everything; clients only draw.
- The world is built in code at server start (`LobbyBuilder`, `RunBuilder`, `PropKit`), in the studded-brick
  style. Hand-made Studio parts outside `Workspace.World` are left alone.
- One place has two modes: a public server is the **lobby**, a reserved server is a **run**. In Studio, set the
  Workspace attribute `ForceMode` to `Run` (or `Config.STUDIO_MODE`) to test a run.
- Keep functions small: Luau allows at most 200 locals in one function.
