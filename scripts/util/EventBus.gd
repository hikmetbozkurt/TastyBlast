## Event Bus — Utility
## Optional shared signal bus for cross-system communication where direct
## signal connections would create tight coupling. Use sparingly — prefer
## direct signals on the relevant system when the relationship is clear.
class_name EventBus
extends RefCounted


# NOTE: This is an optional utility. If you find that all your signal
# connections are direct (System A listens to System B's signal), you may
# not need this class at all. It exists as a documented pattern in case
# a future feature benefits from a centralized event hub.
#
# Example usage (if this were an autoload):
#   EventBus.emit_signal("custom_event", data)
#   EventBus.connect("custom_event", _on_custom_event)
#
# For now, this file is a placeholder. Add custom signals here if needed
# during later phases.
