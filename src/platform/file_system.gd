# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
class_name FileSystemPort
extends RefCounted

## Read-only filesystem access.
##
## Injected rather than called statically so that every service above it can be
## tested without a real AvP2 installation, and therefore without any game data
## in the repository. GDScript has no interfaces, so the contract is expressed
## as a base class whose methods must be overridden.
##
## Implementations must never modify the original installation.


## Whether a directory exists.
func directory_exists(_path: String) -> bool:
	push_error("directory_exists must be overridden")
	return false


## Whether a file exists.
func file_exists(_path: String) -> bool:
	push_error("file_exists must be overridden")
	return false


## Every file beneath a directory, recursively, as absolute paths.
##
## Implementations skip entries they cannot access rather than failing, so that
## one unreadable directory does not abort an inventory scan.
func enumerate_files(_directory: String) -> PackedStringArray:
	push_error("enumerate_files must be overridden")
	return PackedStringArray()


## The leading bytes of a file, at most [param max_bytes].
##
## Returns an empty array when the file cannot be read. Reading a prefix rather
## than the whole file keeps a scan over a 1.4 GB installation cheap.
func read_prefix(_path: String, _max_bytes: int) -> PackedByteArray:
	push_error("read_prefix must be overridden")
	return PackedByteArray()


## Size of a file in bytes, or -1 when it cannot be read.
func file_size(_path: String) -> int:
	push_error("file_size must be overridden")
	return -1
