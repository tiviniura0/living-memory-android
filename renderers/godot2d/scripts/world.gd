extends Node2D

var bridge: Object
var engine_version := ""

func _ready() -> void:
    if not Engine.has_singleton("LivingWorldRender"):
        return # Headless import is not an Android ready event.
    bridge = Engine.get_singleton("LivingWorldRender")
    engine_version = str(Engine.get_version_info()["string"])
    bridge.connect("host_command", _on_host_command)
    $Status.text = "Godot " + engine_version + "\nScène de test native — aucune simulation"
    bridge.sceneEvent("", "boot", engine_version)

func _on_host_command(session: String, action: String, nonce: String) -> void:
    if action == "open":
        bridge.sceneEvent(session, "ready", engine_version)
    elif action == "probe":
        bridge.sceneEvent(session, "probe", nonce)
