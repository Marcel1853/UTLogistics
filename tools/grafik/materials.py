# Gemeinsame Materialien der Blender-Modelle (Haltestelle, Ausgaben): Principled-Material mit Umgebungsverdeckung,
# auf Wunsch Rost/Schmutz-Flecken und Leuchten.
import bpy


def material(name, color, metallic=0.85, rough=0.5, rust=0.0, emission=None):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    base = (*color, 1)
    # Umgebungsverdeckung: Ecken, Fugen und Kontaktstellen dunkler – das gibt den kräftigen Factorio-Look
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = 0.25
    ao.samples = 16
    ao.inputs["Color"].default_value = base
    nt.links.new(ao.outputs["Color"], bsdf.inputs["Base Color"])
    if rust > 0:
        # Rost und Schmutz: großes Rauschen für Flecken, feines für Körnung
        coord = nt.nodes.new("ShaderNodeTexCoord")
        big = nt.nodes.new("ShaderNodeTexNoise")
        big.inputs["Scale"].default_value = 6.0
        big.inputs["Detail"].default_value = 10.0
        big.inputs["Roughness"].default_value = 0.65
        nt.links.new(coord.outputs["Object"], big.inputs["Vector"])
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        # Anteil Rost ≈ `rust`: Rauschwerte liegen meist zwischen 0,3 und 0,7
        ramp.color_ramp.elements[0].position = 0.28 + 0.4 * rust
        ramp.color_ramp.elements[0].color = (0.16, 0.075, 0.035, 1)
        ramp.color_ramp.elements[1].position = 0.36 + 0.4 * rust
        ramp.color_ramp.elements[1].color = base
        nt.links.new(big.outputs["Fac"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], ao.inputs["Color"])
        rr = nt.nodes.new("ShaderNodeMapRange")
        rr.inputs["To Min"].default_value = rough + 0.25
        rr.inputs["To Max"].default_value = rough
        nt.links.new(big.outputs["Fac"], rr.inputs["Value"])
        nt.links.new(rr.outputs["Result"], bsdf.inputs["Roughness"])
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.15
        fine = nt.nodes.new("ShaderNodeTexNoise")
        fine.inputs["Scale"].default_value = 80.0
        nt.links.new(coord.outputs["Object"], fine.inputs["Vector"])
        nt.links.new(fine.outputs["Fac"], bump.inputs["Height"])
        nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1)
        bsdf.inputs["Emission Strength"].default_value = 8.0
    return m
