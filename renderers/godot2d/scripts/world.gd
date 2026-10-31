extends Node2D

var bridge: Object
var engine_version := ""
var active_session := ""

func _ready() -> void:
    get_viewport().size_changed.connect(queue_redraw)
    if not Engine.has_singleton("LivingWorldRender"):
        return # Headless import is not an Android ready event.
    bridge = Engine.get_singleton("LivingWorldRender")
    engine_version = str(Engine.get_version_info()["string"])
    bridge.connect("host_command", _on_host_command)
    $Status.text = "Godot " + engine_version + "\nScène de test native — aucune simulation"
    bridge.sceneEvent("", "boot", engine_version)

func _on_host_command(session: String, action: String, nonce: String) -> void:
    if action == "open":
        active_session = session
        bridge.sceneEvent(session, "ready", engine_version)
    elif action == "probe":
        bridge.sceneEvent(session, "probe", nonce)

# Deterministic visual signature: a real Canvas draw must reach the native
# screenshot. A boot callback or a clear-colored Surface is insufficient.
func _draw() -> void:
    draw_rect(Rect2(get_viewport_rect().get_center() - Vector2(16, 16), Vector2(32, 32)), Color.MAGENTA)

func _input(event: InputEvent) -> void:
    if bridge == null or active_session.is_empty():
        return
    if event is InputEventScreenTouch and event.pressed:
        $Status.text = "Godot " + engine_version + "\nScène de test native — aucune simulation\nAppui natif reçu"
        bridge.sceneEvent(active_session, "probe", "native-touch")
