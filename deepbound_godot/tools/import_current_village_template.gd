extends SceneTree

const PrefabTemplateImporter = preload("res://scripts/systems/PrefabTemplateImporter.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if PrefabTemplateImporter.import_current_goblin_village(PrefabTemplateImporter.DEFAULT_GOBLIN_TEMPLATE_PATH, true):
		print("Imported goblin village template to %s" % PrefabTemplateImporter.DEFAULT_GOBLIN_TEMPLATE_PATH)
		quit(0)
	else:
		print("Failed to import goblin village template.")
		quit(1)
