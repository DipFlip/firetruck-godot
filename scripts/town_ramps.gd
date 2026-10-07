class_name TownRamps
extends Node3D

# Keep the world registry compatible with traffic, map and travel code. Maple
# Bay's experimental jump wedges and their collision geometry are removed.
var ramps: Array[StaticBody3D]=[]
