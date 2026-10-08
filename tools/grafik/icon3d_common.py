"""Gemeinsames für die 3D-Signal-Grundbilder (Stil „3D“): Materialien, Bausteine, Kamera, Licht, Render.

Licht und Kamera nach der Vorlage des Skills meshy-blender-spritesheet (Licht von links oben,
orthografische Kamera, transparenter Hintergrund, Cycles), Blickwinkel wie die Vanilla-Item-Icons.
Farben aus den Vanilla-Icons gemessen (Lok-Rot ≈ 110/43/42, Wagen-Grau ≈ 84/67/66 … 184).
"""
import math

import bpy


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def srgb(c):
    """sRGB 0–255 → lineare Farbe für Blender."""
    def ch(v):
        v = v / 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    return (ch(c[0]), ch(c[1]), ch(c[2]))


def material(name, rgb, metallic=0.25, roughness=0.55, emission=None, strength=0.0, grime=True):
    """Principled-Material; `grime` = fleckiger Schmutz wie bei den Vanilla-Icons."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*srgb(rgb), 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*srgb(emission), 1)
        bsdf.inputs["Emission Strength"].default_value = strength
    elif grime:
        # Metall-Optik wie bei Factorio statt Holz-Maserung: Umgebungsverdeckung dunkelt Ecken und
        # Fugen ab, Kanten (Pointiness) werden leicht heller (abgegriffen), dazu nur grobe, schwache
        # Fleckigkeit ohne Streifen.
        base = nodes.new("ShaderNodeRGB")
        base.outputs[0].default_value = (*srgb(rgb), 1)
        ao = nodes.new("ShaderNodeAmbientOcclusion")
        ao.inputs["Distance"].default_value = 0.35
        ao_ramp = nodes.new("ShaderNodeValToRGB")
        ao_ramp.color_ramp.elements[0].color = (0.35, 0.33, 0.32, 1)
        links.new(ao.outputs["AO"], ao_ramp.inputs["Fac"])
        geo = nodes.new("ShaderNodeNewGeometry")
        edge = nodes.new("ShaderNodeValToRGB")
        edge.color_ramp.elements[0].position = 0.5
        edge.color_ramp.elements[0].color = (1, 1, 1, 1)
        edge.color_ramp.elements[1].position = 0.56
        edge.color_ramp.elements[1].color = (1.45, 1.4, 1.35, 1)
        links.new(geo.outputs["Pointiness"], edge.inputs["Fac"])
        noise = nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 2.5
        noise.inputs["Detail"].default_value = 2.0
        spot = nodes.new("ShaderNodeValToRGB")
        spot.color_ramp.elements[0].color = (0.82, 0.8, 0.78, 1)
        links.new(noise.outputs["Fac"], spot.inputs["Fac"])
        prev = base.outputs[0]
        for factor in (ao_ramp.outputs["Color"], edge.outputs["Color"], spot.outputs["Color"]):
            mix = nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs["Factor"].default_value = 1.0
            links.new(prev, mix.inputs["A"])
            links.new(factor, mix.inputs["B"])
            prev = mix.outputs["Result"]
        links.new(prev, bsdf.inputs["Base Color"])
    return mat


def box(size, location, mat, bevel=0.03, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location, rotation=rot)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        mod = obj.modifiers.new("fase", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    obj.data.materials.append(mat)
    return obj


def cylinder(radius, depth, location, mat, rot=(0, 0, 0), vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rot)
    obj = bpy.context.object
    obj.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return obj


def wheel(location, mat_tire, mat_hub, radius=0.32, width=0.18):
    """Rad quer zur Fahrtrichtung (Achse entlang Y)."""
    cylinder(radius, width, location, mat_tire, (math.radians(90), 0, 0))
    cylinder(radius * 0.45, width + 0.04, location, mat_hub, (math.radians(90), 0, 0), 12)


def render(out, size=256, target=(0, 0, 1.0), ortho=5.0, elev=30, yaw=-38, samples=96):
    """Kamera schräg von vorn oben auf `target`, Licht links oben, transparent rendern."""
    scene = bpy.context.scene
    bpy.ops.object.empty_add(location=target)
    aim = bpy.context.object
    bpy.ops.object.camera_add()
    cam = bpy.context.object
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho
    e, y, dist = math.radians(elev), math.radians(yaw), 16
    cam.location = (target[0] + dist * math.cos(e) * math.sin(y), target[1] - dist * math.cos(e) * math.cos(y),
                    target[2] + dist * math.sin(e))
    track = cam.constraints.new("TRACK_TO")
    track.target = aim
    track.track_axis = "TRACK_NEGATIVE_Z"
    track.up_axis = "UP_Y"
    scene.camera = cam
    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(45), 0, math.radians(-60)))
    bpy.context.object.data.energy = 7.0
    bpy.ops.object.light_add(type="AREA", location=(6, -4, 6))
    bpy.context.object.data.energy = 900
    bpy.context.object.data.size = 5
    world = bpy.data.worlds.new("welt")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Strength"].default_value = 1.1
    # Verlauf hell oben / dunkel unten: Metallflächen bekommen Spiegelungen statt flacher Farbe
    grad = world.node_tree.nodes.new("ShaderNodeTexGradient")
    coord = world.node_tree.nodes.new("ShaderNodeTexCoord")
    sep = world.node_tree.nodes.new("ShaderNodeSeparateXYZ")
    ramp = world.node_tree.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (0.08, 0.075, 0.07, 1)
    ramp.color_ramp.elements[1].color = (0.75, 0.78, 0.82, 1)
    world.node_tree.links.new(coord.outputs["Generated"], sep.inputs[0])
    world.node_tree.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    world.node_tree.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    scene.world = world
    scene.render.engine = "CYCLES"
    scene.cycles.samples = samples
    scene.render.film_transparent = True
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    print("Icon gerendert:", out)
