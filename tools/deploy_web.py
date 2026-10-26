#!/usr/bin/env python3
"""Export every game for the web and publish the site to GitHub Pages.

    python3 tools/deploy_web.py              # export all games, build the site, push to gh-pages
    python3 tools/deploy_web.py --no-push    # build only; inspect the result in .web-build/site

The whole site is rebuilt from source on every run, so nothing goes stale and the
gh-pages branch never accumulates history (it is force-pushed as a single commit).

Needs: godot (4.x, with the matching Web export templates installed), git, python3.
Optional: the `markdown` Python module (nicer rules pages; falls back to plain text).
See "Publishing to the Web" in the root README.md.
"""
import argparse
import datetime
import hashlib
import html
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SITE_SRC = ROOT / "site"
WORK = ROOT / ".web-build"
EXPORT_DIR = WORK / "export"
OUT = WORK / "site"

# Godot names these files after the export path ("index.*"). They are byte-identical
# for every game built with the same template, so the site stores one shared copy.
ENGINE_SUFFIXES = ["js", "wasm", "audio.worklet.js", "audio.position.worklet.js"]

# Appended to a game's export_presets.cfg when it has no Web preset yet.
# Single-threaded, so it needs no special HTTP headers (GitHub Pages cannot set any).
WEB_PRESET = """
[preset.@N@]

name="Web"
platform="Web"
runnable=false
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="tests/*, tools/*, *.md"
export_path="build/web/index.html"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.@N@.options]

custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=true
html/custom_html_shell=""
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=false
"""


def die(msg):
    sys.exit(f"error: {msg}")


def run(cmd, **kw):
    return subprocess.run(cmd, text=True, capture_output=True, **kw)


def godot_version():
    r = run(["godot", "--version"])
    m = re.match(r"(\d+\.\d+(?:\.\d+)?\.[a-z0-9]+)", r.stdout.strip())
    if r.returncode or not m:
        die("could not run `godot --version`; is Godot on the PATH?")
    return m.group(1)  # e.g. "4.7.2.stable"


def check_templates(version):
    tdir = Path.home() / ".local/share/godot/export_templates" / version
    if not (tdir / "web_nothreads_release.zip").exists():
        die(f"Web export templates missing: {tdir}/web_nothreads_release.zip\n"
            "       See 'Installing the Web export templates' in the root README.md.")


def discover_games():
    return sorted(p.name for p in ROOT.iterdir()
                  if p.is_dir() and not p.name.startswith((".", "_")) and (p / "project.godot").exists())


def load_manifest(games):
    entries = json.loads((SITE_SRC / "games.json").read_text())
    slugs = [e["slug"] for e in entries]
    for e in entries:
        for key in ("slug", "title", "pitch"):
            if not e.get(key):
                die(f"site/games.json: entry {e.get('slug', '?')!r} is missing {key!r}")
        if e["slug"] not in games:
            die(f"site/games.json lists {e['slug']!r} but there is no {e['slug']}/project.godot")
    for g in games:
        if g not in slugs:
            die(f"{g}/ is a Godot project but has no entry in site/games.json (add slug, title, pitch)")
    return entries


def check_renderer(game):
    text = (ROOT / game / "project.godot").read_text()
    m = re.search(r'^renderer/rendering_method="([^"]*)"', text, re.M)
    if not m or m.group(1) != "gl_compatibility":
        die(f"{game}: Web export only supports the Compatibility renderer. In project.godot set\n"
            '       [rendering] renderer/rendering_method="gl_compatibility"')


def viewport_size(game):
    text = (ROOT / game / "project.godot").read_text()
    def get(key, default):
        m = re.search(rf"^window/size/{key}=(\d+)", text, re.M)
        return int(m.group(1)) if m else default
    return get("viewport_width", 1152), get("viewport_height", 648)


def ensure_web_preset(game):
    cfg = ROOT / game / "export_presets.cfg"
    text = cfg.read_text() if cfg.exists() else ""
    if 'platform="Web"' in text:
        return
    nums = [int(n) for n in re.findall(r"^\[preset\.(\d+)\]", text, re.M)]
    n = max(nums) + 1 if nums else 0
    cfg.write_text(text.rstrip("\n") + "\n" + WEB_PRESET.replace("@N@", str(n)) if text
                   else WEB_PRESET.lstrip("\n").replace("@N@", str(n)))
    print(f"  added a Web export preset to {game}/export_presets.cfg")


def export_game(game):
    check_renderer(game)
    ensure_web_preset(game)
    proj = str(ROOT / game)
    r = run(["godot", "--headless", "--path", proj, "--import"])
    if r.returncode:
        die(f"{game}: godot --import failed\n{r.stdout}{r.stderr}")
    dest = EXPORT_DIR / game
    shutil.rmtree(dest, ignore_errors=True)
    dest.mkdir(parents=True)
    r = run(["godot", "--headless", "--path", proj, "--export-release", "Web", str(dest / "index.html")])
    missing = [f for f in ("index.html", "index.pck", "index.wasm", "index.js") if not (dest / f).exists()]
    if r.returncode or missing:
        die(f"{game}: Web export failed (missing: {missing})\n{r.stdout}{r.stderr}")
    return dest


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_rules(game, title):
    path = ROOT / game / "RULES.md"
    if not path.exists():
        return ""
    text = path.read_text()
    text = re.sub(rf"\A#\s+{re.escape(title)}\s*\n", "", text)  # the page already has the title
    try:
        import markdown
        return markdown.markdown(text, extensions=["tables", "fenced_code"])
    except ImportError:
        return f"<pre>{html.escape(text)}</pre>"


def fill(template, values):
    out = template
    for k, v in values.items():
        out = out.replace("{{" + k + "}}", v)
    return out


def repo_urls():
    r = run(["git", "-C", str(ROOT), "remote", "get-url", "origin"])
    m = re.search(r"github\.com[:/]([^/]+)/([^/]+?)(?:\.git)?\s*$", r.stdout)
    if r.returncode or not m:
        return None
    owner, repo = m.groups()
    return {"origin": r.stdout.strip(), "owner": owner, "repo": repo,
            "repo_url": f"https://github.com/{owner}/{repo}",
            "site_url": f"https://{owner.lower()}.github.io/{repo}/"}


def build_site(entries, version, urls):
    shutil.rmtree(OUT, ignore_errors=True)
    OUT.mkdir(parents=True)
    (OUT / ".nojekyll").write_text("")

    # Static files (style.css etc.): everything in site/ except templates and the manifest.
    for p in SITE_SRC.iterdir():
        if p.name != "games.json" and not p.name.endswith(".template.html"):
            shutil.copytree(p, OUT / p.name) if p.is_dir() else shutil.copy2(p, OUT / p.name)

    engine_rel = f"engine/{version}"
    engine_dir = OUT / engine_rel
    shared = {}  # suffix -> sha256 of the shared engine file
    repo_url = urls["repo_url"] if urls else "#"
    index_t = (SITE_SRC / "index.template.html").read_text()
    game_t = (SITE_SRC / "game.template.html").read_text()
    cards = []

    for e in entries:
        slug = e["slug"]
        print(f"[{slug}] exporting...")
        exported = export_game(slug)
        play = OUT / "games" / slug / "play"
        shutil.copytree(exported, play)

        # Share the engine: the first game provides the copy; later games must match it.
        same = True
        for s in ENGINE_SUFFIXES:
            digest = sha256(play / f"index.{s}")
            if s not in shared:
                engine_dir.mkdir(parents=True, exist_ok=True)
                shutil.copy2(play / f"index.{s}", engine_dir / f"godot.{s}")
                shared[s] = digest
            same = same and shared[s] == digest
        if same:
            patch_html_for_shared_engine(play, f"../../../{engine_rel}/godot")
            for s in ENGINE_SUFFIXES:
                (play / f"index.{s}").unlink()
        else:
            print(f"  note: {slug} uses a different engine build (threads/extensions?); keeping its own copy")

        w, h = viewport_size(slug)
        credit = f"Made by {html.escape(e['credit'])}. " if e.get("credit") else ""
        page = fill(game_t, {
            "title": html.escape(e["title"]), "pitch": html.escape(e["pitch"]),
            "width": str(w), "height": str(h), "rules": read_rules(slug, e["title"]),
            "credit": credit, "source_url": f"{repo_url}/tree/main/{slug}",
        })
        (OUT / "games" / slug / "index.html").write_text(page)

        byline = f'<span class="credit">By {html.escape(e["credit"])}</span>' if e.get("credit") else ""
        cards.append(f'      <li><a class="card" href="games/{slug}/"><h2>{html.escape(e["title"])}</h2>'
                     f'<p>{html.escape(e["pitch"])}</p>{byline}</a></li>')

    (OUT / "index.html").write_text(fill(index_t, {"cards": "\n".join(cards), "repo_url": repo_url}))


def patch_html_for_shared_engine(play, exe):
    """Point a game's exported index.html at the shared engine, keeping its own .pck."""
    page = play / "index.html"
    text = page.read_text()
    if text.count('<script src="index.js"></script>') != 1:
        die("exported index.html has an unexpected shape (no single <script src=\"index.js\">); "
            "the Godot HTML template changed, update patch_html_for_shared_engine()")
    m = re.search(r"^const GODOT_CONFIG = (\{.*\});$", text, re.M)
    if not m:
        die("exported index.html has no 'const GODOT_CONFIG = {...};' line; "
            "the Godot HTML template changed, update patch_html_for_shared_engine()")
    cfg = json.loads(m.group(1))
    sizes = cfg.get("fileSizes", {})
    cfg["fileSizes"] = {"index.pck": sizes.get("index.pck", 0), f"{exe}.wasm": sizes.get("index.wasm", 0)}
    cfg["executable"] = exe
    cfg["mainPack"] = "index.pck"
    text = text.replace(m.group(0), "const GODOT_CONFIG = " + json.dumps(cfg, separators=(",", ":")) + ";")
    text = text.replace('<script src="index.js"></script>', f'<script src="{exe}.js"></script>')
    page.write_text(text)


def deploy(urls):
    if not urls:
        die("this repo has no GitHub 'origin' remote; cannot deploy")
    if urls["repo"].lower().endswith(".github.io"):
        die(f"refusing to deploy: origin is {urls['repo']}, a user/organisation Pages repo whose content "
            "(e.g. legal pages) must not be replaced. The playground must live in its own repo.")
    sha = run(["git", "-C", str(ROOT), "rev-parse", "--short", "HEAD"]).stdout.strip() or "none"
    dirty = run(["git", "-C", str(ROOT), "status", "--porcelain"]).stdout.strip()
    if dirty:
        print("note: working tree has uncommitted changes; commit and push them to main as well.")
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    def git(*args):
        r = run(["git", "-C", str(OUT), *args])
        if r.returncode:
            die(f"git {' '.join(args)} failed:\n{r.stdout}{r.stderr}")
    shutil.rmtree(OUT / ".git", ignore_errors=True)
    git("init", "-q", "-b", "gh-pages")
    git("add", "-A")
    git("commit", "-q", "-m", f"Deploy web build {stamp} (source {sha})")
    git("push", "-q", "--force", urls["origin"], "gh-pages")
    print(f"pushed gh-pages -> {urls['repo_url']}")
    print(f"live at {urls['site_url']} (GitHub Pages can take a minute to update)")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--no-push", action="store_true", help="build the site in .web-build/site but do not publish")
    args = ap.parse_args()

    version = godot_version()
    check_templates(version)
    games = discover_games()
    entries = load_manifest(games)
    urls = repo_urls()
    WORK.mkdir(exist_ok=True)
    build_site(entries, version, urls)
    size = sum(f.stat().st_size for f in OUT.rglob("*") if f.is_file()) / 1048576
    print(f"built {len(entries)} game(s), site is {size:.0f} MiB (GitHub Pages limit: 1 GiB)")
    if args.no_push:
        print(f"not pushing; site is in {OUT}")
    else:
        deploy(urls)


if __name__ == "__main__":
    main()
