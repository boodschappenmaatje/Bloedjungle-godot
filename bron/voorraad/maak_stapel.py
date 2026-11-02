"""Voorraadstapel (Generals-plan stap 4b, stijl Intendance): een pallet met olijfgroene voorraadkisten in drie standen.

    python bron/voorraad/maak_stapel.py hq     # bewerkbare bron: uit/Voorraadstapel_HQ.blend (procedurele materialen, geen bake)
    python bron/voorraad/maak_stapel.py game   # Godot-versie: assets/voorraadstapel.glb (+ uit/Voorraadstapel.usdz)

Eén bestand, drie groepen naast elkaar op x = -6, 0 en 6 m (zodat de viewer ze naast elkaar toont): `Stapel_vol` (14 kisten, net
half eroverheen), `Stapel_half` (7 kisten, los net) en `Stapel_leeg` (3 kisten, losse planken en een scheef net). Elke groep heeft een
eigen oorsprong in het midden van de pallet op de grond; Godot zet ze op (0, 0, 0) en laat één tegelijk zien. Eén 2K-atlas voor alles.
"""
import random

from vc import *  # noqa: F401,F403


AFHAAL_Z = 2.8                 # afhaalkist: zoveel meter voor het midden van de stapel (de truck pakt hem daar)
CB = (0.96, 0.62, 1.3)         # dezelfde kist als in de truck en het depot


def build_stand(name, x0, count, M, tag):
    root = empty(f"Stapel_{name}", None, (x0, 0, 0))
    gs, gm, gy, gk, gh, gn, gd = G(), G(), G(), bmesh.new(), G(), bmesh.new(), G()
    rng = random.Random({"vol": 101, "half": 102, "leeg": 103}[name])
    pallet(gh, gm, (0, 0.22, 0))
    # standplaatsen van de kisten: laag, rij (x), kolom (z)
    slots = []
    for layer in range(3):
        for cz in range(2):
            for cx in range(3):
                slots.append((layer, cx, cz))
    texts = ["batch", "int", "swl", "n01", "int", "batch", "n02", "int", "swl", "n03", "batch", "int", "n01", "swl"]
    if name == "leeg":
        slots = [(0, 0, 0), (0, 2, 0), (0, 1, 1)]
    for k in range(count):
        layer, cx, cz = slots[k]
        x = -1.5 + cx * 1.5 + rng.uniform(-0.03, 0.03)
        z = -0.9 + cz * 1.8 + rng.uniform(-0.03, 0.03)
        y = 0.22 + 0.36 + layer * 0.74
        crate(gs, gm, gy, gk, (x, y, z), yaw=rng.uniform(-0.06, 0.06), stencil=texts[k % len(texts)])
    if name == "leeg":
        # een scheefgevallen lege kist, losse planken, een ontbrekende dekplank en wat afval
        crate(gs, gm, gy, gk, (1.2, 0.62, -0.7), yaw=0.5, stencil="int")
        for i in range(5):
            bx(gh, (rng.uniform(-2.0, 2.2), 0.045 + 0.05 * (i // 3), rng.uniform(-2.7, -2.0) if i < 3 else rng.uniform(2.1, 2.8)),
               (rng.uniform(1.2, 2.0), 0.05, 0.16), yaw=rng.uniform(-0.6, 0.6))
        bx(gh, (-2.6, 0.5, 0.4), (0.14, 1.1, 0.05), pitch=0.0, roll=0.5, yaw=0.3)   # schuin rechtopstaand stuk plank
        cloth_patch(gn, (-0.6, 0.30, 0.0), 3.6, 2.6, 0.05, 3, yaw=0.3, sag=0.06)
    elif name == "half":
        cloth_patch(gn, (-1.0, 0.22 + 0.36 + 0.74 + 0.37, 0.0), 2.2, 2.0, 0.06, 4, yaw=-0.15, nx=10, nz=8, sag=0.1)
    else:
        # vol: het net hangt over de rechterhelft en valt langs de zijkant
        cloth_patch(gn, (1.1, 0.22 + 0.36 + 2 * 0.74 + 0.40, 0.0), 2.8, 3.6, 0.55, 5, yaw=0.0, nx=14, nz=14, sag=0.12)
        for sx in (-1.1, 1.1):
            bar(gd, (sx, 0.22, -2.0), (sx, 0.22 + 0.74 * 2 + 0.76, -2.0), 0.05, 0.015)   # spanbanden over de laatste laag
            bar(gd, (sx, 0.22 + 0.74 * 2 + 0.76, -2.0), (sx, 0.22 + 0.74 * 2 + 0.76, 2.0), 0.05, 0.015)
    objs = []
    for suffix, g, mat, tile in (("Kisten", gs, M["olijf"], 1.0), ("Beslag", gm, M["staal"], 0.5), ("Band", gy, M["geel"], 0.5),
                                 ("Pallet", gh, M["hout"], 0.6), ("Banden", gd, M["donker"], 0.5)):
        o = commit(f"{suffix}_{name}", g, mat, root, tile=tile, bevel=((suffix == "Kisten" and D >= 1) or (suffix == "Pallet" and D >= 2)))
        if o:
            objs.append(o)
    for suffix, bm, mat in (("Net", gn, M["net"]), ("Stencil", gk, M["stencil"])):
        if bm.faces:
            o = F.new_obj(f"{suffix}_{name}", bm, mat, smooth=False, parent=root)
            objs.append(o)
        else:
            bm.free()
    # afhaalkist: een losse kist op een klein pallet aan de voorkant (+z) van de stapel; de grijper van de truck pakt hem daar (maat = kist van de truck)
    ah = empty("Afhaal", root, (0, 0, 0))
    ah["nocull"] = True
    ga, gam, gay, gak, gal = G(), G(), G(), bmesh.new(), G()
    pallet(gal, gam, (0, 0.22, AFHAAL_Z), w=1.25, d=1.5, boards=5)
    crate(ga, gam, gay, gak, (0, 0.22 + CB[1] / 2, AFHAAL_Z), yaw=0.03, stencil="batch", size=CB)
    for suffix, g, mat, tile in (("Afhaal_kist", ga, M["olijf"], 1.0), ("Afhaal_beslag", gam, M["staal"], 0.5), ("Afhaal_band", gay, M["geel"], 0.5),
                                 ("Afhaal_pallet", gal, M["hout"], 0.6)):
        o = commit(f"{suffix}_{name}", g, mat, ah, tile=tile, bevel=((suffix == "Afhaal_kist" and D >= 1) or (suffix == "Afhaal_pallet" and D >= 2)))
        if o:
            o["nocull"] = True
            objs.append(o)
    o = F.new_obj(f"Afhaal_stencil_{name}", gak, M["stencil"], smooth=False, parent=ah)
    o["nocull"] = True
    objs.append(o)
    return root, objs


def main():
    sc = fresh_scene()
    M = materials()
    stands = []
    for name, x0, n in (("vol", -6.0, 14), ("half", 0.0, 7), ("leeg", 6.0, 3)):
        root, objs = build_stand(name, x0, n, M, name)
        stands.append((name, root, objs))
        print(f"[{LEVEL}] stand {name}: {n} kisten")
    print(f"[{LEVEL}] driehoeken (voor snoeien): {tri_count()}")
    stem = {"hq": "Voorraadstapel_HQ", "game": "voorraadstapel"}[LEVEL]
    if LEVEL != "hq":
        bake_groups([("stapel", bakeable())])
    print(f"[{LEVEL}] driehoeken: {tri_count()}")
    for name, root, objs in stands:
        n = 0
        dg = bpy.context.evaluated_depsgraph_get()
        for o in objs:
            if o.type == "MESH":
                n += sum(len(p.vertices) - 2 for p in o.evaluated_get(dg).to_mesh().polygons)
        print(f"[{LEVEL}]   {name}: {n} driehoeken")
    print(f"[{LEVEL}] materialen: {len(bpy.data.materials)}")
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / f"{stem}.blend"))
    if LEVEL == "hq":
        print("HQ-bron opgeslagen:", OUT / f"{stem}.blend")
        return
    export_glb(ROOT / "assets" / f"{stem}.glb")
    export_usdz(OUT / "Voorraadstapel.usdz")


if __name__ == "__main__":
    main()
