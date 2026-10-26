#!/usr/bin/env python3
"""Build a small, neutral SVG/PNG sprite library for Godot prototypes."""

from __future__ import annotations

import json
import math
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
SIZE = 128
INK = "#ffffff"
SPRITES: dict[str, dict[str, str]] = {}


def add(category: str, name: str, art: str, note: str = "") -> None:
    SPRITES.setdefault(category, {})[name] = (art, note)


def path(d: str, width: float = 6, opacity: float = 1, fill: str = "none", extra: str = "") -> str:
    return f'<path d="{d}" fill="{fill}" stroke="{INK}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round" opacity="{opacity}" {extra}/>'


def line(x1: float, y1: float, x2: float, y2: float, width: float = 6, opacity: float = 1) -> str:
    return path(f"M{x1:g} {y1:g} L{x2:g} {y2:g}", width, opacity)


def circle(x: float, y: float, r: float, width: float = 6, opacity: float = 1, fill: str = "none") -> str:
    return f'<circle cx="{x:g}" cy="{y:g}" r="{r:g}" fill="{fill}" stroke="{INK}" stroke-width="{width:g}" opacity="{opacity:g}"/>'


def rect(x: float, y: float, w: float, h: float, radius: float = 0, width: float = 6, opacity: float = 1, fill: str = "none") -> str:
    return f'<rect x="{x:g}" y="{y:g}" width="{w:g}" height="{h:g}" rx="{radius:g}" fill="{fill}" stroke="{INK}" stroke-width="{width:g}" opacity="{opacity:g}"/>'


def poly(points: list[tuple[float, float]], width: float = 6, opacity: float = 1, fill: str = "none") -> str:
    coords = " ".join(f"{x:g},{y:g}" for x, y in points)
    return f'<polygon points="{coords}" fill="{fill}" stroke="{INK}" stroke-width="{width:g}" stroke-linejoin="round" opacity="{opacity:g}"/>'


def ell(x: float, y: float, rx: float, ry: float, width: float = 6, opacity: float = 1, fill: str = "none") -> str:
    return f'<ellipse cx="{x:g}" cy="{y:g}" rx="{rx:g}" ry="{ry:g}" fill="{fill}" stroke="{INK}" stroke-width="{width:g}" opacity="{opacity:g}"/>'


def dots(points: list[tuple[float, float]], r: float = 5, opacity: float = 1) -> str:
    return "".join(circle(x, y, r, 0, opacity, INK) for x, y in points)


def polar(cx: float, cy: float, r: float, angle: float) -> tuple[float, float]:
    a = math.radians(angle)
    return cx + r * math.cos(a), cy + r * math.sin(a)


def regular(n: int, radius: float, rotation: float = -90) -> list[tuple[float, float]]:
    return [polar(64, 64, radius, rotation + i * 360 / n) for i in range(n)]


def rays(n: int, inner: float, outer: float, width: float = 5, rotation: float = -90, opacity: float = 1) -> str:
    return "".join(line(*polar(64, 64, inner, a), *polar(64, 64, outer, a), width, opacity) for a in [rotation + i * 360 / n for i in range(n)])


# Tokens can stand for players, units, resources, or markers without assigning meaning.
add("tokens", "solid_disc", circle(64, 64, 35, 0, 1, INK))
add("tokens", "open_ring", circle(64, 64, 34, 9))
add("tokens", "nested_rings", circle(64, 64, 39, 5) + circle(64, 64, 23, 5, .7))
add("tokens", "center_pip", circle(64, 64, 39, 6) + circle(64, 64, 8, 0, 1, INK))
add("tokens", "split_disc", path("M64 25 A39 39 0 1 0 64 103 Z", 0, 1, INK) + path("M64 25 A39 39 0 1 1 64 103", 5, .7))
add("tokens", "diamond", poly([(64, 19), (105, 64), (64, 109), (23, 64)], 7))
add("tokens", "filled_diamond", poly([(64, 25), (101, 64), (64, 103), (27, 64)], 0, 1, INK))
add("tokens", "kite", poly([(64, 15), (96, 63), (64, 112), (32, 63)], 6) + line(32, 63, 96, 63, 3, .5))
add("tokens", "triangle", poly(regular(3, 45), 7))
add("tokens", "inverted_triangle", poly(regular(3, 45, 90), 7))
add("tokens", "hexagon", poly(regular(6, 43), 7))
add("tokens", "octagon", poly(regular(8, 43, 22.5), 7))
add("tokens", "capsule", rect(27, 39, 74, 50, 25, 7))
add("tokens", "lozenge", path("M20 64 Q64 17 108 64 Q64 111 20 64Z", 6))
add("tokens", "cross", path("M52 24 H76 V52 H104 V76 H76 V104 H52 V76 H24 V52 H52 Z", 6))
add("tokens", "four_petals", "".join(ell(*polar(64, 64, 19, a), 13 if a % 180 else 22, 22 if a % 180 else 13, 4) for a in [0, 90, 180, 270]))
add("tokens", "clover", "".join(circle(*polar(64, 64, 19, a), 18, 4) for a in [45, 135, 225, 315]))
add("tokens", "crescent", '<defs><mask id="cut"><rect width="128" height="128" fill="white"/><circle cx="82" cy="53" r="37" fill="black"/></mask></defs><circle cx="61" cy="64" r="43" fill="white" mask="url(#cut)"/>')
add("tokens", "eclipse", circle(58, 64, 34, 5) + circle(77, 64, 34, 5, .6))
add("tokens", "spiral", path("M65 65 C58 65 57 55 65 51 C78 43 89 57 82 70 C74 88 47 85 40 67 C31 42 57 22 80 32 C108 43 110 79 88 97", 6))
add("tokens", "orbit", ell(64, 64, 44, 22, 5) + ell(64, 64, 22, 44, 5, .7) + circle(64, 64, 7, 0, 1, INK))
add("tokens", "hourglass", poly([(33, 25), (95, 25), (65, 64), (95, 103), (33, 103), (63, 64)], 6))
add("tokens", "pinwheel", "".join(path(f"M64 64 Q{polar(64,64,37,a-23)[0]:.1f} {polar(64,64,37,a-23)[1]:.1f} {polar(64,64,43,a)[0]:.1f} {polar(64,64,43,a)[1]:.1f}", 6) for a in [0, 90, 180, 270]) + circle(64,64,6,0,1,INK))
add("tokens", "sunburst", circle(64, 64, 24, 5) + rays(12, 32, 47, 5))


# Frames leave the middle open for numbers, drawn pieces, or extra markers.
add("frames", "circle", circle(64, 64, 46, 5))
add("frames", "double_circle", circle(64,64,47,4)+circle(64,64,37,3,.55))
add("frames", "dashed_circle", circle(64,64,44,5,1,"none",) .replace("/>", ' stroke-dasharray="10 10"/>'))
add("frames", "segmented_circle", "".join(path(f"M{polar(64,64,44,a)[0]:.2f} {polar(64,64,44,a)[1]:.2f} A44 44 0 0 1 {polar(64,64,44,a+33)[0]:.2f} {polar(64,64,44,a+33)[1]:.2f}", 6) for a in range(-90,270,45)))
add("frames", "square", rect(19,19,90,90,0,5))
add("frames", "rounded_square", rect(18,18,92,92,22,5))
add("frames", "double_square", rect(17,17,94,94,9,4)+rect(28,28,72,72,6,3,.55))
add("frames", "diamond", poly([(64,12),(116,64),(64,116),(12,64)],5))
add("frames", "hexagon", poly(regular(6,50),5))
add("frames", "octagon", poly(regular(8,50,22.5),5))
add("frames", "corner_brackets", "".join(path(d,6) for d in ["M18 46 V18 H46","M82 18 H110 V46","M110 82 V110 H82","M46 110 H18 V82"]))
add("frames", "mid_brackets", "".join(path(d,6) for d in ["M42 26 H26 V102 H42","M86 26 H102 V102 H86"]))
add("frames", "broken_ring", path("M47 22 A45 45 0 1 0 81 22",6)+path("M55 16 L64 29 L73 16",4,.65))
add("frames", "notched_square", path("M19 19 H49 L64 34 L79 19 H109 V49 L94 64 L109 79 V109 H79 L64 94 L49 109 H19 V79 L34 64 L19 49 Z",5))
add("frames", "soft_scallop", path("M64 17 Q77 13 83 25 Q96 20 103 33 Q116 40 107 52 Q117 64 107 76 Q116 88 103 95 Q96 108 83 103 Q77 115 64 111 Q51 115 45 103 Q32 108 25 95 Q12 88 21 76 Q11 64 21 52 Q12 40 25 33 Q32 20 45 25 Q51 13 64 17Z",5))
add("frames", "cardinal_ticks", circle(64,64,37,4,.55)+rays(4,43,55,6))


# Conduits are edge-to-edge tile pieces. Rotate them by 90 degrees as needed.
add("conduits", "thin_straight", line(-8,64,136,64,5))
add("conduits", "bold_straight", line(-8,64,136,64,14))
add("conduits", "double_straight", line(-8,53,136,53,5)+line(-8,75,136,75,5))
add("conduits", "triple_straight", "".join(line(-8,y,136,y,3,.85) for y in [50,64,78]))
add("conduits", "dashed_straight", path("M-8 64 H136",7,1,extra='stroke-dasharray="14 11"'))
add("conduits", "dotted_straight", path("M-8 64 H136",7,1,extra='stroke-dasharray="1 13"'))
add("conduits", "wire_straight", line(-8,64,136,64,4)+dots([(29,64),(64,64),(99,64)],4))
add("conduits", "wire_paired", line(-8,54,136,54,4)+line(-8,74,136,74,4)+"".join(line(x,54,x,74,3,.7) for x in [16,64,112]))
add("conduits", "pipe_straight", rect(-8,48,144,32,8,5)+line(-8,55,136,55,2,.4))
add("conduits", "pipe_ribbed", rect(-8,47,144,34,8,5)+"".join(line(x,48,x,80,3,.6) for x in [16,40,64,88,112]))
add("conduits", "sleeved_straight", line(-8,64,136,64,6)+rect(47,48,34,32,7,5))
add("conduits", "beaded_straight", line(-8,64,136,64,4,.65)+"".join(circle(x,64,7,3,1,INK) for x in [23,64,105]))
add("conduits", "elbow", path("M64 -8 V64 H136",7))
add("conduits", "rounded_elbow", path("M64 -8 V41 Q64 64 87 64 H136",7))
add("conduits", "double_elbow", path("M53 -8 V75 H136",5)+path("M75 -8 V53 H136",5))
add("conduits", "tee", path("M-8 64 H136 M64 64 V-8",7))
add("conduits", "round_tee", '<defs><mask id="cut"><rect width="128" height="128" fill="white"/><circle cx="64" cy="64" r="11" fill="black"/></mask></defs><g mask="url(#cut)">'+path("M-8 64 H136 M64 64 V-8",7)+'</g>'+circle(64,64,12,5))
add("conduits", "cross", path("M-8 64 H136 M64 -8 V136",7))
add("conduits", "ring_cross", '<defs><mask id="cut"><rect width="128" height="128" fill="white"/><circle cx="64" cy="64" r="16" fill="black"/></mask></defs><g mask="url(#cut)">'+path("M-8 64 H136 M64 -8 V136",6)+'</g>'+circle(64,64,17,5))
add("conduits", "y_split", path("M64 136 V76 Q64 61 51 49 L0 -2 M64 76 Q64 61 77 49 L128 -2",7))
add("conduits", "s_curve", path("M-8 64 C28 64 28 29 64 29 S100 64 136 64",7))
add("conduits", "wave", path("M-8 64 C10 28 28 28 46 64 S82 100 100 64 S118 28 136 64",6))
add("conduits", "zigzag", path("M-8 64 H28 L43 43 L64 85 L85 43 L100 64 H136",6))
add("conduits", "braided", path("M-8 54 C15 54 21 74 42 74 S69 54 85 54 S110 74 136 74",5)+path("M-8 74 C15 74 21 54 42 54 S69 74 85 74 S110 54 136 54",5))


# Nodes are deliberately ambiguous: a hub, socket, switch, etc. can mean anything.
add("nodes", "plain_hub", circle(64,64,32,6)+circle(64,64,9,0,1,INK))
add("nodes", "open_hub", circle(64,64,37,7)+circle(64,64,19,4,.6))
add("nodes", "radial_hub", circle(64,64,25,5)+rays(8,34,49,5)+circle(64,64,5,0,1,INK))
add("nodes", "spoked_hub", circle(64,64,42,5)+"".join(line(64,64,*polar(64,64,40,a),4,.7) for a in range(0,360,45))+circle(64,64,9,0,1,INK))
add("nodes", "three_port", circle(64,64,29,5)+"".join(circle(*polar(64,64,42,a),7,4) for a in [-90,30,150]))
add("nodes", "four_port", circle(64,64,30,5)+"".join(circle(*polar(64,64,43,a),7,4) for a in [-90,0,90,180]))
add("nodes", "six_port", poly(regular(6,34),5)+"".join(circle(*polar(64,64,45,a),5,3) for a in range(-90,270,60)))
add("nodes", "socket", circle(64,64,39,6)+path("M48 46 V76 M80 46 V76",6)+path("M48 76 Q64 91 80 76",5))
add("nodes", "split_socket", path("M64 20 A44 44 0 0 0 64 108 M64 20 A44 44 0 0 1 64 108",6)+line(64,22,64,106,4,.6))
add("nodes", "valve", circle(64,64,39,5)+path("M35 37 L93 91 M93 37 L35 91",7))
add("nodes", "coil", circle(64,64,45,5)+path("M30 64 C30 44 44 44 44 64 S58 84 58 64 S72 44 72 64 S86 84 86 64 S100 44 100 64",5))
add("nodes", "capacitor", circle(64,64,45,5)+line(48,33,48,95,6)+line(80,33,80,95,6))
add("nodes", "lattice", poly(regular(6,47),5)+"".join(line(*polar(64,64,47,a),*polar(64,64,47,a+120),3,.65) for a in [-90,-30,30]))
add("nodes", "nested_square", rect(22,22,84,84,14,5)+rect(43,43,42,42,6,5,.75)+circle(64,64,5,0,1,INK))
add("nodes", "three_lobes", "".join(circle(*polar(64,64,22,a),19,5) for a in [-90,30,150])+circle(64,64,6,0,1,INK))
add("nodes", "iris", circle(64,64,45,5)+"".join(path(f"M64 64 Q{polar(64,64,33,a+10)[0]:.1f} {polar(64,64,33,a+10)[1]:.1f} {polar(64,64,40,a+60)[0]:.1f} {polar(64,64,40,a+60)[1]:.1f}",4,.8) for a in range(0,360,60)))


# Low-level accents: put them over existing pieces or use alone.
add("accents", "single_pip", dots([(64,64)],8))
add("accents", "double_pip", dots([(48,64),(80,64)],7))
add("accents", "triple_pip", dots([(39,64),(64,64),(89,64)],6))
add("accents", "four_pips", dots([(46,46),(82,46),(46,82),(82,82)],6))
add("accents", "nine_pips", dots([(x,y) for x in [40,64,88] for y in [40,64,88]],4.5))
add("accents", "small_plus", path("M64 40 V88 M40 64 H88",7))
add("accents", "small_cross", path("M45 45 L83 83 M83 45 L45 83",7))
add("accents", "short_dash", line(39,64,89,64,8))
add("accents", "slash", line(40,89,88,39,7))
add("accents", "chevron", path("M39 49 L64 76 L89 49",7))
add("accents", "double_chevron", path("M39 37 L64 62 L89 37 M39 64 L64 89 L89 64",6))
add("accents", "asterisk", rays(6,4,28,5))
add("accents", "spark", path("M64 25 L72 56 L103 64 L72 72 L64 103 L56 72 L25 64 L56 56 Z",4))
add("accents", "small_target", circle(64,64,26,4)+circle(64,64,7,0,1,INK))
add("accents", "quarter_arcs", "".join(path(f"M{polar(64,64,33,a)[0]:.1f} {polar(64,64,33,a)[1]:.1f} A33 33 0 0 1 {polar(64,64,33,a+45)[0]:.1f} {polar(64,64,33,a+45)[1]:.1f}",5) for a in [0,90,180,270]))
add("accents", "ticks", rays(8,28,39,4))


# Tile overlays are clipped inside a 96-pixel square. They do not imply terrain or rules.
def texture(content: str, border: bool = True) -> str:
    return '<defs><clipPath id="tile"><rect x="16" y="16" width="96" height="96" rx="9"/></clipPath></defs>' + (rect(16,16,96,96,9,3,.35) if border else "") + '<g clip-path="url(#tile)">' + content + '</g>'


add("textures", "parallel_lines", texture("".join(line(8,y,120,y,3,.55) for y in range(25,113,14))))
add("textures", "vertical_lines", texture("".join(line(x,8,x,120,3,.55) for x in range(25,113,14))))
add("textures", "diagonal_hatch", texture("".join(line(x,8,x+104,112,3,.55) for x in range(-80,113,16))))
add("textures", "cross_hatch", texture("".join(line(x,8,x+104,112,2,.45)+line(x,112,x+104,8,2,.45) for x in range(-80,113,18))))
add("textures", "dot_field", texture(dots([(x,y) for x in range(28,112,16) for y in range(28,112,16)],2.5,.65)))
add("textures", "offset_dots", texture(dots([(x+(7 if row%2 else 0),28+row*16) for row in range(6) for x in range(27,108,16)],2.8,.6)))
add("textures", "grid", texture("".join(line(x,12,x,116,2,.5) for x in range(32,113,16))+"".join(line(12,y,116,y,2,.5) for y in range(32,113,16))))
add("textures", "broken_grid", texture("".join(line(x,22,x,106,2,.45) for x in [39,64,89])+"".join(line(22,y,106,y,2,.45) for y in [39,64,89])+dots([(x,y) for x in [39,64,89] for y in [39,64,89]],3.5,.85)))
add("textures", "waves", texture("".join(path(f"M12 {y} Q38 {y-15} 64 {y} T116 {y}",3,.55) for y in [27,47,67,87,107])))
add("textures", "chevrons", texture("".join(path(f"M10 {y+12} L36 {y-10} L62 {y+12} L88 {y-10} L114 {y+12}",3,.55) for y in [32,60,88,116])))
add("textures", "concentric", texture("".join(circle(64,64,r,3,.55) for r in [14,29,44,59,74])))
add("textures", "radial", texture(rays(16,9,70,2,.0,.55)))
add("textures", "lozenges", texture("".join(poly([(x,y-9),(x+9,y),(x,y+9),(x-9,y)],2,.55) for y in [31,55,79,103] for x in [28,52,76,100])))
add("textures", "slots", texture("".join(rect(x,y,22,5,2,0,.55,INK) for y in [30,50,70,90,110] for x in [24+(13 if y%40==10 else 0),68+(13 if y%40==10 else 0)])))
add("textures", "rings", texture("".join(circle(x,y,7,2,.55) for x in [30,52,74,96] for y in [30,52,74,96])))
add("textures", "fracture", texture(path("M17 54 L39 44 L49 69 L73 57 L84 82 L109 67",3,.75)+path("M39 44 L43 17 M49 69 L30 105 M73 57 L88 17 M84 82 L91 112",3,.55)))


def svg(art: str) -> str:
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">\n{art}\n</svg>\n'


def build() -> None:
    manifest = {"size": [SIZE, SIZE], "style": "white with transparency; tint with Godot modulate", "categories": {}}
    for category, items in SPRITES.items():
        folder = ROOT / category
        folder.mkdir(exist_ok=True)
        manifest["categories"][category] = []
        for name, (art, note) in items.items():
            source = folder / f"{name}.svg"
            output = folder / f"{name}.png"
            source.write_text(svg(art))
            subprocess.run(["rsvg-convert", "-w", str(SIZE), "-h", str(SIZE), "-o", str(output), str(source)], check=True)
            manifest["categories"][category].append({"name": name, "svg": f"{category}/{name}.svg", "png": f"{category}/{name}.png", "note": note})
    (ROOT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    contact_sheet()


def contact_sheet() -> None:
    columns = 8
    cell_w, cell_h = 148, 164
    entries = [(category, name) for category, items in SPRITES.items() for name in items]
    rows = math.ceil(len(entries) / columns)
    sheet = Image.new("RGB", (columns * cell_w, rows * cell_h + 50), "#162226")
    draw = ImageDraw.Draw(sheet)
    font_path = "/usr/share/fonts/TTF/DejaVuSans.ttf"
    if not Path(font_path).exists():
        font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    font = ImageFont.truetype(font_path, 12) if Path(font_path).exists() else ImageFont.load_default()
    title_font = ImageFont.truetype(font_path, 18) if Path(font_path).exists() else font
    draw.text((18, 13), f"ABSTRACT SPRITE LIBRARY  /  {len(entries)} assets", fill="#E9F2F2", font=title_font)
    for index, (category, name) in enumerate(entries):
        col, row = index % columns, index // columns
        x, y = col * cell_w, row * cell_h + 50
        draw.rounded_rectangle((x+5,y+4,x+cell_w-5,y+cell_h-4), radius=10, fill="#203037", outline="#345057", width=1)
        icon = Image.open(ROOT / category / f"{name}.png").convert("RGBA")
        sheet.paste(icon, (x+10,y+7), icon)
        draw.text((x+10,y+133), name[:20], fill="#D6E7E5", font=font)
        draw.text((x+10,y+148), category, fill="#8DA9A9", font=font)
    sheet.save(ROOT / "contact_sheet.png")


if __name__ == "__main__":
    build()
