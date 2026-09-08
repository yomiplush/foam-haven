@tool
extends SceneTree
func _initialize():
	var action_map = OpenXRActionMap.new()
	action_map.create_default_action_sets()
	ResourceSaver.save(action_map, "res://openxr_action_map.tres")
	var settings = EditorInterface.get_editor_settings()
	settings.set_setting("export/android/java_sdk_path", "/home/yomiplush/android/jdk")
	settings.set_setting("export/android/android_sdk_path", "/home/yomiplush/android/sdk")
	quit()
