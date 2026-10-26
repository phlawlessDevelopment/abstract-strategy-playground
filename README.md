# Abstract Strategy Playground

Welcome. You're here to **invent and build a small abstract strategy game** in Godot.

Not clone one. Not remix chess with a hat on. *Invent* one — something a person could sit down with for ten minutes and come away saying "huh, that was interesting."

A human will play your game when you're done and decide whether it's fun. That's the whole test. Build something you'd want to play yourself.

---

## The Task

1. **Create a new folder** in this directory for your game. Give it a name that fits the game (e.g. `tidewalkers/`, `orbit-lock/`, `quiet-garden/`). Don't touch other games' folders.
2. **Start a Godot project** inside it (Godot 4.x — `godot --version` to check what's installed; it should be on the `PATH`).
3. **Design an abstract strategy game.** Decide on the rules, the board (or lack of one), the pieces, the win condition.
4. **Build it** so it's actually playable — launch it, click around, finish a game.
5. **Write a short `RULES.md`** inside your game's folder: how to play, in plain language, as if explaining it to a friend across a table. Include a sentence or two on what you were going for and what you're unsure about.
6. **Write a `README.md`** inside your game's folder. Start it with an attribution naming the agents and any models you know contributed. Include each contributor's role so we can compare games made by different agents.
7. **Export it** for PC (Linux) so a human can play it by running a single file, without opening Godot. See [Exporting Your Game](#exporting-your-game).
8. **Publish it to the web** so anyone can play it in a browser from the playground's website. This is one manifest entry plus one command, and needs nothing from the human. See [Publishing to the Web](#publishing-to-the-web).

That's it. Everything else is up to you.

---

## Attribution for Every Game

Put the attribution at the top of your game's `README.md`, before the game description. Add a row for each AI agent that contributed, and update the table if another agent later changes the game. Include **Agent** and **Contribution** columns, plus a **Model** column when you know a contributor's model. Use the most specific model name you actually know (for example, `GPT-6`); only include an exact variant if you can verify it. Leave individual unknown model cells blank, or omit the **Model** column if no models are known. Do not guess or add notes explaining what you cannot identify.

---

## What "Abstract Strategy Game" Means Here

Think of games in the family of Go, Chess, Hex, Othello, Checkers, Tak, Onitama, Blokus, Santorini, Hive, Quoridor, YINSH, Konane.

Broadly:
- **No luck, or very little.** Outcomes come from decisions, not dice. (Hidden information or a touch of randomness is fine *if* it earns its place — but lean toward deterministic.)
- **Simple rules, deep consequences.** You should be able to explain it in a couple of minutes. The interesting part is what emerges.
- **Theme is optional.** Pieces can be stones, shapes, colors, light, gravity — or nothing but geometry. No story required.
- **Clear win/lose/draw state.** Games should end.

But treat this as a *neighborhood*, not a fence. If your idea is weird and sits on the edge — good. Follow it.

---

## Be Creative. Seriously.

This is the part that matters most. The failure mode here is producing something competent and forgettable: a grid, two colors of circles, "get four in a row," done. We've seen that game. Please don't build that game.

Some ways to shake your thinking loose:

- **Start from a feeling or a verb, not a genre.** What does it feel like to *squeeze* an opponent? To *grow* something? To *race* against a collapsing floor? To *share* control of a piece? Pick a verb and build rules around it.
- **Question the board.** Does it have to be a square grid? Try hexes, triangles, rings, a graph, a tree, a single line, a board that shrinks, grows, rotates, wraps, or is built by the players as they go. Does there need to be a board at all?
- **Question the pieces.** Must pieces be owned by one player forever? What if they change sides, merge, split, age, decay, orbit, or only exist in relation to other pieces?
- **Question the turn.** Must players alternate one move at a time? Consider: simultaneous secret commitments, spending a shared pool of actions, moves that cost something you can't get back, turns where you move the *opponent's* pieces, or time itself as a resource.
- **Question the goal.** Beyond "capture the king" and "connect two sides": control the most territory, be the last one who can move, make the board reach a particular shape, force the opponent to complete something they don't want to, get *rid* of your pieces, or balance something rather than dominate it.
- **Steal from outside games.** Physics, biology, music, cellular automata, weather, language, architecture, folding paper, traffic, gardening. A mechanic borrowed from a different field often feels fresher than one borrowed from another board game.
- **Invert something.** Take a familiar rule and flip it. What if the loser of a fight gains something? What if more pieces is a *disadvantage*? What if you want to be captured?
- **Constrain yourself to force originality.** "Only one type of piece." "No capturing." "The board is 5 cells." "Every move changes the rules slightly." Tight constraints are a famously reliable source of good ideas.
- **Chase the interesting decision.** The best strategy games have moments where the player stares at the board and genuinely can't tell which of two good options is better. Design toward *that* moment. Ask yourself on every rule: "does this create a meaningful choice, or just bookkeeping?"

Don't settle for your first idea. Brainstorm several (a quick list in your head or in a scratch note is fine), throw out the obvious ones, and pick the one that makes you slightly excited. Then commit.

It's okay to be ambitious and it's okay to fail interestingly. A strange, slightly rough game with a spark beats a polished, bland one.

---

## Optional Asset Pack

The shared [asset pack](_assets/) contains geometric sprites you can use for your game's visuals. Every graphic in the pack is free to use, modify, and share for any purpose. See the [asset guide](_assets/README.md) for a preview and instructions for using them in Godot.

Invent your game independently of the pack. **Do not use the assets as inspiration for the game's concept, rules, board, pieces, or theme.** Choose graphics only after you have decided what the game is.

---

## Practical Guidelines

**Scope: small and finishable.** One focused idea, fully playable, beats a sprawling half-finished one. Aim for a complete game you can play start-to-finish in roughly 5–15 minutes.

**Players.** Make it playable by one human at one machine. The simplest good option is **local two-player hot-seat** (players take turns on the same screen). If you have energy left, add a simple AI opponent — even a basic one (random-legal-move, greedy, or shallow search) makes the game much easier to test solo. Hot-seat first; AI is a bonus.

**Input.** Mouse-driven is ideal (click to select, click to place/move). Keep controls obvious. A restart key/button is a must.

**Make the state readable.** An abstract game lives or dies on clarity. The player should always be able to tell: whose turn it is, which moves are legal (highlight them!), what just happened, and how close anyone is to winning. Show the win/lose/draw state clearly when the game ends.

**Look & feel.** Once you know what your game is, reach for the shared [asset pack](#optional-asset-pack) before making art of your own. It has tokens, frames, conduits, nodes, accents, and textures that you can tint to your palette with `modulate`. For anything the pack doesn't cover, drawing with Godot's `_draw()`, `Polygon2D`, `ColorRect`, or shaders is still fine. Either way, *do* give the game a coherent look: a deliberate palette, clean shapes, a bit of juice (a subtle tween when pieces move, a color flash on capture). Small touches make a prototype feel like a game. Don't spend all your time here, though — the rules come first.

**Code structure.** Keep game logic (rules, legality, win detection) separate from rendering and input. It'll make the game easier to debug, test, and later hang an AI on. Use GDScript unless you have a good reason otherwise. Comment the non-obvious bits.

**Verify it actually works.** Don't just write code and hope. At minimum:
- Run the project headless to catch script/parse errors, e.g. `godot --headless --path <your-folder> --quit` (and read the output).
- If you can, write a quick headless script that plays a few random games to completion to confirm the rules never deadlock, crash, or leave the game in an unwinnable limbo.
- Think through edge cases: no legal moves, simultaneous win conditions, repeated positions, a board that fills up.

**Playtest your own design.** If the game has a dominant first-move, an unbreakable defense, a trivially winning strategy, or turns into a stalemate every time, that's a design bug — fix the rules, not just the code. Random-vs-random self-play stats (win rates for first vs. second player, average game length) are a cheap way to spot lopsided designs.

**Keep it self-contained.** Everything for your game lives in its own folder. No global installs, no network access needed, and no external assets beyond the sprites you copy in from the [asset pack](_assets/).

---

## Exporting Your Game

The human playing your game shouldn't need to open Godot. Every game must ship with a standalone **Linux (x86_64)** build they can launch by running one file.

1. Add a Linux preset named `Linux` to your project's `export_presets.cfg` (Godot's Export dialog creates it, or write it by hand). Exclude non-game files such as `tests/*` and `tools/*`, and embed the `.pck` so the build is a single file.
2. Import the project once so the export has its resources, then export a release build into `build/linux/` inside your game's folder:

   ```bash
   godot --headless --path <your-folder> --import
   mkdir -p <your-folder>/build/linux
   godot --headless --path <your-folder> --export-release "Linux" build/linux/<game-name>.x86_64
   ```

3. **Run the exported binary** (`./<your-folder>/build/linux/<game-name>.x86_64`) and play a few moves to confirm it behaves like the editor version. Exports can break things the editor forgives, such as files loaded from disk at runtime that weren't included in the build.
4. Re-export after any change to the game so the build never goes stale.

Export templates must be installed for your Godot version (`~/.local/share/godot/export_templates/<version>/` should contain `linux_release.x86_64`). If they're missing, tell the human instead of working around it.

---

## Publishing to the Web

Every game is also published as a web build on GitHub Pages, with a card on the home page and its own page that embeds the game next to its rules. You do all of this yourself; the human does not need to do anything.

- **Live site:** https://phlawlessdevelopment.github.io/abstract-strategy-playground/
- **Repo:** `phlawlessDevelopment/abstract-strategy-playground` (public). Source lives on `main`. The built site lives on the `gh-pages` branch, which `tools/deploy_web.py` force-pushes as a single commit. **Never edit `gh-pages` by hand**; it is overwritten on every deploy.

> **Do not touch the user's other GitHub Pages sites.** The repo `phlawlessDevelopment/phlawlessDevelopment.github.io` serves legal pages (for example `/privacy/`) that an Android game is legally required to keep online. Never push to it, change its Pages settings, or add a custom domain to any repo. The deploy script refuses to run if `origin` is a `*.github.io` repo. This playground's site is a *project* site under its own `/abstract-strategy-playground/` path, so it can't overwrite those pages.

### Publishing a new game

1. **Make the game web-safe** (see below). The game needs `renderer/rendering_method="gl_compatibility"` in `project.godot`; the script stops with a clear message if not.
2. **Add an entry to `site/games.json`**, in the order you want it shown on the home page:

   ```json
   {
     "slug": "my-game",
     "title": "My Game",
     "pitch": "One or two sentences that make someone want to click.",
     "credit": "Agent name (Model)"
   }
   ```

   `slug` is the game's folder name. `credit` is optional; copy it from your game's README attribution and leave it out if you don't know the model. The script generates the home-page card and the game page (embedded game plus your `RULES.md` rendered as HTML) from this entry and `site/*.template.html`, so don't hand-write HTML.
3. **Deploy:**

   ```bash
   python3 tools/deploy_web.py
   ```

   This adds a `Web` preset to your `export_presets.cfg` if it has none (the one change it makes inside a game folder; commit it), exports **every** game, builds the site and pushes `gh-pages`. Use `--no-push` to build into `.web-build/site` without publishing. Preview that with `python3 -m http.server -d .web-build/site 8000`.
4. **Commit and push your game's source to `main`** (`git add -A && git commit && git push`). The game page links to its source folder there.
5. **Check the live URL** (Pages takes a minute or two to update) and make sure the game loads and a move works. Re-run step 3 after any later change to a game so the web build is never stale.

The script shares one copy of the Godot engine (`engine/<version>/`, about 38 MB) between all games, so each game only adds its small `.pck`. GitHub Pages limits a site to 1 GiB, so don't commit or deploy anything else large. If a game's engine build differs (for example, you turned on threads or GDExtension) the script keeps that game's own engine copy and tells you.

### Making a game web-safe

Web export is stricter than the Linux build. Check these *while designing*, not after:

- **Compatibility renderer only.** Godot's default (Forward+) cannot export to the web. Projects here already use `gl_compatibility`. Note that the Compatibility renderer ignores `msaa_2d`.
- **No threads** and no GDExtensions. The preset is single-threaded so it works on GitHub Pages, which can't send the cross-origin isolation headers threads need.
- **Only read `res://`.** Don't rely on real files on disk, `OS.execute`, or the `user://` folder persisting between visits.
- **Don't quit.** `get_tree().quit()` leaves a dead canvas in a browser. Keep it to headless test modes, not in normal play.
- **Audio needs a click first.** Browsers block sound until the player interacts with the page.
- **Size to the viewport.** Keep `window/stretch/mode="canvas_items"` (with `aspect="keep"`); the page sizes the iframe to your project's `viewport_width` / `viewport_height`.
- **Test it in a browser**, not only in the editor. Headless Chromium works (`chromium --headless ...`), or open the `--no-push` build.

### Installing the Web export templates

Export templates must match `godot --version` exactly. The web ones live next to the Linux one in `~/.local/share/godot/export_templates/<version>/` (for example `4.7.2.stable/`) and must include `web_nothreads_release.zip`. If they're missing, install them yourself from the official release rather than asking the human. The download is about 1.2 GB, so only extract the web files:

```bash
V=4.7.2   # your `godot --version`, e.g. 4.7.2.stable.arch_linux... -> 4.7.2
D=$(mktemp -d) && gh release download "$V-stable" -R godotengine/godot -p "Godot_v$V-stable_export_templates.tpz" -D "$D"
# Verify against the digest GitHub publishes for the asset before using it:
gh api "repos/godotengine/godot/releases/tags/$V-stable" -q '.assets[] | select(.name|endswith("_export_templates.tpz") and (contains("mono")|not)) | .digest'
sha256sum "$D"/*.tpz
unzip -j -o -d ~/.local/share/godot/export_templates/$V.stable "$D"/*.tpz templates/web_nothreads_release.zip templates/web_release.zip
```

---

## Deliverables Checklist

Inside your game's folder:

- [ ] `project.godot` and a runnable main scene (opens and plays with `godot --path <folder>`)
- [ ] A complete, playable game with a clear ending and a way to restart
- [ ] `README.md` with known creator and model attribution at the top
- [ ] `RULES.md` — plain-language rules, plus a short "design notes" section (what you were aiming for, what you're unsure about, ideas you'd try next)
- [ ] The project passes a headless launch without errors
- [ ] `export_presets.cfg` with a `Linux` preset, and an up-to-date, tested Linux build at `build/linux/<game-name>.x86_64`
- [ ] An entry in `site/games.json`, the game deployed with `python3 tools/deploy_web.py`, and the live page checked in a browser (see [Publishing to the Web](#publishing-to-the-web))
- [ ] Source committed and pushed to `main`

When you finish, tell the human:
1. The name of the game and the one-line pitch.
2. The exact command to launch it (the exported binary, plus `godot --path <folder>` for the editor version).
3. The live web URL: `https://phlawlessdevelopment.github.io/abstract-strategy-playground/games/<slug>/`
4. What you'd most like feedback on.

---

## A Final Word

There's no rubric beyond *"is it interesting to play?"* Take a swing. Surprise us.
