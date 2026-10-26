"""Actie-animaties voor het mannetje (assets/soldaat.glb): "rollen" (ontwijkrol), "sprinten" en een nieuwe, snelle "herladen".
Gebruik:  python3 maak_acties.py uit/    -> uit/acties.blend en uit/acties.glb (alleen skelet + de drie animaties)

Alle houdingen worden opgebouwd op de bestaande houdingen van het mannetje ("stil" en "rennen"), zodat de stijl past.
Ruimte van het skelet: -Y is vooruit, +Z omhoog, +X is links van het mannetje.
 - draaien om +X kantelt iets dat omhoog wijst naar voren, en zwaait iets dat omlaag wijst naar achteren
 - de gun-montage in het spel is vast aan de rechterhand in de "stil"-houding (soldier_model.gd), dus de rechterhand
   moet het geweer in elke houding netjes dicht bij het lijf houden."""
import sys, os, math, bpy
from mathutils import Vector, Matrix

out = sys.argv[1] if len(sys.argv) > 1 else "uit/"
os.makedirs(out, exist_ok=True)
here = os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(here, "../../assets/soldaat.glb"))
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
bpy.context.view_layer.objects.active = arm
scene = bpy.context.scene
scene.render.fps = 30
pose = arm.pose.bones
ORDER = [b.name for b in arm.data.bones]
for _a in list(bpy.data.actions):
    _a.name = "basis_" + _a.name          # zodat onze nieuwe acties hun eigen naam krijgen (o.a. "herladen")
base_actions = {a.name[len("basis_"):]: a for a in bpy.data.actions}
arm.animation_data_create()


def upd():
    bpy.context.view_layer.update()


# ---------- de houdingen waarop we bouwen, vooraf uitgelezen ----------
def sample(action, frame):
    arm.animation_data.action = base_actions[action]
    if arm.animation_data.action.slots:
        arm.animation_data.action_slot = arm.animation_data.action.slots[0]
    scene.frame_set(frame)
    upd()
    return {pb.name: pb.matrix_basis.copy() for pb in pose}


BASE_STIL = sample("stil", 1)
BASE_RUN = [sample("rennen", f) for f in range(16)]
arm.animation_data.action = None
bpy.ops.object.mode_set(mode='POSE')


def apply(basis):
    for n in ORDER:
        pose[n].matrix_basis = basis[n]
    upd()


def aim(name, d):
    """Draai bot `name` zodat hij langs richting d wijst (met zo min mogelijk draaiing, zoals in maak_klimmen.py)."""
    pb = pose[name]
    head = pb.matrix.translation.copy()
    cur = pb.matrix.to_3x3()
    ydir = cur.col[1]
    q = Vector(ydir).rotation_difference(Vector(d).normalized())
    pb.matrix = Matrix.Translation(head) @ (q.to_matrix() @ cur).to_4x4()
    upd()


def rot(name, axis, deg, pivot=None):
    """Draai bot `name` om een as van de ruimte van het skelet, door zijn kop (of `pivot`)."""
    pb = pose[name]
    m = pb.matrix.copy()
    p = Vector(pivot) if pivot is not None else m.translation.copy()
    r = Matrix.Rotation(math.radians(deg), 4, axis)
    pb.matrix = Matrix.Translation(p) @ r @ Matrix.Translation(-p) @ m
    upd()


def shift(name, d):
    pb = pose[name]
    pb.matrix = Matrix.Translation(Vector(d)) @ pb.matrix
    upd()


def head_of(name):
    return pose[name].matrix.translation.copy()


def tail_of(name):
    pb = pose[name]
    return pb.matrix.translation + pb.matrix.to_3x3().col[1] * pb.length


L1 = 0.274   # bovenarm
L2 = 0.273   # onderarm


def arm_to(side, target, hint):
    """Twee-botten-IK voor de arm: de hand naar `target`, de elleboog zo ver mogelijk naar `hint` (richting)."""
    s = "L" if side > 0 else "R"
    S = head_of(f"DEF-upper_arm{s}")
    T = Vector(target)
    d = T - S
    dist = min(d.length, (L1 + L2) * 0.999)
    dn = d.normalized()
    a = (L1 * L1 - L2 * L2 + dist * dist) / (2 * dist)
    h = math.sqrt(max(L1 * L1 - a * a, 0.0))
    hv = Vector(hint) - dn * Vector(hint).dot(dn)
    hv = hv.normalized() if hv.length > 1e-6 else Vector((0, 0, -1))
    E = S + dn * a + hv * h
    aim(f"DEF-upper_arm{s}", E - S)
    aim(f"DEF-forearm{s}", T - E)


CUR = {"act": None}


def key(frame):
    # de actie hangt alleen tijdens het sleutelen aan het skelet: anders overschrijft hij de houding die we opbouwen
    arm.animation_data.action = CUR["act"]
    for pb in pose:
        pb.rotation_mode = 'QUATERNION'
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        pb.keyframe_insert("location", frame=frame)
    saved = {pb.name: pb.matrix_basis.copy() for pb in pose}
    arm.animation_data.action = None
    for n in ORDER:
        pose[n].matrix_basis = saved[n]
    upd()


def new_action(name, length):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    act.frame_range = (0, length)
    CUR["act"] = act
    arm.animation_data.action = None
    return act


def finish(act):
    for fc in act.layers[0].strips[0].channelbags[0].fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = 'BEZIER'
            kp.handle_left_type = kp.handle_right_type = 'AUTO_CLAMPED'


X, Y, Z = 'X', 'Y', 'Z'
HIPS = "DEF-hips"
SPINE = ("DEF-spine001", "DEF-spine002", "DEF-spine003")


def smooth(t):
    return t * t * (3 - 2 * t)


# =====================================================================================================
# ROLLEN: een koprol vooruit (0,5 s). Opgetrokken knieën, geweer tegen de borst, landing in de hurk.
# =====================================================================================================
ROLL_FRAMES = 15


def roll_pose(f):
    apply(BASE_STIL)
    # fases (0..1 over de rol): 0-0.2 inzet (hurken), 0.2-0.8 koprol, 0.8-1 landing en opkomen
    # hoeveel opgerold: 0 = recht, 1 = helemaal opgevouwen
    tuck_keys = {0: 0.0, 2: 0.55, 4: 1.0, 10: 1.0, 12: 0.75, 14: 0.35, 15: 0.1}
    spin_keys = {0: 0, 2: 12, 4: 55, 6: 130, 8: 210, 10: 285, 12: 340, 14: 360, 15: 360}
    drop_keys = {0: 0.0, 2: -0.22, 4: -0.34, 6: -0.36, 8: -0.36, 10: -0.34, 12: -0.32, 14: -0.18, 15: -0.05}

    def interp(keys):
        ks = sorted(keys)
        for i in range(len(ks) - 1):
            a, b = ks[i], ks[i + 1]
            if a <= f <= b:
                t = (f - a) / (b - a)
                return keys[a] + (keys[b] - keys[a]) * smooth(t)
        return keys[ks[-1]]

    tuck = interp(tuck_keys)
    spin = interp(spin_keys)
    drop = interp(drop_keys)
    # opgevouwen: romp krult naar voren, kin op de borst, knieën omhoog en hielen naar de billen
    for n in SPINE:
        rot(n, X, 22 * tuck)
    rot("DEF-neck", X, 20 * tuck)
    rot("DEF-head", X, 15 * tuck)
    for s in ("L", "R"):
        rot(f"DEF-thigh{s}", X, -(35 + 75 * tuck))   # knie omhoog (naar voren)
        rot(f"DEF-shin{s}", X, 20 + 120 * tuck)       # hiel naar de bil
        rot(f"DEF-foot{s}", X, -25 * tuck)
    # armen: het geweer blijft tegen de borst, de elleboog gaat mee naar binnen
    rot("DEF-upper_armR", X, 15 * tuck, pivot=head_of("DEF-upper_armR"))
    rot("DEF-upper_armL", X, 15 * tuck, pivot=head_of("DEF-upper_armL"))
    # hele lichaam: om het zwaartepunt (heup) draaien, de heup beschrijft een boog
    pivot = head_of(HIPS) + Vector((0, 0, 0.05))
    rot(HIPS, X, spin, pivot=pivot)
    shift(HIPS, (0, 0, drop + 0.12 * math.sin(math.radians(min(max(spin, 0), 360) / 2)) * 0.0))


act = new_action("rollen", ROLL_FRAMES)
for f in (0, 2, 4, 6, 8, 10, 12, 14, 15):
    roll_pose(f)
    key(f)
finish(act)


# =====================================================================================================
# SPRINTEN: de bestaande ren-lus, maar sneller, voorovergebogen, met grotere stappen en lage heup (16 frames = 0,53 s)
# =====================================================================================================
act = new_action("sprinten", 16)
for f in range(17):
    apply(BASE_RUN[f % 16])
    # voorover
    for n in SPINE:
        rot(n, X, 6.5)
    rot("DEF-neck", X, -9)
    rot("DEF-head", X, -11)
    # grotere stappen: de beenhoek vooruit/achteruit met 30% vergroten
    for s in ("L", "R"):
        pb = pose[f"DEF-thigh{s}"]
        d = pb.matrix.to_3x3().col[1]
        fwd = math.degrees(math.atan2(-d.y, -d.z))   # 0 = recht omlaag, + = knie naar voren
        rot(f"DEF-thigh{s}", X, -0.30 * fwd)
    shift(HIPS, (0, -0.03, -0.07))
    key(f)
finish(act)


# =====================================================================================================
# HERLADEN: 1,2 s. Geweer zakt naar de borst, linkerhand pakt een magazijn van het koppel, klikt het erin,
# trekt het grendel naar achteren en brengt het geweer weer omhoog.
# =====================================================================================================
RELOAD_FRAMES = 36


apply(BASE_STIL)
P_HAND_L = head_of("DEF-handL")
P_HAND_R = head_of("DEF-handR")
HIPS_P = head_of(HIPS)
G0 = Vector((0, -1, 0))                       # het geweer wijst in de stilstaande houding recht vooruit
U0 = Vector((0, 0, 1))
S0 = U0.cross(G0)                             # naar links
GUN_LOCAL = pose["DEF-handR"].matrix.to_3x3().inverted() @ G0   # de loop in de ruimte van de hand
rel = P_HAND_L - P_HAND_R
FORE = (rel.dot(G0), rel.dot(U0), rel.dot(S0))  # waar de linkerhand het geweer vasthoudt (langs, boven, opzij)
POUCH = Vector((0.20, HIPS_P.y - 0.14, HIPS_P.z + 0.03))        # magazijntas voor op de linkerheup


def gun_state(f):
    """Positie van de rechterhand, richting van de loop en 'boven' van het geweer op tijdstip f."""
    gp = keyed(gun_pitch, f)
    gd = keyed(gun_drop, f)
    pr = P_HAND_R + Vector((0, 0.03 * (gd / 0.10), -gd))
    g = (Matrix.Rotation(math.radians(gp), 3, 'X') @ G0).normalized()
    u = (U0 - g * U0.dot(g)).normalized()
    s = u.cross(g)
    return pr, g, u, s


def on_gun(f, along, up, side):
    pr, g, u, s = gun_state(f)
    return pr + g * along + u * up + s * side


def lerp(a, b, t):
    return a + (b - a) * t


def keyed(keys, f):
    ks = sorted(keys)
    for i in range(len(ks) - 1):
        a, b = ks[i], ks[i + 1]
        if a <= f <= b:
            t = smooth((f - a) / (b - a))
            return keys[a].lerp(keys[b], t) if isinstance(keys[a], Vector) else lerp(keys[a], keys[b], t)
    return keys[ks[-1]]


gun_pitch = {0: 0.0, 3: -4.0, 6: -14.0, 16: -14.0, 21: -18.0, 24: -8.0, 29: -8.0, 33: -2.0, 36: 0.0}   # loop omhoog (negatief = omhoog)
gun_drop = {0: 0.0, 5: 0.10, 16: 0.10, 22: 0.06, 28: 0.04, 33: 0.0, 36: 0.0}
lean = {0: 0.0, 8: 4.0, 12: 6.0, 20: 5.0, 28: 3.0, 36: 0.0}
head_look = {0: 0.0, 8: 12.0, 20: 10.0, 28: 4.0, 36: 0.0}

# linkerhand: voorgreep -> magazijntas -> magazijn in het geweer -> grendel -> voorgreep. De doelen onder en bij het
# geweer zijn ten opzichte van het geweer (dat zakt en kantelt), die bij het lichaam in de ruimte van het skelet.
lt = {
    0: on_gun(0, *FORE),
    4: on_gun(4, FORE[0] * 0.8, FORE[1] - 0.10, FORE[2] + 0.04),
    9: POUCH,
    12: POUCH + Vector((0.01, 0.0, 0.02)),
    18: on_gun(18, FORE[0] * 0.5, FORE[1] - 0.20, 0.0),
    20: on_gun(20, FORE[0] * 0.45, FORE[1] - 0.13, 0.0),
    21: on_gun(21, FORE[0] * 0.45, FORE[1] - 0.10, 0.0),
    24: on_gun(24, 0.12, 0.075, 0.03),
    27: on_gun(27, -0.02, 0.075, 0.03),
    29: on_gun(29, 0.12, 0.075, 0.03),
    33: on_gun(33, *FORE),
    36: on_gun(36, *FORE),
}

act = new_action("herladen", RELOAD_FRAMES)
for f in (0, 2, 4, 6, 9, 12, 15, 18, 20, 21, 24, 27, 29, 33, 36):
    apply(BASE_STIL)
    for n in SPINE:
        rot(n, X, keyed(lean, f) / 3)
    rot("DEF-head", X, keyed(head_look, f))
    # rechterarm: geweer zakt wat en de loop kantelt omhoog (de hand bepaalt de richting van het wapen)
    pr, g, u, s = gun_state(f)
    arm_to(-1, pr, Vector((-0.4, 0.6, -1.0)))
    hand = pose["DEF-handR"]
    cur = hand.matrix.to_3x3() @ GUN_LOCAL
    q = cur.rotation_difference(g)
    head = hand.matrix.translation.copy()
    hand.matrix = Matrix.Translation(head) @ (q.to_matrix() @ hand.matrix.to_3x3()).to_4x4()
    upd()
    # linkerarm: IK naar het doel van deze stand
    arm_to(1, keyed(lt, f), Vector((0.5, 0.5, -1.0)))
    key(f)
finish(act)

# =====================================================================================================
# EXPLOSIE_DOOD: weggeslingerd door een ontploffing (1,33 s). Het spel verplaatst het mannetje zelf langs een boog
# (enemy.gd); deze animatie doet de houding: rug gekromd, armen en benen wild, op de rug landen en blijven liggen.
# Frames: 0-16 in de lucht (landing rond frame 16), 16-24 neerploffen en glijden, 24-40 laatste uitrollen.
# =====================================================================================================
BLAST_FRAMES = 40
b_pitch = {0: 0.0, 2: -18.0, 6: -58.0, 11: -84.0, 15: -96.0, 18: -91.0, 24: -88.0, 40: -88.0}   # hele lichaam naar achteren (om de heup)
b_drop = {0: 0.0, 5: 0.02, 12: 0.0, 15: -0.30, 18: -0.74, 21: -0.80, 24: -0.78, 40: -0.78}       # heup zakt naar de grond bij de landing
b_arm = {0: 0.0, 2: -45.0, 6: -150.0, 12: -168.0, 16: -150.0, 20: -112.0, 26: -85.0, 40: -75.0}  # armen zwaaien omhoog/naar achteren
b_spread = {0: 0.0, 4: 28.0, 12: 42.0, 20: 32.0, 40: 18.0}
b_thL = {0: 0.0, 4: 38.0, 10: 62.0, 16: 28.0, 22: 10.0, 40: 6.0}    # linkerbeen: knie omhoog
b_thR = {0: 0.0, 4: -18.0, 10: -34.0, 16: 20.0, 22: 12.0, 40: 8.0}  # rechterbeen: schopt naar achteren
b_shL = {0: 0.0, 4: 30.0, 10: 78.0, 16: 40.0, 22: 16.0, 40: 10.0}
b_shR = {0: 0.0, 4: 18.0, 10: 52.0, 16: 36.0, 22: 14.0, 40: 10.0}
b_neck = {0: 0.0, 3: -26.0, 8: -32.0, 16: -22.0, 24: -10.0, 40: -6.0}
b_spine = {0: 0.0, 3: -12.0, 8: -15.0, 16: -9.0, 24: 0.0, 40: 0.0}   # gekromde rug

act = new_action("explosie_dood", BLAST_FRAMES)
for f in (0, 2, 4, 6, 8, 11, 13, 15, 16, 18, 20, 22, 24, 28, 34, 40):
    apply(BASE_STIL)
    for n in SPINE:
        rot(n, X, keyed(b_spine, f))
    rot("DEF-neck", X, keyed(b_neck, f))
    rot("DEF-head", X, keyed(b_neck, f) * 0.6)
    for s_, sign in (("L", 1.0), ("R", -1.0)):
        ua = f"DEF-upper_arm{s_}"
        rot(ua, X, keyed(b_arm, f), pivot=head_of(ua))
        rot(ua, Z, sign * keyed(b_spread, f), pivot=head_of(ua))
    rot("DEF-thighL", X, keyed(b_thL, f))
    rot("DEF-thighR", X, keyed(b_thR, f))
    rot("DEF-shinL", X, keyed(b_shL, f))
    rot("DEF-shinR", X, keyed(b_shR, f))
    pivot = head_of(HIPS) + Vector((0, 0, 0.05))
    rot(HIPS, X, keyed(b_pitch, f), pivot=pivot)
    shift(HIPS, (0, 0, keyed(b_drop, f)))
    key(f)
finish(act)

# =====================================================================================================
# BRAND_RENNEN: in brand gestoken door napalm (lus van 16 beelden = 0,53 s). De rennende lus van het mannetje, maar de armen
# slaan wild boven het hoofd, de romp helt achterover en de kop schudt van links naar rechts.
# BRAND_VAL: na het rennen bezwijkt hij (1 s): de knieën knikken, hij valt voorover, blijft liggen en trilt na.
# =====================================================================================================
FIRE_FRAMES = 16
act = new_action("brand_rennen", FIRE_FRAMES)
for f in range(FIRE_FRAMES + 1):
    apply(BASE_RUN[f % 16])
    ph = 2 * math.pi * f / FIRE_FRAMES
    for n in SPINE:
        rot(n, X, -9.0)
    rot("DEF-neck", Z, 18.0 * math.sin(ph * 2), pivot=head_of("DEF-neck"))
    rot("DEF-head", X, -14.0)
    for s_, sign in (("L", 1.0), ("R", -1.0)):
        ua = f"DEF-upper_arm{s_}"
        fa = f"DEF-forearm{s_}"
        side_ph = ph + (0.0 if s_ == "L" else math.pi)
        rot(ua, X, -150.0 + 22.0 * math.sin(side_ph), pivot=head_of(ua))       # handen hoog, om en om slaand
        rot(ua, Z, sign * (28.0 + 18.0 * math.cos(side_ph)), pivot=head_of(ua))
        rot(fa, X, -35.0 + 30.0 * math.sin(side_ph + 1.2), pivot=head_of(fa))
    key(f if f < FIRE_FRAMES else FIRE_FRAMES)
finish(act)

FALL_FRAMES = 32
f_pitch = {0: -4.0, 6: 8.0, 12: 34.0, 18: 82.0, 21: 94.0, 24: 90.0, 32: 90.0}      # romp voorover, uiteindelijk plat op de buik
f_drop = {0: 0.0, 6: -0.22, 12: -0.42, 18: -0.62, 21: -0.78, 24: -0.76, 32: -0.76}
f_thigh = {0: 10.0, 6: 55.0, 12: 62.0, 18: 38.0, 24: 14.0, 32: 10.0}
f_shin = {0: 25.0, 6: 105.0, 12: 120.0, 18: 70.0, 24: 20.0, 32: 16.0}               # eerst op de knieën, dan uitgestrekt
f_arm = {0: -150.0, 6: -120.0, 12: -80.0, 18: -150.0, 21: -170.0, 24: -165.0, 32: -165.0}   # armen vooruit gestrekt op de grond
act = new_action("brand_val", FALL_FRAMES)
for f in (0, 3, 6, 9, 12, 15, 18, 21, 24, 26, 28, 30, 32):
    apply(BASE_STIL)
    twitch = math.sin(f * 1.9) * (1.0 - smooth(min(1.0, max(0.0, (f - 22) / 10.0)))) * (f >= 22)
    for n in SPINE:
        rot(n, X, 6.0 * min(1.0, f / 12.0))
    rot("DEF-neck", X, 10.0 + 8.0 * twitch)
    for s_, sign in (("L", 1.0), ("R", -1.0)):
        ua = f"DEF-upper_arm{s_}"
        rot(ua, X, keyed(f_arm, f) + 7.0 * twitch, pivot=head_of(ua))
        rot(ua, Z, sign * (30.0 + 10.0 * twitch), pivot=head_of(ua))
    rot("DEF-thighL", X, keyed(f_thigh, f))
    rot("DEF-thighR", X, keyed(f_thigh, f) * 0.8)
    rot("DEF-shinL", X, keyed(f_shin, f))
    rot("DEF-shinR", X, keyed(f_shin, f) * 0.85)
    pivot = head_of(HIPS) + Vector((0, 0, 0.05))
    rot(HIPS, X, keyed(f_pitch, f), pivot=pivot)
    shift(HIPS, (0, 0, keyed(f_drop, f)))
    key(f)
finish(act)

scene.frame_start, scene.frame_end = 0, 40
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "acties.blend"))

# alleen skelet + animaties naar glb: de game haalt de filmpjes eruit en hangt ze aan het mannetje
for o in list(bpy.data.objects):
    if o.type == 'MESH':
        bpy.data.objects.remove(o)
for a in list(bpy.data.actions):
    if a.name not in ("rollen", "sprinten", "herladen", "explosie_dood", "brand_rennen", "brand_val"):
        bpy.data.actions.remove(a)
bpy.ops.export_scene.gltf(filepath=os.path.join(out, "acties.glb"), export_format='GLB', export_animation_mode='ACTIONS', export_force_sampling=True, export_apply=False)
print("KLAAR", sorted(a.name for a in bpy.data.actions))
