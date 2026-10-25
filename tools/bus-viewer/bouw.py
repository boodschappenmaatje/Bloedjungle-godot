"""Bouwt de telefoonviewer (één HTML-bestand met het GLB ingebed): python3 tools/bus-viewer/bouw.py uit.html"""
import base64, sys, pathlib
d = pathlib.Path(__file__).parent
t = (d / "sjabloon.html").read_text().replace("__FX__", (d / "effecten.js").read_text()).replace("__TRIS__", sys.argv[2] if len(sys.argv) > 2 else "10.883")
glb = base64.b64encode((d / "../../assets/bus.glb").read_bytes()).decode()
pathlib.Path(sys.argv[1]).write_text(t.replace("__GLB__", glb))
