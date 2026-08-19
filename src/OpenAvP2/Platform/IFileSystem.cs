// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors

namespace OpenAvP2.Platform;

/// <summary>
/// Read-only filesystem access, injected rather than called statically so that
/// every service above it can be tested without a real AvP2 installation.
/// </summary>
/// <remarks>
/// Deliberately minimal: it exposes only the operations OpenAvP2 actually needs
/// to inspect an installation. Implementations must not modify the original
/// installation in any way.
/// </remarks>
public interface IFileSystem
{
    /// <summary>Determines whether a directory exists.</summary>
    bool DirectoryExists(string path);

    /// <summary>Determines whether a file exists.</summary>
    bool FileExists(string path);

    /// <summary>
    /// Enumerates every file beneath a directory, recursively, as absolute paths.
    /// </summary>
    /// <remarks>
    /// Implementations skip entries they cannot access rather than throwing, so
    /// that one unreadable directory does not abort an inventory scan.
    /// </remarks>
    IEnumerable<string> EnumerateFiles(string directory);

    /// <summary>Opens a file for reading.</summary>
    Stream OpenRead(string path);

    /// <summary>Returns the size of a file in bytes.</summary>
    long GetFileSize(string path);
}