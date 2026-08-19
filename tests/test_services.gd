# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
extends GutTest

## Guards the composition root. A miswired graph is a runtime failure in every
## host, so it is worth catching in a unit test rather than on first launch.


func test_builds_the_orchestrator_and_its_whole_graph() -> void:
	assert_not_null(Services.new(FakeFileSystem.new()).inventory_orchestrator())


func test_builds_each_service() -> void:
	var services := Services.new(FakeFileSystem.new())

	assert_not_null(services.installation_validator())
	assert_not_null(services.inventory_writer())
	assert_not_null(services.file_system)


func test_defaults_to_the_physical_file_system() -> void:
	assert_true(Services.new().file_system is PhysicalFileSystem)


func test_injected_file_system_reaches_the_services() -> void:
	# This is what lets every test run without a real installation.
	var fake := FakeFileSystem.new()
	var services := Services.new(fake)

	assert_same(services.file_system, fake)


func test_registers_probes_as_a_collection() -> void:
	# Format-specific probes are added as each format is understood, so the
	# registration must be a collection rather than a single service.
	assert_gt(Services.new(FakeFileSystem.new()).probes.size(), 0)
