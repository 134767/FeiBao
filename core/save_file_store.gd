## Staged / recoverable text file store (no business schema knowledge).
## Not a cross-platform absolute atomic write guarantee.
class_name SaveFileStore
extends RefCounted

const SOURCE_PRIMARY: String = "PRIMARY"
const SOURCE_BACKUP: String = "BACKUP"
const SOURCE_MISSING: String = "MISSING"
const SOURCE_CORRUPT: String = "CORRUPT"

const FILE_MISSING: String = "MISSING"
const FILE_VALID: String = "VALID"
const FILE_INVALID: String = "INVALID"
const FILE_UNREADABLE: String = "UNREADABLE"

const TEST_ROOT_VIRTUAL: String = "user://feibao_tests"
const TEST_ROOT_PREFIX: String = "user://feibao_tests/"


static func temporary_path_for(primary_path: String) -> String:
	return primary_path + ".tmp"


static func backup_path_for(primary_path: String) -> String:
	return primary_path + ".bak"


## Classify an existing file using the caller-provided validator (no schema knowledge).
static func classify_file(path: String, validator: Callable) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {"state": FILE_MISSING, "text": "", "readable": false}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"state": FILE_UNREADABLE, "text": "", "readable": false}
	var text: String = f.get_as_text()
	var err: Error = f.get_error()
	f.close()
	if err != OK and err != ERR_FILE_EOF:
		return {"state": FILE_UNREADABLE, "text": "", "readable": false}
	if text.is_empty():
		return {"state": FILE_INVALID, "text": text, "readable": true}
	if _is_valid_text(text, validator):
		return {"state": FILE_VALID, "text": text, "readable": true}
	return {"state": FILE_INVALID, "text": text, "readable": true}


static func load_text(primary_path: String, validator: Callable) -> Dictionary:
	if primary_path.is_empty():
		return _load_fail(SOURCE_MISSING, "primary path is empty")
	var backup_path: String = backup_path_for(primary_path)
	var primary_info: Dictionary = classify_file(primary_path, validator)
	var backup_info: Dictionary = classify_file(backup_path, validator)
	var pstate: String = str(primary_info.get("state", FILE_MISSING))
	var bstate: String = str(backup_info.get("state", FILE_MISSING))

	if pstate == FILE_VALID:
		return {
			"ok": true,
			"text": str(primary_info.get("text", "")),
			"source": SOURCE_PRIMARY,
			"recovered_from_backup": false,
			"error": "",
		}
	if bstate == FILE_VALID:
		return {
			"ok": true,
			"text": str(backup_info.get("text", "")),
			"source": SOURCE_BACKUP,
			"recovered_from_backup": true,
			"error": "recovered from backup",
		}
	if pstate == FILE_MISSING and bstate == FILE_MISSING:
		return _load_fail(SOURCE_MISSING, "primary and backup missing")
	return _load_fail(SOURCE_CORRUPT, "primary and backup both unavailable or invalid")


static func save_text(primary_path: String, text: String, validator: Callable) -> Dictionary:
	if primary_path.is_empty():
		return _save_fail("primary path is empty")
	if text.is_empty():
		return _save_fail("text is empty")

	var backup_path: String = backup_path_for(primary_path)
	var tmp_path: String = temporary_path_for(primary_path)

	# Classify BEFORE any write so invalid primary never overwrites a valid backup.
	var primary_info: Dictionary = classify_file(primary_path, validator)
	var backup_info: Dictionary = classify_file(backup_path, validator)
	var pstate: String = str(primary_info.get("state", FILE_MISSING))
	var bstate: String = str(backup_info.get("state", FILE_MISSING))
	var primary_bytes: String = str(primary_info.get("text", ""))
	var backup_bytes: String = str(backup_info.get("text", ""))

	# Fail-closed when no validated recovery source can be preserved/used.
	if pstate != FILE_VALID and bstate != FILE_VALID and not (pstate == FILE_MISSING and bstate == FILE_MISSING):
		# invalid/unreadable primary and/or backup without a VALID peer → do not touch files
		return _save_fail_full(
			"no validated recovery source; refusing to overwrite invalid artifacts",
			false,
			true if bstate == FILE_VALID else false,
			pstate,
			bstate
		)

	var dir_path: String = primary_path.get_base_dir()
	if not dir_path.is_empty() and not _ensure_dir(dir_path):
		return _save_fail_full("cannot create parent directory", false, false, pstate, bstate)

	if not _write_all(tmp_path, text):
		_safe_remove(tmp_path)
		return _save_fail_full("failed to write temporary file", false, false, pstate, bstate)

	var tmp_read: String = _read_all(tmp_path)
	if not _is_valid_text(tmp_read, validator):
		_safe_remove(tmp_path)
		return _save_fail_full("temporary validation failed; sources untouched", false, false, pstate, bstate)

	var backup_created: bool = false
	var backup_preserved: bool = false

	if pstate == FILE_VALID:
		# Only a validated primary may become the new backup.
		if not _write_all(backup_path, primary_bytes):
			_safe_remove(tmp_path)
			return _save_fail_full("failed to write backup from validated primary", false, false, pstate, bstate)
		var bak_check: Dictionary = classify_file(backup_path, validator)
		if str(bak_check.get("state", "")) != FILE_VALID:
			# Restore previous backup bytes if we had any readable content.
			if bstate == FILE_VALID:
				_write_all(backup_path, backup_bytes)
			_safe_remove(tmp_path)
			return _save_fail_full("backup revalidation failed; primary untouched", false, false, pstate, bstate)
		backup_created = true
	elif bstate == FILE_VALID:
		# Keep legal backup byte-for-byte; never copy invalid primary onto it.
		backup_preserved = true
	# first save (missing/missing): no backup yet

	if not _write_all(primary_path, tmp_read):
		var restored: bool = false
		if pstate == FILE_VALID:
			# Prefer restoring original primary content.
			if _write_all(primary_path, primary_bytes):
				restored = true
			elif bstate == FILE_VALID or backup_created:
				if _write_all(primary_path, backup_bytes if bstate == FILE_VALID else primary_bytes):
					restored = true
		elif bstate == FILE_VALID:
			# Do not leave a truncated primary if we can restore from backup.
			if _write_all(primary_path, backup_bytes):
				restored = true
		_safe_remove(tmp_path)
		return {
			"ok": false,
			"backup_created": backup_created,
			"backup_preserved": backup_preserved,
			"previous_primary_state": pstate,
			"previous_backup_state": bstate,
			"restore_attempted": true,
			"restore_ok": restored,
			"error": "failed to replace primary",
		}

	_safe_remove(tmp_path)
	return {
		"ok": true,
		"backup_created": backup_created,
		"backup_preserved": backup_preserved,
		"previous_primary_state": pstate,
		"previous_backup_state": bstate,
		"error": "",
	}


## Normalize and validate a test storage directory under user://feibao_tests/.
## Uses simplified path + globalized boundary checks (not string prefix alone).
static func normalize_test_storage_dir(path: String) -> Dictionary:
	if path.is_empty():
		return {"ok": false, "path": "", "error": "empty path"}
	if not path.begins_with("user://"):
		return {"ok": false, "path": "", "error": "only user:// test paths allowed"}

	var normalized: String = path.replace("\\", "/")
	if normalized.begins_with("user://"):
		var rest: String = normalized.substr(7)
		while rest.contains("//"):
			rest = rest.replace("//", "/")
		normalized = "user://" + rest

	normalized = normalized.simplify_path()
	if not normalized.begins_with("user://"):
		return {"ok": false, "path": "", "error": "path must be under user://"}

	normalized = normalized.rstrip("/")
	if normalized == TEST_ROOT_VIRTUAL:
		return {"ok": false, "path": "", "error": "test root itself is not a case path"}

	# Reject lookalike prefixes (e.g. user://feibao_tests_case) and escapes after simplify.
	if not normalized.begins_with(TEST_ROOT_PREFIX):
		return {"ok": false, "path": "", "error": "path not under user://feibao_tests/"}

	var relative: String = normalized.substr(TEST_ROOT_PREFIX.length())
	if relative.is_empty() or relative.contains(".."):
		return {"ok": false, "path": "", "error": "path escapes test root"}

	# Globalized boundary check: must remain under globalized test root.
	var global_root: String = ProjectSettings.globalize_path(TEST_ROOT_VIRTUAL).replace("\\", "/")
	var global_path: String = ProjectSettings.globalize_path(normalized).replace("\\", "/")
	global_root = global_root.simplify_path().rstrip("/")
	global_path = global_path.simplify_path().rstrip("/")
	if global_root.is_empty() or global_path.is_empty():
		return {"ok": false, "path": "", "error": "cannot globalize paths"}
	if global_path == global_root:
		return {"ok": false, "path": "", "error": "path equals test root"}
	var root_prefix: String = global_root + "/"
	if not global_path.begins_with(root_prefix):
		return {"ok": false, "path": "", "error": "global path escapes test root"}

	return {"ok": true, "path": normalized, "error": ""}

static func is_valid_test_storage_dir(path: String) -> bool:
	return bool(normalize_test_storage_dir(path).get("ok", false))


## Removes only primary/tmp/backup for a contained test primary path.
static func remove_test_artifacts(primary_path: String) -> Dictionary:
	if primary_path.is_empty():
		return {"ok": false, "error": "empty path"}
	var dir: String = primary_path.get_base_dir()
	var check: Dictionary = normalize_test_storage_dir(dir)
	if not bool(check.get("ok", false)):
		return {"ok": false, "error": "refusing cleanup outside contained test path"}
	# Ensure primary itself is the expected filename under that dir.
	var expected: String = str(check.get("path", "")).path_join("player_profile.json")
	var norm_primary: String = primary_path.replace("\\", "/").simplify_path()
	if norm_primary != expected and not norm_primary.ends_with("/player_profile.json"):
		# Allow explicit primary under validated dir.
		var parent_ok: Dictionary = normalize_test_storage_dir(norm_primary.get_base_dir())
		if not bool(parent_ok.get("ok", false)):
			return {"ok": false, "error": "primary not under contained test dir"}
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
	var err: Error = f.get_error()
	f.close()
	if err != OK and err != ERR_FILE_EOF:
		return false
	# Confirm bytes readable back match expected length at least.
	if not FileAccess.file_exists(path):
		return false
	var verify: FileAccess = FileAccess.open(path, FileAccess.READ)
	if verify == null:
		return false
	var got: String = verify.get_as_text()
	verify.close()
	return got == text


static func _ensure_dir(dir_path: String) -> bool:
	if dir_path.is_empty():
		return true
	var global_dir: String = ProjectSettings.globalize_path(dir_path)
	if DirAccess.dir_exists_absolute(global_dir):
		return true
	var err: Error = DirAccess.make_dir_recursive_absolute(global_dir)
	if err == OK:
		return true
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
	return _save_fail_full(error, false, false, "", "")


static func _save_fail_full(
	error: String,
	backup_created: bool,
	backup_preserved: bool,
	pstate: String,
	bstate: String
) -> Dictionary:
	return {
		"ok": false,
		"backup_created": backup_created,
		"backup_preserved": backup_preserved,
		"previous_primary_state": pstate,
		"previous_backup_state": bstate,
		"error": error,
	}
