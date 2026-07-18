## Staged / recoverable text file store (no business schema knowledge).
## Not a cross-platform absolute atomic write guarantee.
class_name SaveFileStore
extends RefCounted

const SOURCE_PRIMARY: String = "PRIMARY"
const SOURCE_BACKUP: String = "BACKUP"
const SOURCE_MISSING: String = "MISSING"
const SOURCE_CORRUPT: String = "CORRUPT"


static func temporary_path_for(primary_path: String) -> String:
	return primary_path + ".tmp"


static func backup_path_for(primary_path: String) -> String:
	return primary_path + ".bak"


static func load_text(primary_path: String, validator: Callable) -> Dictionary:
	if primary_path.is_empty():
		return _load_fail(SOURCE_MISSING, "primary path is empty")
	var backup_path: String = backup_path_for(primary_path)
	var primary_exists: bool = FileAccess.file_exists(primary_path)
	var backup_exists: bool = FileAccess.file_exists(backup_path)

	if primary_exists:
		var primary_text: String = _read_all(primary_path)
		if _is_valid_text(primary_text, validator):
			return {
				"ok": true,
				"text": primary_text,
				"source": SOURCE_PRIMARY,
				"recovered_from_backup": false,
				"error": "",
			}
		if backup_exists:
			var backup_text: String = _read_all(backup_path)
			if _is_valid_text(backup_text, validator):
				return {
					"ok": true,
					"text": backup_text,
					"source": SOURCE_BACKUP,
					"recovered_from_backup": true,
					"error": "primary invalid; recovered from backup",
				}
			return _load_fail(SOURCE_CORRUPT, "primary and backup both invalid")
		return _load_fail(SOURCE_CORRUPT, "primary invalid and backup missing")

	if backup_exists:
		var only_backup: String = _read_all(backup_path)
		if _is_valid_text(only_backup, validator):
			return {
				"ok": true,
				"text": only_backup,
				"source": SOURCE_BACKUP,
				"recovered_from_backup": true,
				"error": "primary missing; recovered from backup",
			}
		return _load_fail(SOURCE_CORRUPT, "primary missing and backup invalid")

	return _load_fail(SOURCE_MISSING, "primary and backup missing")


static func save_text(primary_path: String, text: String, validator: Callable) -> Dictionary:
	if primary_path.is_empty():
		return _save_fail("primary path is empty")
	if text.is_empty():
		return _save_fail("text is empty")

	var dir_path: String = primary_path.get_base_dir()
	if not dir_path.is_empty() and not _ensure_dir(dir_path):
		return _save_fail("cannot create parent directory")

	var tmp_path: String = temporary_path_for(primary_path)
	var backup_path: String = backup_path_for(primary_path)

	if not _write_all(tmp_path, text):
		_safe_remove(tmp_path)
		return _save_fail("failed to write temporary file")

	var tmp_read: String = _read_all(tmp_path)
	if not _is_valid_text(tmp_read, validator):
		_safe_remove(tmp_path)
		return _save_fail("temporary validation failed; primary untouched")

	var backup_created: bool = false
	var primary_existed: bool = FileAccess.file_exists(primary_path)
	if primary_existed:
		var existing: String = _read_all(primary_path)
		if not _write_all(backup_path, existing):
			_safe_remove(tmp_path)
			return _save_fail("failed to preserve backup of existing primary")
		backup_created = true

	if not _write_all(primary_path, tmp_read):
		# Attempt restore from backup if we had one.
		if backup_created and FileAccess.file_exists(backup_path):
			var bak: String = _read_all(backup_path)
			_write_all(primary_path, bak)
		_safe_remove(tmp_path)
		return _save_fail("failed to replace primary")

	_safe_remove(tmp_path)
	return {
		"ok": true,
		"backup_created": backup_created,
		"error": "",
	}


## Removes only primary/tmp/backup for a known test primary path (never user:// root).
static func remove_test_artifacts(primary_path: String) -> Dictionary:
	if primary_path.is_empty():
		return {"ok": false, "error": "empty path"}
	if not primary_path.begins_with("user://feibao_tests/"):
		return {"ok": false, "error": "refusing to remove non-test path"}
	_safe_remove(primary_path)
	_safe_remove(temporary_path_for(primary_path))
	_safe_remove(backup_path_for(primary_path))
	return {"ok": true, "error": ""}


static func _is_valid_text(text: String, validator: Callable) -> bool:
	if text.is_empty():
		return false
	if not validator.is_valid():
		return false
	var result: Variant = validator.call(text)
	if typeof(result) == TYPE_BOOL:
		return bool(result)
	if typeof(result) == TYPE_DICTIONARY:
		return bool((result as Dictionary).get("ok", false))
	return false


static func _read_all(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text: String = f.get_as_text()
	f.close()
	return text


static func _write_all(path: String, text: String) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.flush()
	f.close()
	return true


static func _ensure_dir(dir_path: String) -> bool:
	if dir_path.is_empty():
		return true
	var global_dir: String = ProjectSettings.globalize_path(dir_path)
	if DirAccess.dir_exists_absolute(global_dir):
		return true
	var err: Error = DirAccess.make_dir_recursive_absolute(global_dir)
	if err == OK:
		return true
	# user:// fallback
	if dir_path.begins_with("user://"):
		var root: DirAccess = DirAccess.open("user://")
		if root == null:
			return false
		var rel: String = dir_path.trim_prefix("user://")
		return root.make_dir_recursive(rel) == OK or DirAccess.dir_exists_absolute(global_dir)
	return false


static func _safe_remove(path: String) -> void:
	if path.is_empty():
		return
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _load_fail(source: String, error: String) -> Dictionary:
	return {
		"ok": false,
		"text": "",
		"source": source,
		"recovered_from_backup": false,
		"error": error,
	}


static func _save_fail(error: String) -> Dictionary:
	return {
		"ok": false,
		"backup_created": false,
		"error": error,
	}
