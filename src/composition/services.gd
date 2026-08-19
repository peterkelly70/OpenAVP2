# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name Services
extends RefCounted

## Composition root.
##
## GDScript has no dependency injection container, so composition is explicit:
## this class builds the object graph, and every service receives its
## dependencies through [code]_init[/code] rather than constructing them itself.
## The game, the dedicated server and the command line tools all build their
## graph here rather than each wiring their own.
##
## Overriding [member file_system] before calling a build method is what lets
## tests substitute an in-memory filesystem.

## The filesystem every service reads through. Replace before building to test.
var file_system: FileSystemPort

## Probes offered to the inventory orchestrator, in order. Format-specific probes
## are appended here as each format becomes understood.
var probes: Array[FormatProbe]


func _init(injected_file_system: FileSystemPort = null) -> void:
	file_system = injected_file_system if injected_file_system != null else PhysicalFileSystem.new()
	probes = [SignatureProbe.new()] as Array[FormatProbe]


## Builds the installation validator.
func installation_validator() -> InstallationValidator:
	return InstallationValidator.new(file_system)


## Builds the inventory orchestrator and its whole dependency graph.
func inventory_orchestrator() -> InventoryOrchestrator:
	return InventoryOrchestrator.new(file_system, installation_validator(), probes)


## Builds the inventory writer.
func inventory_writer() -> JsonInventoryWriter:
	return JsonInventoryWriter.new()
