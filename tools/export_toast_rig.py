"""Bakes the 3D toast (pet-3d/06_拆件绑骨) into files the app can play with plain SceneKit.

The model is a part-split rigid rig: every vertex follows exactly one bone, so it is five
rigid parts (body, two arms, two legs). This script writes, into the output folder:

  toast_rig.bin   per part: interleaved float32 [pos3 normal3 uv2 tangent4] + uint32 indices,
                  in the part bone's local space (Y up, like glTF)
  toast_rig.json  part layout in the .bin, rest pose, and each clip as per-frame bone
                  transforms [tx ty tz qx qy qz qw] in model space
  toast_color.jpg / toast_normal.png / toast_orm.jpg   the PBR textures

Run with Blender 3.4+:
  Blender -b --python tools/export_toast_rig.py -- <folder with the GLBs> <output folder>
"""
import bpy, bmesh, json, os, struct, sys
from mathutils import Matrix

args = sys.argv[sys.argv.index("--") + 1:]
src_dir, out_dir = args
prefix = "面包人3D_A软胶_压薄50%_拆件_"
clips = [("idle", "动画_待机放松"), ("happy", "动画_开心跳"), ("bow", "动画_鞠躬")]
parts = {
    "body": "mixamorig:Spine1",
    "armR": "mixamorig:RightArm",
    "armL": "mixamorig:LeftArm",
    "legR": "mixamorig:RightUpLeg",
    "legL": "mixamorig:LeftUpLeg",
}
FPS = 24
# Blender Z-up -> glTF / SceneKit Y-up.
C = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))


def load(clip_file):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(src_dir, prefix + clip_file + ".glb"))
    return [o for o in bpy.context.scene.objects if o.type == "ARMATURE"][0]


def r(x, n=5):
    return round(x, n)


# --- Geometry and textures, from the bind pose -------------------------------------------
arm = load(clips[0][1])
bone_to_part = {b: p for p, b in parts.items()}
rest = {p: C @ arm.matrix_world @ arm.data.bones[b].matrix_local @ C.inverted() for p, b in parts.items()}
buckets = {p: {"verts": [], "index": [], "lookup": {}} for p in parts}

for obj in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
    mesh = obj.data
    mesh.calc_tangents()
    mesh.calc_normals_split()
    mesh.calc_loop_triangles()
    groups = {g.index: g.name for g in obj.vertex_groups}
    world = C @ obj.matrix_world
    uv = mesh.uv_layers.active.data
    for tri in mesh.loop_triangles:
        for li in tri.loops:
            loop = mesh.loops[li]
            v = mesh.vertices[loop.vertex_index]
            bone = groups[max(v.groups, key=lambda g: g.weight).group]
            part = bone_to_part[bone]
            to_local = rest[part].inverted() @ world
            rot = to_local.to_3x3()
            p = to_local @ v.co
            n = (rot @ loop.normal).normalized()
            t = (rot @ loop.tangent).normalized()
            u = uv[li].uv
            vert = tuple(r(x) for x in (*p, *n, u.x, 1 - u.y, *t, loop.bitangent_sign))
            b = buckets[part]
            if vert not in b["lookup"]:
                b["lookup"][vert] = len(b["verts"])
                b["verts"].append(vert)
            b["index"].append(b["lookup"][vert])

blob = bytearray()
layout = {}
for p, b in buckets.items():
    vo = len(blob)
    for vert in b["verts"]:
        blob += struct.pack("<12f", *vert)
    io = len(blob)
    blob += struct.pack(f"<{len(b['index'])}I", *b["index"])
    layout[p] = {"vertexOffset": vo, "vertexCount": len(b["verts"]), "indexOffset": io, "indexCount": len(b["index"])}

os.makedirs(out_dir, exist_ok=True)
with open(os.path.join(out_dir, "toast_rig.bin"), "wb") as f:
    f.write(blob)

for img in bpy.data.images:
    if not img.packed_file:
        continue
    kind = "color" if img.name.startswith("Color") else "normal" if img.name.startswith("Normal") else "orm"
    ext = "png" if img.packed_file.data[:4] == b"\x89PNG" else "jpg"
    with open(os.path.join(out_dir, f"toast_{kind}.{ext}"), "wb") as f:
        f.write(img.packed_file.data)


# --- Clips: per-frame bone transforms in model space --------------------------------------
def pose(m):
    t, q, _ = m.decompose()
    return [r(t.x), r(t.y), r(t.z), r(q.x), r(q.y), r(q.z), r(q.w)]


def bake(clip_file):
    arm = load(clip_file)
    scene = bpy.context.scene
    act = arm.animation_data.action
    start, end = act.frame_range
    frames = []
    f = start
    while f <= end + 1e-4:
        scene.frame_set(int(f), subframe=f - int(f))
        frame = {}
        for p, b in parts.items():
            frame[p] = pose(C @ arm.matrix_world @ arm.pose.bones[b].matrix @ C.inverted())
        frames.append(frame)
        f += scene.render.fps / FPS
    return frames


out = {"fps": FPS, "parts": layout,
       "rest": {p: pose(m) for p, m in rest.items()},
       "clips": {}}
for name, clip_file in clips:
    frames = bake(clip_file)
    out["clips"][name] = {p: [fr[p] for fr in frames] for p in parts}
    print("clip", name, len(frames), "frames")

with open(os.path.join(out_dir, "toast_rig.json"), "w") as f:
    json.dump(out, f, separators=(",", ":"))
print("parts", {p: (l["vertexCount"], l["indexCount"] // 3) for p, l in layout.items()})
