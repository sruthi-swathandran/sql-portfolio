"""
Convert the TLC taxi zone shapefile into a tab-separated file that
MySQL can LOAD DATA, with one MULTIPOLYGON and one centroid POINT
per location id.

    python 02_build_zone_geometry.py

Reads   data/taxi_zones_map/taxi_zones_map_shapefiles/taxi_zones_map.shp
Writes  data/zone_geometry.tsv

Requires: pyshp, shapely.  pip install pyshp shapely


WHY THIS SCRIPT EXISTS AT ALL
-----------------------------
Two things MySQL will not do for us.

First, ST_Centroid rejects geographic spatial reference systems:

    Error 3618: st_centroid(POLYGON) has not been implemented for
    geographic spatial reference systems

So the centroid is computed here and stored as a column.

Second, the shapefile holds 263 records but only 260 distinct
location ids. Ids 56 and 103 each appear twice, while 57, 104 and
105 are absent. In taxi_zones.csv, 56 and 57 are both named Corona
and 103, 104 and 105 are all Governor's Island/Ellis Island/Liberty
Island, so the shapefile appears to label same-named adjacent zones
inconsistently.

Which record belongs to which id cannot be recovered from these
files, so nothing is guessed. Records sharing an id are merged into
one geometry and the three unmatched ids are left without one.


CENTROIDS ARE COMPUTED IN DEGREES
---------------------------------
Treating longitude and latitude as plane coordinates distorts
distances, so in principle a centroid should be computed in a
projected system. In practice it was checked: computing every
centroid both in raw degrees and via EPSG:2263 (NY Long Island,
feet) and comparing the two gave a maximum difference of 0.5 metres
across all 260 zones, with a median of zero. Zones are small enough
that the distortion cancels.

Raw degrees is therefore used, which removes a pyproj dependency.


AXIS ORDER
----------
This file writes WKT as "longitude latitude", which is how the
shapefile stores it. The LOAD DATA statement that reads it must
pass 'axis-order=long-lat' to ST_GeomFromText, because MySQL
otherwise follows the EPSG:4326 definition and reads latitude
first. See the comments in 03_load_reference.sql.
"""

from collections import defaultdict
from pathlib import Path

import shapefile
from shapely.geometry import shape, MultiPolygon
from shapely.ops import unary_union

HERE = Path(__file__).resolve().parent.parent
SHP = HERE / "data" / "taxi_zones_map" / "taxi_zones_map_shapefiles" / "taxi_zones_map"
OUT = HERE / "data" / "zone_geometry.tsv"


def main() -> None:
    reader = shapefile.Reader(str(SHP))

    # Group by location id first. Records sharing an id are parts of
    # the same zone as far as this data can tell, so they merge.
    by_id: dict[int, list] = defaultdict(list)
    for record, shp in zip(reader.records(), reader.shapes()):
        # __geo_interface__ resolves ring orientation for us, so
        # interior rings stay holes rather than becoming solid.
        by_id[int(record["location_i"])].append(shape(shp.__geo_interface__))

    print(f"shapefile records : {len(reader)}")
    print(f"distinct location ids : {len(by_id)}")
    merged = [lid for lid, parts in by_id.items() if len(parts) > 1]
    print(f"ids built from more than one record : {sorted(merged)}")

    repaired = 0
    outside = []
    rows = []

    for location_id in sorted(by_id):
        geom = unary_union(by_id[location_id])

        # buffer(0) is the standard repair for self-intersecting
        # rings. None were found in this shapefile, but a silent
        # invalid geometry would make every spatial predicate on
        # that zone unreliable, so the check stays.
        if not geom.is_valid:
            geom = geom.buffer(0)
            repaired += 1

        # The column is MULTIPOLYGON, so single-part zones have to
        # be wrapped rather than written as POLYGON.
        if geom.geom_type == "Polygon":
            geom = MultiPolygon([geom])

        centroid = geom.centroid

        # A centroid can fall outside its own polygon when the zone
        # is a ring of islands or a crescent. That is acceptable for
        # measuring distance between zones, but it is worth knowing
        # which zones it happens to.
        if not geom.contains(centroid):
            outside.append(location_id)

        rows.append((location_id, geom.wkt, centroid.wkt))

    with OUT.open("w", encoding="utf-8", newline="\n") as fh:
        for location_id, geom_wkt, centroid_wkt in rows:
            fh.write(f"{location_id}\t{geom_wkt}\t{centroid_wkt}\n")

    print(f"invalid geometries repaired : {repaired}")
    print(f"centroid outside its own zone : {len(outside)} {sorted(outside)}")
    print(f"rows written : {len(rows)}")
    print(f"output : {OUT}  ({OUT.stat().st_size / 1e6:.1f} MB)")


if __name__ == "__main__":
    main()
