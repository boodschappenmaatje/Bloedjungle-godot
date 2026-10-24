@tool
extends Resource
class_name ArcadeVfxProfile
## Instelbaar, visueel profiel voor de geïsoleerde M1911 VFX-labscène.

@export_group("Tracer")
@export_range(0.5, 10.0, 0.1, "suffix:m") var tracer_length := 4.8
@export_range(0.01, 0.25, 0.005, "suffix:m") var tracer_width := 0.062
@export_range(0.25, 2.5, 0.05) var tracer_brightness := 1.2
@export_range(0.5, 8.0, 0.1, "suffix:m") var ground_pulse_size := 3.8
@export var tracer_core_color := Color(1.0, 0.98, 0.72, 1.0)
@export var tracer_edge_color := Color(1.0, 0.7, 0.14, 0.82)
@export var tracer_tail_color := Color(1.0, 0.28, 0.035, 0.05)

@export_group("Mondingsvuur")
@export_range(0.5, 2.5, 0.05) var muzzle_size := 1.12
@export_range(0.06, 0.1, 0.005, "suffix:s") var muzzle_duration := 0.085
@export_range(0.0, 5.0, 0.1) var light_intensity := 2.8
@export_range(0.0, 1.5, 0.05) var smoke_intensity := 0.65

@export_group("Terugslag en inslag")
@export_range(0.5, 3.0, 0.05) var recoil_strength := 1.45
@export_range(0.25, 2.5, 0.05) var impact_intensity := 1.35
