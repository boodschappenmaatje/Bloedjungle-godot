# Colt Shot VFX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bouw de goedgekeurde Colt-flits, baan en muur-/boominlagen als opt-in en lever een afspeelbare 3D-reviewviewer vóór merge.

**Architecture:** Hergebruik de bestaande M1911-flipbookroute en pools in `Fx`; laat `Bullet` het Colt-profiel doorgeven aan een materiaalafhankelijke impact. Breid de bestaande Three.js-viewer uit met een geïsoleerde schot- en inslagdemo op het echte M1911 GLB.

**Tech Stack:** Godot GDScript, Godot 4.7 Mobile, Three.js 0.180, esbuild, Playwright.

**Spec:** `docs/superpowers/specs/2026-11-10-colt-shot-vfx-design.md`

## Global Constraints
- Bestaande Draft PR #269; geen merge of OTA.
- Geen verandering aan audio, gameplay of standaard grafische instellingen.
- Oude inslagen verdwijnen bij de cap; iPhone 60 FPS is een doel, geen ongeteste claim.

## Review Focus
- Twee snelle Colt-schoten mogen geen gedeeld shader-frame door elkaar halen.
- Een ander wapen mag niet de Colt-inslag krijgen.
- Een boomstam moet als hout geclassificeerd blijven.
- Bij veel inslagen blijft de decalpool begrensd en worden de oudste verwijderd.
- De viewer moet een werkelijk bewegende slede en een afspeelbare effecttijdlijn hebben.

### Task 1: Colt flits en baan

**Files:** `scripts/fx.gd`, `scripts/bullet.gd`, `scripts/data.gd`, `assets/vfx/m1911/m1911_flipbook.gdshader`, `tests/colt_vfx_test.gd`.

**Interfaces:** `Fx.m1911_vfx_enabled() -> bool`; `Bullet._weapon_glow()` gebruikt de Colt-profielwaarden. Bestaande `Fx.muzzle()` blijft de ingang.

- [ ] Schrijf regressietests voor opt-in en overlappende flitsen.
- [ ] Voer de test uit en noteer de baseline.
- [ ] Geef elke actieve atlasflits een eigen shader-instance en stel flits/baankleuren af op de goedgekeurde mockup.
- [ ] Controleer test en Godot-import.
- [ ] Commit.

### Task 2: Materiaalafhankelijke Colt-inslag

**Files:** `scripts/fx.gd`, `scripts/bullet.gd`, `tests/colt_vfx_test.gd`.

**Interfaces:** `Fx.impact(parent, pos, normal, material, colt_shot := false)`; alleen een Colt-kogel met opt-in geeft `colt_shot=true` door.

- [ ] Test hout, beton, andere wapens en cap/oudste decal.
- [ ] Voer test uit en controleer de verwachte ontbrekende Colt-effecten.
- [ ] Maak begrensde 3D-splinters/brokjes, stof en oppervlaktesporen via bestaande helpers.
- [ ] Draai regressies voor visuele effecten en de schietlogica.
- [ ] Commit.

### Task 3: Geanimeerde reviewviewer

**Files:** `tools/blender-vq2-viewer/index.html`, `src.js`, `style.css`, `viewer.js`, `test-colt-vfx.mjs`, `README.md`.

**Interfaces:** Viewer-selectie `m1911`, echte GLB-clip `M1911_schot`, keuze muur/boom, animatiebediening en testhook `__VQ2_TEST__.coltVfx()`.

- [ ] Test dat muur/boom en tijdlijn zichtbaar zijn en dat de slede beweegt.
- [ ] Bouw een 3D-schotdemo met atlasflits, baan en materiaaleffecten in de bestaande viewer.
- [ ] Bouw de browserbundle en test de viewer in Chromium met screenshots.
- [ ] Commit en push naar Draft PR #269; toon de preview voor review zonder merge.
