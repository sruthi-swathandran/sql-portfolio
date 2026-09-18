"""
Render the GeoJSON exports as PNGs for the project README.

    python 09_render_maps.py

Reads   maps/*.geojson
Writes  images/*.png

Requires: matplotlib.  pip install matplotlib


WHY A SCRIPT AND NOT A SCREENSHOT
---------------------------------
GitHub renders .geojson as an interactive map in its file viewer,
but a README cannot embed that view. It can only link to it. So
the README needs a static image as well.

A screenshot of GitHub's viewer would carry its interface chrome
and basemap attribution into the document, and could not be
regenerated when a number changes. This reads the same file the
map is built from, so the picture and the interactive version can
never disagree.

STYLING COMES FROM THE DATA
---------------------------
The fill colour of every zone is a property on the feature,
written by the CASE expression in 08_export_maps.sql. This script
does not decide what colour anything is. It draws what the query
already decided, which keeps one definition of the colour scale
rather than two that can drift apart.
"""

import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon as MplPolygon
from matplotlib.collections import PatchCollection
from matplotlib.lines import Line2D

HERE = Path(__file__).resolve().parent.parent
MAPS = HERE / "maps"
IMAGES = HERE / "images"


def rings(geometry):
    """Yield exterior rings. Holes are ignored: the taxi zones have
    none worth drawing at this scale, and filling them correctly
    would need a compound path for no visible gain."""
    if geometry["type"] == "Polygon":
        yield geometry["coordinates"][0]
    elif geometry["type"] == "MultiPolygon":
        for part in geometry["coordinates"]:
            yield part[0]


def render(geojson_path: Path, png_path: Path, title: str, legend: list) -> None:
    data = json.loads(geojson_path.read_text(encoding="utf-8"))

    patches, colours = [], []
    for feature in data["features"]:
        fill = feature["properties"].get("fill", "#cccccc")
        for ring in rings(feature["geometry"]):
            patches.append(MplPolygon(ring, closed=True))
            colours.append(fill)

    fig, ax = plt.subplots(figsize=(11, 11), dpi=110)

    ax.add_collection(PatchCollection(
        patches,
        facecolor=colours,
        edgecolor="#8a8a8a",
        linewidths=0.35,
    ))

    # Latitude and longitude are not interchangeable units. One
    # degree of longitude at 40.7 degrees north covers about 76%
    # of what a degree of latitude does, so an equal aspect ratio
    # would stretch the city east to west.
    ax.set_aspect(1 / 0.758)
    ax.autoscale_view()
    ax.set_axis_off()
    ax.set_title(title, fontsize=13, loc="left", pad=14)

    ax.legend(
        handles=[Line2D([0], [0], marker="s", linestyle="none", markersize=11,
                        markerfacecolor=c, markeredgecolor="#8a8a8a", label=l)
                 for c, l in legend],
        loc="upper left",
        frameon=False,
        fontsize=9,
    )

    IMAGES.mkdir(exist_ok=True)
    fig.savefig(png_path, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print(f"{png_path.name}  ({png_path.stat().st_size / 1000:.0f} KB)")


def main() -> None:
    render(
        MAPS / "zone_change_2017_2019.geojson",
        IMAGES / "zone-change-2017-2019.png",
        "Green taxi pickups by zone, change from 2017 to 2019",
        [("#1a9850", "up more than 50%"),
         ("#a6d96a", "up 10 to 50%"),
         ("#ffffbf", "within 10%"),
         ("#fdae61", "down 10 to 40%"),
         ("#f46d43", "down 40 to 60%"),
         ("#d73027", "down more than 60%"),
         ("#cccccc", "under 5,000 trips in 2017")],
    )

    bands = MAPS / "zone_distance_bands.geojson"
    if bands.exists():
        render(
            bands,
            IMAGES / "zone-distance-bands.png",
            "Distance from the Manhattan Yellow Zone",
            [("#54278f", "Yellow Zone"),
             ("#756bb1", "0 to 4 km"),
             ("#9e9ac8", "4 to 8 km"),
             ("#bcbddc", "8 to 12 km"),
             ("#dadaeb", "12 to 18 km"),
             ("#f2f0f7", "18 km plus")],
        )


if __name__ == "__main__":
    main()
