# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name InventoryOrchestrator
extends RefCounted

## Scans an AvP2 installation and produces the format inventory that is the exit
## criterion for roadmap stage 0.
##
## The orchestrator owns the sequence of the scan and nothing else: validation,
## filesystem access and file inspection are all injected. Adding a probe for a
## newly understood format therefore requires no change here.

var _file_system: FileSystemPort
var _validator: InstallationValidator
var _probes: Array[FormatProbe]


func _init(
	file_system: FileSystemPort,
	validator: InstallationValidator,
	probes: Array[FormatProbe]
) -> void:
	_file_system = file_system
	_validator = validator
	_probes = probes


## Scans an installation directory.
##
## A directory that fails validation is still scanned and reported, so that a
## near-miss can be diagnosed rather than merely rejected.
##
## [param options] accepts "examples_per_signature" (int) and "probe_contents"
## (bool).
func scan(installation_path: String, options: Dictionary = {}) -> Dictionary:
	var examples_per_signature: int = options.get("examples_per_signature", 3)
	var probe_contents: bool = options.get("probe_contents", true)

	var validation := _validator.validate(installation_path)
	for failure in validation.failures():
		print("[VFS] Installation check failed: %s (%s)"
			% [failure["requirement"], failure["detail"]])

	var extensions := {}
	var unreadable := {}
	var file_count := 0
	var total_bytes := 0

	for path in _file_system.enumerate_files(installation_path):
		var canonical := VfsPath.canonicalize(_relative(installation_path, path))
		var ext := VfsPath.extension(canonical)
		if ext == "":
			ext = "(none)"

		var size := _file_system.file_size(path)
		if size < 0:
			unreadable[canonical] = "could not be opened"
			continue

		file_count += 1
		total_bytes += size

		if not extensions.has(ext):
			extensions[ext] = {"count": 0, "total_bytes": 0, "signatures": {}}
		extensions[ext]["count"] += 1
		extensions[ext]["total_bytes"] += size

		if not probe_contents:
			continue

		var result := _probe_file(path, canonical, unreadable)
		if not result.is_empty():
			_record_signature(
				extensions[ext]["signatures"],
				result["signature"],
				canonical,
				examples_per_signature)

	print("[VFS] Inventory complete: %d files, %d extensions, %d unreadable"
		% [file_count, extensions.size(), unreadable.size()])

	return {
		"installation_path": installation_path,
		"generated_utc": Time.get_datetime_string_from_system(true, true),
		"is_valid_installation": validation.is_valid,
		"file_count": file_count,
		"total_bytes": total_bytes,
		"extensions": _summarise(extensions),
		"unreadable_files": unreadable,
	}


func _probe_file(path: String, canonical: String, unreadable: Dictionary) -> Dictionary:
	for probe in _probes:
		if not probe.can_probe(canonical):
			continue

		var prefix := _file_system.read_prefix(path, probe.required_bytes())
		if prefix.is_empty():
			# Distinguish an empty file from an unreadable one.
			if _file_system.file_size(path) > 0:
				unreadable[canonical] = "could not be read"
			return {}

		var result := probe.probe(canonical, prefix)
		if not result.is_empty():
			return result

	return {}


func _record_signature(
	signatures: Dictionary, signature: String, path: String, example_limit: int
) -> void:
	if not signatures.has(signature):
		signatures[signature] = {"count": 0, "examples": PackedStringArray()}
	signatures[signature]["count"] += 1
	if signatures[signature]["examples"].size() < example_limit:
		signatures[signature]["examples"].append(path)


## Collapses the accumulators into a stable, sorted report structure. Ordering is
## deterministic so that two scans of the same installation produce identical
## output and can be diffed.
func _summarise(extensions: Dictionary) -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []

	for ext in extensions:
		var entry: Dictionary = extensions[ext]
		var groups: Array[Dictionary] = []
		for signature in entry["signatures"]:
			var group: Dictionary = entry["signatures"][signature]
			groups.append({
				"signature": signature,
				"count": group["count"],
				"examples": group["examples"],
			})
		groups.sort_custom(_by_count_then_key.bind("signature"))

		summaries.append({
			"extension": ext,
			"count": entry["count"],
			"total_bytes": entry["total_bytes"],
			"signatures": groups,
		})

	summaries.sort_custom(_by_count_then_key.bind("extension"))
	return summaries


static func _by_count_then_key(a: Dictionary, b: Dictionary, key: String) -> bool:
	if a["count"] != b["count"]:
		return a["count"] > b["count"]
	return a[key] < b[key]


static func _relative(root: String, path: String) -> String:
	if path.begins_with(root):
		return path.substr(root.length()).lstrip("/\\")
	return path
