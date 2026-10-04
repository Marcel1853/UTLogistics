# Blender grafisch mit eingeschaltetem MCP-Server starten (für Live-Änderungen über Claude):
#   blender tools/grafik/utl_train_stop.blend --python tools/grafik/mcp_start.py
import bpy
import addon_utils

addon_utils.enable("blender_mcp", default_set=True, persistent=True)


def start():
    try:
        bpy.ops.blendermcp.start_server()
        print("[MCP] Server gestartet")
    except Exception as error:  # noqa: BLE001 – nur melden
        print("[MCP] Fehler:", error)
    return None


bpy.app.timers.register(start, first_interval=2.0)
