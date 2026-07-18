## Local player profile session owner. Coordinates codec + staged save store.
## Does not own navigation or UI. AppState remains in-memory session state only.
## Schema 1 loads migrate lazily in memory; first successful changed save writes schema 2.
extends Node

signal profile_changed(revision: int)
signal character_granted(character_id: StringName, revision: int)
signal selected_character_changed(character_id: StringName, revision: int)
signal party_changed(party_ids: Array[StringName], revision: int)

const STATE_UNINITIALIZED: StringName = &"UNINITIALIZED"
const STATE_NEW_PROFILE: StringName = &"NEW_PROFILE"
const STATE_LOADED_PRIMARY: StringName = &"LOADED_PRIMARY"
const STATE_RECOVERED_BACKUP: StringName = &"RECOVERED_BACKUP"
const STATE_SAFE_DEFAULT_CORRUPT: StringName = &"SAFE_DEFAULT_CORRUPT"
const STATE_SAVE_FAILED: StringName = &"SAVE_FAILED"

const PROD_DIR: String = "user://feibao"
const PROD_PRIMARY: String = "user://feibao/player_profile.json"
const TRANSACTION_KIND: String = "player_persistence_transaction_v1"

const NOTICE_RECOVERED: String = "已從備份還原玩家資料"
const NOTICE_CORRUPT: String = "玩家資料損壞，已使用安全預設（尚未覆蓋原檔）"
const ERR_SAVE_FAILED: String = "無法儲存玩家資料，請再試一次"
const ERR_TX_ROLLBACK: String = "transaction rollback failure"
const ERR_UNKNOWN_CHARACTER: String = "unknown character id"
const ERR_CATALOG_LOAD: String = "character catalog load failed"
const ERR_NOT_OWNED: String = "character is not owned"

var _initialized: bool = false
var _profile: PlayerProfile = null
var _load_state: StringName = STATE_UNINITIALIZED
var _last_error: String = ""
var _user_notice: String = ""
var _test_storage_dir: String = ""
var _save_override: Callable = Callable()
var _last_save_wrote_disk: bool = false
var _profile_migration_pending: bool = false
var _loaded_source_schema_version: int = PlayerProfile.SCHEMA_VERSION


func _ready() -> void:
	_profile = PlayerProfile.create_default()
	_load_state = STATE_UNINITIALIZED
	_profile_migration_pending = false
	_loaded_source_schema_version = PlayerProfile.SCHEMA_VERSION


func get_production_primary_path() -> String:
	return PROD_PRIMARY


func get_primary_path() -> String:
	if not _test_storage_dir.is_empty():
		return _test_storage_dir.path_join("player_profile.json")
	return PROD_PRIMARY


func configure_test_storage_path(path: String) -> bool:
	var check: Dictionary = SaveFileStore.normalize_test_storage_dir(path)
	if not bool(check.get("ok", false)):
		return false
	_test_storage_dir = str(check.get("path", ""))
	return true


func clear_test_storage_path() -> void:
	_test_storage_dir = ""


func is_using_test_storage() -> bool:
	return not _test_storage_dir.is_empty()


func reset_runtime_state_for_tests() -> void:
	_initialized = false
	_profile = PlayerProfile.create_default()
	_load_state = STATE_UNINITIALIZED
	_last_error = ""
	_user_notice = ""
	_save_override = Callable()
	_last_save_wrote_disk = false
	_profile_migration_pending = false
	_loaded_source_schema_version = PlayerProfile.SCHEMA_VERSION
	SaveFileStore.clear_test_write_failure_step()
	SaveFileStore.clear_test_restore_failure()


func set_save_override_for_tests(callback: Callable) -> void:
	_save_override = callback


func clear_save_override_for_tests() -> void:
	_save_override = Callable()


func initialize() -> Dictionary:
	if _initialized:
		return _status_dict()

	_last_error = ""
	_user_notice = ""
	_last_save_wrote_disk = false
	var primary: String = get_primary_path()
	var load_result: Dictionary = SaveFileStore.load_text(primary, Callable(self, "_validate_profile_text"))

	if bool(load_result.get("ok", false)):
		var parsed: Dictionary = PlayerProfileCodec.parse_json_text(str(load_result.get("text", "")))
		if bool(parsed.get("ok", false)):
			_profile = parsed["profile"] as PlayerProfile
			_profile_migration_pending = bool(parsed.get("migration_required", false))
			_loaded_source_schema_version = int(parsed.get("source_schema_version", PlayerProfile.SCHEMA_VERSION))
			if bool(load_result.get("recovered_from_backup", false)):
				_load_state = STATE_RECOVERED_BACKUP
				_user_notice = NOTICE_RECOVERED
			else:
				_load_state = STATE_LOADED_PRIMARY
			_sync_app_state_from_profile()
			_initialized = true
			# Lazy migration: never write on initialize for schema 1 or schema 2.
			return _status_dict()

	var source: String = str(load_result.get("source", ""))
	if source == SaveFileStore.SOURCE_MISSING:
		_profile = PlayerProfile.create_default()
		_load_state = STATE_NEW_PROFILE
		_last_error = ""
		_user_notice = ""
		_profile_migration_pending = false
		_loaded_source_schema_version = PlayerProfile.SCHEMA_VERSION
		AppState.set_player_name("")
		_initialized = true
		return _status_dict()

	_profile = PlayerProfile.create_default()
	_load_state = STATE_SAFE_DEFAULT_CORRUPT
	_last_error = str(load_result.get("error", "corrupt save"))
	_user_notice = NOTICE_CORRUPT
	_profile_migration_pending = false
	_loaded_source_schema_version = PlayerProfile.SCHEMA_VERSION
	AppState.set_player_name("")
	_initialized = true
	return _status_dict()


func is_initialized() -> bool:
	return _initialized


func is_profile_migration_pending() -> bool:
	return _profile_migration_pending


func get_loaded_source_schema_version() -> int:
	return _loaded_source_schema_version


func get_profile() -> PlayerProfile:
	if _profile == null:
		return PlayerProfile.create_default()
	return _profile


func get_player_name() -> String:
	return get_profile().get_player_name()


func owns_character(character_id: StringName) -> bool:
	return get_profile().owns_character(character_id)


func get_selected_character_id() -> StringName:
	return get_profile().get_selected_character_id()


func get_owned_character_ids() -> Array[StringName]:
	return get_profile().get_owned_character_ids()


func get_active_party_character_ids() -> Array[StringName]:
	return get_profile().get_active_party_character_ids()


func get_party_leader_character_id() -> StringName:
	return get_profile().get_party_leader_character_id()


func is_character_in_active_party(character_id: StringName) -> bool:
	return get_profile().is_character_in_active_party(character_id)


func is_known_character(character_id: StringName) -> bool:
	var catalog: Dictionary = CharacterCatalog.load_default()
	return _catalog_contains_character(catalog, character_id)


func get_known_owned_count() -> int:
	var catalog: Dictionary = CharacterCatalog.load_default()
	if not bool(catalog.get("ok", false)):
		return 0
	var known: Dictionary = {}
	for item in catalog.get("characters", []):
		if item is CharacterDefinition:
			known[str((item as CharacterDefinition).get_id())] = true
	var count: int = 0
	for id in get_owned_character_ids():
		if known.has(str(id)):
			count += 1
	return count


func _catalog_contains_character(catalog: Dictionary, character_id: StringName) -> bool:
	if not bool(catalog.get("ok", false)):
		return false
	var id_str: String = String(character_id)
	if id_str.is_empty():
		return false
	for item in catalog.get("characters", []):
		if item is CharacterDefinition and (item as CharacterDefinition).get_id() == character_id:
			return true
	return false


func get_load_state() -> StringName:
	return _load_state


func get_last_error() -> String:
	return _last_error


func get_user_notice() -> String:
	return _user_notice


func did_last_save_write_disk() -> bool:
	return _last_save_wrote_disk


func grant_character(character_id: StringName) -> Dictionary:
	return _mutate_character_ownership(character_id, &"grant")


func select_character(character_id: StringName) -> Dictionary:
	return _mutate_character_ownership(character_id, &"select")


func add_party_member(character_id: StringName) -> Dictionary:
	return _mutate_party(character_id, &"add", -1)


func remove_party_member(character_id: StringName) -> Dictionary:
	return _mutate_party(character_id, &"remove", -1)


func move_party_member(character_id: StringName, target_index: int) -> Dictionary:
	return _mutate_party(character_id, &"move", target_index)


func save_player_name(value: String) -> Dictionary:
	_last_save_wrote_disk = false
	if not _initialized:
		initialize()

	var trimmed: String = value.strip_edges()
	if trimmed.is_empty() or trimmed.length() < 1 or trimmed.length() > PlayerProfile.PLAYER_NAME_MAX_LENGTH:
		return {
			"ok": false,
			"changed": false,
			"error": "invalid player name",
			"profile_revision": get_profile().get_revision(),
		}

	var current: PlayerProfile = get_profile()
	if trimmed == current.get_player_name():
		return {
			"ok": true,
			"changed": false,
			"error": "",
			"profile_revision": current.get_revision(),
		}

	var candidate: PlayerProfile = current.with_player_name(trimmed)
	var commit: Dictionary = _commit_candidate_profile(candidate)
	if not bool(commit.get("ok", false)):
		return {
			"ok": false,
			"changed": false,
			"error": ERR_SAVE_FAILED,
			"profile_revision": current.get_revision(),
		}

	AppState.set_player_name(trimmed)
	return {
		"ok": true,
		"changed": true,
		"error": "",
		"profile_revision": candidate.get_revision(),
	}


func _mutate_character_ownership(character_id: StringName, mode: StringName) -> Dictionary:
	_last_save_wrote_disk = false
	if not _initialized:
		initialize()

	var current: PlayerProfile = get_profile()
	var base_result: Dictionary = {
		"ok": false,
		"changed": false,
		"error": "",
		"profile_revision": current.get_revision(),
		"character_id": character_id,
	}

	var catalog: Dictionary = CharacterCatalog.load_default()
	if not bool(catalog.get("ok", false)):
		base_result["error"] = ERR_CATALOG_LOAD
		return base_result

	if not _catalog_contains_character(catalog, character_id):
		base_result["error"] = ERR_UNKNOWN_CHARACTER
		return base_result

	var mutation: Dictionary
	if mode == &"grant":
		mutation = current.with_character_granted(character_id)
	else:
		mutation = current.with_selected_character(character_id)

	if not bool(mutation.get("ok", false)):
		base_result["error"] = str(mutation.get("error", ERR_NOT_OWNED))
		return base_result

	var candidate: PlayerProfile = mutation["profile"] as PlayerProfile
	if candidate == null:
		base_result["error"] = "mutation produced no profile"
		return base_result

	if not bool(mutation.get("changed", false)):
		return {
			"ok": true,
			"changed": false,
			"error": "",
			"profile_revision": current.get_revision(),
			"character_id": character_id,
		}

	var commit: Dictionary = _commit_candidate_profile(candidate)
	if not bool(commit.get("ok", false)):
		return {
			"ok": false,
			"changed": false,
			"error": ERR_SAVE_FAILED,
			"profile_revision": current.get_revision(),
			"character_id": character_id,
		}

	var rev: int = candidate.get_revision()
	profile_changed.emit(rev)
	if mode == &"grant":
		character_granted.emit(character_id, rev)
	else:
		selected_character_changed.emit(character_id, rev)

	return {
		"ok": true,
		"changed": true,
		"error": "",
		"profile_revision": rev,
		"character_id": character_id,
	}


func _mutate_party(character_id: StringName, mode: StringName, target_index: int) -> Dictionary:
	_last_save_wrote_disk = false
	if not _initialized:
		initialize()

	var current: PlayerProfile = get_profile()
	var base_result: Dictionary = {
		"ok": false,
		"changed": false,
		"error": "",
		"profile_revision": current.get_revision(),
		"character_id": character_id,
		"active_party_character_ids": current.get_active_party_character_ids(),
	}

	var mutation: Dictionary
	if mode == &"add":
		var catalog: Dictionary = CharacterCatalog.load_default()
		if not bool(catalog.get("ok", false)):
			base_result["error"] = ERR_CATALOG_LOAD
			return base_result
		if not _catalog_contains_character(catalog, character_id):
			base_result["error"] = ERR_UNKNOWN_CHARACTER
			return base_result
		if not current.owns_character(character_id):
			base_result["error"] = ERR_NOT_OWNED
			return base_result
		mutation = current.with_party_member_added(character_id)
	elif mode == &"remove":
		# Remove allows unknown persisted IDs already in party; no catalog requirement.
		mutation = current.with_party_member_removed(character_id)
	else:
		mutation = current.with_party_member_moved(character_id, target_index)

	if not bool(mutation.get("ok", false)):
		base_result["error"] = str(mutation.get("error", "party mutation failed"))
		return base_result

	var candidate: PlayerProfile = mutation["profile"] as PlayerProfile
	if candidate == null:
		base_result["error"] = "mutation produced no profile"
		return base_result

	if not bool(mutation.get("changed", false)):
		return {
			"ok": true,
			"changed": false,
			"error": "",
			"profile_revision": current.get_revision(),
			"character_id": character_id,
			"active_party_character_ids": current.get_active_party_character_ids(),
		}

	var commit: Dictionary = _commit_candidate_profile(candidate)
	if not bool(commit.get("ok", false)):
		return {
			"ok": false,
			"changed": false,
			"error": ERR_SAVE_FAILED,
			"profile_revision": current.get_revision(),
			"character_id": character_id,
			"active_party_character_ids": current.get_active_party_character_ids(),
		}

	var rev: int = candidate.get_revision()
	var party_copy: Array[StringName] = candidate.get_active_party_character_ids()
	profile_changed.emit(rev)
	party_changed.emit(party_copy, rev)

	return {
		"ok": true,
		"changed": true,
		"error": "",
		"profile_revision": rev,
		"character_id": character_id,
		"active_party_character_ids": party_copy,
	}


## Shared candidate commit: encode + save, publish only on success.
## Successful write clears migration_pending and sets source schema to 2.
func _commit_candidate_profile(candidate: PlayerProfile) -> Dictionary:
	var encoded: Dictionary = PlayerProfileCodec.encode_profile(candidate)
	if not bool(encoded.get("ok", false)):
		_load_state = STATE_SAVE_FAILED
		_last_error = str(encoded.get("error", "encode failed"))
		return {"ok": false, "error": _last_error}

	var text: String = str(encoded.get("text", ""))
	var save_result: Dictionary
	if _save_override.is_valid():
		save_result = _save_override.call(get_primary_path(), text)
	else:
		save_result = SaveFileStore.save_text(
			get_primary_path(),
			text,
			Callable(self, "_validate_profile_text")
		)

	if not bool(save_result.get("ok", false)):
		_load_state = STATE_SAVE_FAILED
		_last_error = str(save_result.get("error", "save failed"))
		return {"ok": false, "error": _last_error}

	_profile = candidate
	_last_save_wrote_disk = true
	_last_error = ""
	_user_notice = ""
	_load_state = STATE_LOADED_PRIMARY
	_profile_migration_pending = false
	_loaded_source_schema_version = PlayerProfile.SCHEMA_VERSION
	return {"ok": true, "error": ""}


## Capture full memory + artifact snapshot before a login persistence transaction.
func capture_persistence_transaction() -> Dictionary:
	if not _initialized:
		initialize()
	var storage: Dictionary = SaveFileStore.capture_artifact_snapshot(get_primary_path())
	if not bool(storage.get("ok", false)):
		return {
			"ok": false,
			"transaction": {},
			"error": "storage snapshot failed: %s" % str(storage.get("error", "")),
		}
	var tx: Dictionary = {
		"transaction_kind": TRANSACTION_KIND,
		"profile": get_profile().duplicate_profile(),
		"app_state_player_name": AppState.get_player_name(),
		"load_state": _load_state,
		"last_error": _last_error,
		"user_notice": _user_notice,
		"last_save_wrote_disk": _last_save_wrote_disk,
		"profile_migration_pending": _profile_migration_pending,
		"loaded_source_schema_version": _loaded_source_schema_version,
		"storage_snapshot": storage,
		"primary_path": get_primary_path(),
	}
	return {"ok": true, "transaction": tx, "error": ""}


## Complete rollback of profile, AppState, PlayerData flags, and primary/tmp/backup bytes.
func rollback_persistence_transaction(transaction: Dictionary) -> Dictionary:
	if str(transaction.get("transaction_kind", "")) != TRANSACTION_KIND:
		return {"ok": false, "disk_ok": false, "error": "invalid transaction_kind"}
	var primary: String = get_primary_path()
	if str(transaction.get("primary_path", "")) != primary:
		return {"ok": false, "disk_ok": false, "error": "transaction primary_path mismatch"}
	var storage_snapshot: Dictionary = transaction.get("storage_snapshot", {}) as Dictionary
	var disk: Dictionary = SaveFileStore.restore_artifact_snapshot(primary, storage_snapshot)

	var prior_profile: PlayerProfile = transaction.get("profile") as PlayerProfile
	if prior_profile != null:
		_profile = prior_profile.duplicate_profile()
	else:
		_profile = PlayerProfile.create_default()
	AppState.set_player_name(str(transaction.get("app_state_player_name", "")))
	_user_notice = str(transaction.get("user_notice", ""))
	_last_save_wrote_disk = bool(transaction.get("last_save_wrote_disk", false))
	_profile_migration_pending = bool(transaction.get("profile_migration_pending", false))
	_loaded_source_schema_version = int(transaction.get("loaded_source_schema_version", PlayerProfile.SCHEMA_VERSION))

	if not bool(disk.get("ok", false)):
		_load_state = STATE_SAVE_FAILED
		_last_error = "%s: %s" % [ERR_TX_ROLLBACK, str(disk.get("error", ""))]
		return {
			"ok": false,
			"disk_ok": false,
			"error": _last_error,
		}

	_load_state = transaction.get("load_state", STATE_UNINITIALIZED) as StringName
	_last_error = str(transaction.get("last_error", ""))
	return {"ok": true, "disk_ok": true, "error": ""}


## Deprecated unsafe path: must not be used for navigation rollback.
func restore_profile_snapshot(_snapshot: PlayerProfile) -> Dictionary:
	return {
		"ok": false,
		"disk_ok": false,
		"error": "unsafe restore_profile_snapshot disabled; use rollback_persistence_transaction",
	}


func cleanup_test_artifacts() -> Dictionary:
	if _test_storage_dir.is_empty():
		return {"ok": false, "error": "no test storage configured"}
	var check: Dictionary = SaveFileStore.normalize_test_storage_dir(_test_storage_dir)
	if not bool(check.get("ok", false)):
		return {"ok": false, "error": "configured test path failed containment"}
	return SaveFileStore.remove_test_artifacts(get_primary_path())


func _validate_profile_text(text: String) -> bool:
	var parsed: Dictionary = PlayerProfileCodec.parse_json_text(text)
	return bool(parsed.get("ok", false))


func _sync_app_state_from_profile() -> void:
	AppState.set_player_name(get_profile().get_player_name())


func _status_dict() -> Dictionary:
	return {
		"ok": true,
		"initialized": _initialized,
		"state": str(_load_state),
		"player_name": get_player_name(),
		"error": _last_error,
		"notice": _user_notice,
		"recovered_from_backup": _load_state == STATE_RECOVERED_BACKUP,
		"migration_pending": _profile_migration_pending,
		"source_schema_version": _loaded_source_schema_version,
	}
