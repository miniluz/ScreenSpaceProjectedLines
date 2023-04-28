# ScreenSpaceProjectedLines

A Godot project that converts edge-only models and applies an appropiate shader to give the lines width through screen-space projected lines and miter joints.

## How to use

Make sure `res://assets/processed/` exists. Download `res://source/code/luz-joint-import-script.gd` and attach it as an import script, then import.  That will create a mesh in that folder that you can then rename and move wherever. Use a MeshInstance3D to instantiate it. Then use `luz-joint.gdshader` as a base for writing your shader.
