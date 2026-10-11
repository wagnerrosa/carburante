#!/usr/bin/env python3
"""Gera os ícones de conquista (Premium — PLAN/premium-mvp.md §3).

Cada medalha vira um ícone alternativo do app: o mesmo fundo escuro do ícone
principal (`carburante.icon`, Icon Composer) com a arte 3D da medalha no lugar
da roda em chamas. Um ícone por ARTE (os níveis de uma categoria dividem a
arte). Medalhas de marca (logo de fabricante) e Iron Butt ficam de fora.

Uso (na raiz do repositório; macOS, usa `sips`):
    python3 scripts/achievement_icons.py

Lê a arte de `icones_3d/` (pacote comprado no Envato, fora do git) e escreve
`Carburante/Carburante/AchievementIcons/conquista-<arte>.icon`. No fim imprime
os nomes para `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` — a lista tem de
bater com `AppIconCatalog.options` no app.
"""

import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "icones_3d"
APP = ROOT / "Carburante" / "Carburante"
MAIN_ICON = APP / "carburante.icon" / "icon.json"
OUT = APP / "AchievementIcons"

# Arte da medalha (Badge.assetName) → arquivo de origem. Conferido contra os
# imagesets de Assets.xcassets/Badges em 2026-10-08.
ART = {
    "firstFuel": "Fuel.png",
    "firstMaintenance": "Mechanic.png",
    "bestConsumption": "Trophy.png",
    "piston": "Piston_2.png",
    "scooter": "Scooter.png",
    "sport": "Motor Sports.png",
    "trail": "Motocross Helmet.png",
    "offroad": "Motocross.png",
    "street": "Motorcycle.png",
    "custom": "Classic Helmet.png",
    "touring": "Jacket.png",
    "other": "Helmet.png",
}

# 512 px basta: o maior ícone na tela de início tem 180 px; o app não cresce
# ~1 MB por ícone como cresceria com 1024.
ART_PIXELS = 512
# Fração do quadro ocupada pela arte (a roda do ícone principal ocupa ~0,9).
ART_SCALE_OF_CANVAS = 0.82
CANVAS_POINTS = 1024


def main() -> None:
    template = json.loads(MAIN_ICON.read_text())
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)

    names = []
    for art, filename in ART.items():
        name = f"conquista-{art}"
        bundle = OUT / f"{name}.icon"
        assets = bundle / "Assets"
        assets.mkdir(parents=True)
        image_name = f"{art}.png"
        subprocess.run(
            ["sips", "-Z", str(ART_PIXELS), str(SOURCE / filename), "--out", str(assets / image_name)],
            check=True, capture_output=True,
        )
        icon = json.loads(json.dumps(template))
        layer = icon["groups"][0]["layers"][0]
        layer["image-name"] = image_name
        layer["name"] = art
        layer["position"] = {
            "scale": CANVAS_POINTS * ART_SCALE_OF_CANVAS / ART_PIXELS,
            "translation-in-points": [0, 0],
        }
        (bundle / "icon.json").write_text(json.dumps(icon, indent=2) + "\n")
        names.append(name)

    print("ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES =")
    print('"' + " ".join(names) + '"')


if __name__ == "__main__":
    main()
