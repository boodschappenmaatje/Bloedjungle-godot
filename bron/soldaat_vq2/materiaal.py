"""Gedeeld PBR-materiaal (albedo, OpenGL-normal, ORM) voor de VQ2-soldaat."""

import bpy


def material(name, imgs):
    m = bpy.data.materials.new(name)
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    a = nt.nodes.new("ShaderNodeTexImage")
    a.image = imgs["albedo"]
    nt.links.new(a.outputs["Color"], bsdf.inputs["Base Color"])
    nm = nt.nodes.new("ShaderNodeTexImage")
    nm.image = imgs["normal"]
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(nm.outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    o = nt.nodes.new("ShaderNodeTexImage")
    o.image = imgs["orm"]
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(o.outputs["Color"], sep.inputs[0])
    nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    return m
