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

const SNAPSHOT_KIND: String = "save_artifact_snapshot_v2"

const TEST_ROOT_VIRTUAL: String = "user://feibao_tests"
const TEST_ROOT_PREFIX: String = "user://feibao_tests/"

## Tests-only write failure seam. Empty = production default (never fail).
## Allowed: "tmp_write" | "backup_write" | "primary_write"
static var _test_write_fail_step: String = ""
## Tests-only restore failure seam for observability.
static var _test_restore_fail: bool = false


static func temporary_path_for(primary_path: String) -> String:
	return primary_path + ".tmp"


static func backup_path_for(primary_path: String) -> String:
	return primary_path + ".bak"


static func set_test_write_failure_step(step: String) -> void:
	_test_write_fail_step = step


static func clear_test_write_failure_step() -> void:
	_test_write_fail_step = ""


static func set_test_restore_failure(enabled: bool) -> void:
	_test_restore_fail = enabled


static func clear_test_restore_failure() -> void:
	_test_restore_fail = false


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


static func capture_artifact_snapshot(primary_path: String) -> Dictionary:
	if primary_path.is_empty():
		return {"ok": false, "error": "primary path is empty", "snapshot_kind": SNAPSHOT_KIND}
	var keys: PackedStringArray = PackedStringArray(["primary", "temporary", "backup"])
	var paths: Dictionary = {
		"primary": primary_path,
		"temporary": temporary_path_for(primary_path),
		"backup": backup_path_for(primary_path),
	}
	var artifacts: Dictionary = {}
	for key in keys:
		var path: String = str(paths[key])
		var art: Dictionary = _capture_one_artifact(path)
		if not bool(art.get("ok", false)):
			return {
				"ok": false,
				"error": "unreadable artifact: %s" % key,
				"snapshot_kind": SNAPSHOT_KIND,
				"primary_path": primary_path,
			}
		artifacts[key] = art.get("data", {})
	return {
		"ok": true,
		"snapshot_kind": SNAPSHOT_KIND,
		"primary_path": primary_path,
		"artifacts": artifacts,
		"error": "",
	}


static func restore_artifact_snapshot(primary_path: String, snapshot: Dictionary) -> Dictionary:
	if _test_restore_fail:
		return {"ok": false, "error": "test-forced restore failure"}
	if primary_path.is_empty():
		return {"ok": false, "error": "primary path is empty"}
	if str(snapshot.get("snapshot_kind", "")) != SNAPSHOT_KIND:
		return {"ok": false, "error": "invalid snapshot_kind"}
	if str(snapshot.get("primary_path", "")) != primary_path:
		return {"ok": false, "error": "snapshot primary_path mismatch"}
	var artifacts: Variant = snapshot.get("artifacts", {})
	if typeof(artifacts) != TYPE_DICTIONARY:
		return {"ok": false, "error": "snapshot artifacts missing"}
	var art: Dictionary = artifacts as Dictionary
	var mapping: Dictionary = {
		"primary": primary_path,
		"temporary": temporary_path_for(primary_path),
		"backup": backup_path_for(primary_path),
	}
	for key in mapping.keys():
		if not art.has(key):
			return {"ok": false, "error": "missing artifact entry: %s" % str(key)}
		var entry: Dictionary = art[key] as Dictionary
		var path: String = str(mapping[key])
		var restored: Dictionary = _restore_one_artifact(path, entry)
		if not bool(restored.get("ok", false)):
			return {"ok": false, "error": "failed restoring %s: %s" % [str(key), str(restored.get("error", ""))]}
	if not artifact_snapshot_matches(primary_path, snapshot):
		return {"ok": false, "error": "post-restore snapshot mismatch"}
	return {"ok": true, "error": ""}


static func artifact_snapshot_matches(primary_path: String, snapshot: Dictionary) -> bool:
	if str(snapshot.get("snapshot_kind", "")) != SNAPSHOT_KIND:
		return false
	if str(snapshot.get("primary_path", "")) != primary_path:
		return false
	var current: Dictionary = capture_artifact_snapshot(primary_path)
	if not bool(current.get("ok", false)):
		return false
	var cur_art: Dictionary = current.get("artifacts", {}) as Dictionary
	var snap_art: Dictionary = snapshot.get("artifacts", {}) as Dictionary
	for key in ["primary", "temporary", "backup"]:
		var a: Dictionary = snap_art.get(key, {}) as Dictionary
		var b: Dictionary = cur_art.get(key, {}) as Dictionary
		if bool(a.get("exists", false)) != bool(b.get("exists", false)):
			return false
		if bool(a.get("exists", false)):
			if str(a.get("sha256", "")) != str(b.get("sha256", "")):
				return false
			if int(a.get("length", -1)) != int(b.get("length", -2)):
				return false
			var ab: Variant = a.get("bytes", PackedByteArray())
			var bb: Variant = b.get("bytes", PackedByteArray())
			if typeof(ab) != TYPE_PACKED_BYTE_ARRAY or typeof(bb) != TYPE_PACKED_BYTE_ARRAY:
				return false
			if ab != bb:
				return false
	return true


static func save_text(primary_path: String, text: String, validator: Callable) -> Dictionary:
	if primary_path.is_empty():
		return _save_fail("primary path is empty")
	if text.is_empty():
		return _save_fail("text is empty")

	var pre_snap: Dictionary = capture_artifact_snapshot(primary_path)
	if not bool(pre_snap.get("ok", false)):
		return _save_fail("cannot capture pre-write artifact snapshot: %s" % str(pre_snap.get("error", "")))

	var backup_path: String = backup_path_for(primary_path)
	var tmp_path: String = temporary_path_for(primary_path)

	# Classify BEFORE any write so invalid primary never overwrites a valid backup.
	var primary_info: Dictionary = classify_file(primary_path, validator)
	var backup_info: Dictionary = classify_file(backup_path, validator)
	var pstate: String = str(primary_info.get("state", FILE_MISSING))
	var bstate: String = str(backup_info.get("state", FILE_MISSING))
	# Fail-closed when no validated recovery source can be preserved/used.
	if pstate != FILE_VALID and bstate != FILE_VALID and not (pstate == FILE_MISSING and bstate == FILE_MISSING):
		return _save_fail_full(
			"no validated recovery source; refusing to overwrite invalid artifacts",
			false,
			true if bstate == FILE_VALID else false,
			pstate,
			bstate,
			false,
			false
		)

	var dir_path: String = primary_path.get_base_dir()
	if not dir_path.is_empty() and not _ensure_dir(dir_path):
		return _fail_and_restore(pre_snap, primary_path, "cannot create parent directory", pstate, bstate)

	# Profile payload remains UTF-8 JSON text for public save_text API.
	if _test_write_fail_step == "tmp_write" or not _write_all(tmp_path, text):
		return _fail_and_restore(pre_snap, primary_path, "failed to write temporary file", pstate, bstate)

	var tmp_read: String = _read_all(tmp_path)
	if not _is_valid_text(tmp_read, validator):
		return _fail_and_restore(pre_snap, primary_path, "temporary validation failed; sources untouched", pstate, bstate)

	var backup_created: bool = false
	var backup_preserved: bool = false

	if pstate == FILE_VALID:
		# Copy validated primary as raw bytes so backup stays byte-exact.
		var primary_raw: PackedByteArray = _read_all_bytes(primary_path)
		if primary_raw.is_empty() and FileAccess.file_exists(primary_path):
			return _fail_and_restore(pre_snap, primary_path, "failed to read validated primary bytes", pstate, bstate)
		if _test_write_fail_step == "backup_write" or not _write_all_bytes(backup_path, primary_raw):
			return _fail_and_restore(pre_snap, primary_path, "failed to write backup from validated primary", pstate, bstate)
		var bak_check: Dictionary = classify_file(backup_path, validator)
		if str(bak_check.get("state", "")) != FILE_VALID:
			return _fail_and_restore(pre_snap, primary_path, "backup revalidation failed; primary untouched", pstate, bstate)
		backup_created = true
	elif bstate == FILE_VALID:
		backup_preserved = true

	var tmp_raw: PackedByteArray = _read_all_bytes(tmp_path)
	if _test_write_fail_step == "primary_write" or not _write_all_bytes(primary_path, tmp_raw):
		return _fail_and_restore(pre_snap, primary_path, "failed to replace primary", pstate, bstate, backup_created, backup_preserved)
	_safe_remove(tmp_path)
	return {
		"ok": true,
		"backup_created": backup_created,
		"backup_preserved": backup_preserved,
		"previous_primary_state": pstate,
		"previous_backup_state": bstate,
		"restore_attempted": false,
		"restore_ok": false,
		"error": "",
	}


## Normalize and validate a test storage directory under user://feibao_tests/.
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

	if not normalized.begins_with(TEST_ROOT_PREFIX):
		return {"ok": false, "path": "", "error": "path not under user://feibao_tests/"}

	var relative: String = normalized.substr(TEST_ROOT_PREFIX.length())
	if relative.is_empty() or relative.contains(".."):
		return {"ok": false, "path": "", "error": "path escapes test root"}

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


static func remove_test_artifacts(primary_path: String) -> Dictionary:
	if primary_path.is_empty():
		return {"ok": false, "error": "empty path"}
	var dir: String = primary_path.get_base_dir()
	var check: Dictionary = normalize_test_storage_dir(dir)
	if not bool(check.get("ok", false)):
		return {"ok": false, "error": "refusing cleanup outside contained test path"}
	var expected: String = str(check.get("path", "")).path_join("player_profile.json")
	var norm_primary: String = primary_path.replace("\\", "/").simplify_path()
	if norm_primary != expected and not norm_primary.ends_with("/player_profile.json"):
		var parent_ok: Dictionary = normalize_test_storage_dir(norm_primary.get_base_dir())
		if not bool(parent_ok.get("ok", false)):
			return {"ok": false, "error": "primary not under contained test dir"}
	_safe_remove(primary_path)
	_safe_remove(temporary_path_for(primary_path))
	_safe_remove(backup_path_for(primary_path))
	return {"ok": true, "error": ""}


static func _capture_one_artifact(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {
			"ok": true,
			"data": {
				"exists": false,
				"readable": false,
				"bytes": PackedByteArray(),
				"sha256": "",
				"length": -1,
			},
		}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "unreadable"}
	var expected_len: int = int(f.get_length())
	var bytes: PackedByteArray = f.get_buffer(expected_len)
	var err: Error = f.get_error()
	f.close()
	if err != OK and err != ERR_FILE_EOF:
		return {"ok": false, "error": "read error"}
	if bytes.size() != expected_len:
		return {"ok": false, "error": "incomplete read"}
	return {
		"ok": true,
		"data": {
			"exists": true,
			"readable": true,
			"bytes": bytes,
			"sha256": _sha256_bytes(bytes),
			"length": bytes.size(),
		},
	}


static func _restore_one_artifact(path: String, entry: Dictionary) -> Dictionary:
	var exists: bool = bool(entry.get("exists", false))
	if not exists:
		_safe_remove(path)
		if FileAccess.file_exists(path):
			return {"ok": false, "error": "could not remove artifact"}
		return {"ok": true, "error": ""}
	if not bool(entry.get("readable", false)):
		return {"ok": false, "error": "snapshot entry not readable"}
	var bytes_v: Variant = entry.get("bytes", null)
	if typeof(bytes_v) != TYPE_PACKED_BYTE_ARRAY:
		return {"ok": false, "error": "bytes must be PackedByteArray"}
	var bytes: PackedByteArray = bytes_v as PackedByteArray
	var expected_len: int = int(entry.get("length", -1))
	if expected_len != bytes.size():
		return {"ok": false, "error": "length mismatch before restore"}
	var expected_sha: String = str(entry.get("sha256", ""))
	if expected_sha != _sha256_bytes(bytes):
		return {"ok": false, "error": "sha mismatch before restore"}
	var dir: String = path.get_base_dir()
	if not dir.is_empty() and not _ensure_dir(dir):
		return {"ok": false, "error": "cannot ensure directory"}
	if not _write_all_bytes(path, bytes):
		return {"ok": false, "error": "write failed"}
	var verify: Dictionary = _capture_one_artifact(path)
	if not bool(verify.get("ok", false)):
		return {"ok": false, "error": "post-write unreadable"}
	var data: Dictionary = verify.get("data", {}) as Dictionary
	if str(data.get("sha256", "")) != expected_sha:
		return {"ok": false, "error": "sha mismatch after restore"}
	if int(data.get("length", -1)) != expected_len:
		return {"ok": false, "error": "length mismatch after restore"}
	var got: Variant = data.get("bytes", PackedByteArray())
	if typeof(got) != TYPE_PACKED_BYTE_ARRAY or got != bytes:
		return {"ok": false, "error": "bytes mismatch after restore"}
	return {"ok": true, "error": ""}

static func _fail_and_restore(
	pre_snap: Dictionary,
	primary_path: String,
	error: String,
	pstate: String,
	bstate: String,
	backup_created: bool = false,
	backup_preserved: bool = false
) -> Dictionary:
	var restore: Dictionary = restore_artifact_snapshot(primary_path, pre_snap)
	return {
		"ok": false,
		"backup_created": backup_created,
		"backup_preserved": backup_preserved,
		"previous_primary_state": pstate,
		"previous_backup_state": bstate,
		"restore_attempted": true,
		"restore_ok": bool(restore.get("ok", false)),
		"error": error if bool(restore.get("ok", false)) else "%s; restore failed: %s" % [error, str(restore.get("error", ""))],
	}


static func _sha256_bytes(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


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


static func _read_all_bytes(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var expected_len: int = int(f.get_length())
	var bytes: PackedByteArray = f.get_buffer(expected_len)
	f.close()
	if bytes.size() != expected_len:
		return PackedByteArray()
	return bytes


## UTF-8 profile text writer for public save_text path only.
static func _write_all(path: String, text: String) -> bool:
	return _write_all_bytes(path, text.to_utf8_buffer())


## Authority raw-byte writer used by artifact snapshot restore and staged copies.
static func _write_all_bytes(path: String, bytes: PackedByteArray) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(bytes)
	f.flush()
	var err: Error = f.get_error()
	f.close()
	if err != OK and err != ERR_FILE_EOF:
		return false
	if not FileAccess.file_exists(path):
		return false
	var verify: FileAccess = FileAccess.open(path, FileAccess.READ)
	if verify == null:
		return false
	var expected_len: int = int(verify.get_length())
	var got: PackedByteArray = verify.get_buffer(expected_len)
	verify.close()
	return got == bytes


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
	return _save_fail_full(error, false, false, "", "", false, false)


static func _save_fail_full(
	error: String,
	backup_created: bool,
	backup_preserved: bool,
	pstate: String,
	bstate: String,
	restore_attempted: bool = false,
	restore_ok: bool = false
) -> Dictionary:
	return {
		"ok": false,
		"backup_created": backup_created,
		"backup_preserved": backup_preserved,
		"previous_primary_state": pstate,
		"previous_backup_state": bstate,
		"restore_attempted": restore_attempted,
		"restore_ok": restore_ok,
		"error": error,
	}
