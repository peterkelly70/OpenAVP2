// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors

using OpenAvP2.Platform;
using OpenAvP2.Vfs;

namespace OpenAvP2.Installation;

/// <summary>
/// Validates an installation by looking for the archives AvP2 cannot run without.
/// </summary>
/// <remarks>
/// Matching is done on canonicalised names so that validation behaves the same
/// on case-sensitive filesystems, where the shipped casing of a file cannot be
/// relied on (Technical Design Document, sections 6 and 23).
/// <para>
/// This checks that a directory <em>is</em> an AvP2 installation. Identifying
/// which version and patch level it is requires reading archive contents and is
/// the job of the inventory scan.
/// </para>
/// </remarks>
public sealed class InstallationValidator : IInstallationValidator
{
    private readonly IFileSystem _fileSystem;

    /// <summary>Archives expected in the root of any AvP2 installation.</summary>
    private static readonly string[] RequiredArchives = ["avp2.rez"];

    /// <summary>
    /// Directories expected in an AvP2 installation. Absence is reported but is
    /// not by itself disqualifying, since content may live entirely in archives.
    /// </summary>
    private static readonly string[] ExpectedDirectories = ["sound", "custom"];

    /// <summary>Initialises the validator.</summary>
    public InstallationValidator(IFileSystem fileSystem)
    {
        ArgumentNullException.ThrowIfNull(fileSystem);
        _fileSystem = fileSystem;
    }

    /// <inheritdoc />
    public InstallationValidation Validate(string path)
    {
        ArgumentNullException.ThrowIfNull(path);

        var checks = new List<InstallationCheck>();

        if (!_fileSystem.DirectoryExists(path))
        {
            checks.Add(new InstallationCheck(
                "Installation directory exists", false, $"Not found: {path}"));
            return new InstallationValidation(path, false, checks);
        }

        checks.Add(new InstallationCheck(
            "Installation directory exists", true, path));

        // Resolve the directory listing once, canonicalised, so that lookups are
        // case-insensitive without assuming the filesystem is.
        var rootFiles = SafeEnumerateRootNames(path);

        var required = 0;
        foreach (var archive in RequiredArchives)
        {
            var found = rootFiles.Contains(archive);
            if (found)
            {
                required++;
            }

            checks.Add(new InstallationCheck(
                $"Base archive {archive}",
                found,
                found ? "Found" : "Missing from the installation root"));
        }

        foreach (var directory in ExpectedDirectories)
        {
            var found = _fileSystem.DirectoryExists(Path.Combine(path, directory));
            checks.Add(new InstallationCheck(
                $"Directory {directory}",
                found,
                found ? "Found" : "Not present; content may be archived instead"));
        }

        // Only the required archives determine validity. The directory checks are
        // advisory, so an installation that keeps everything in archives still
        // validates.
        return new InstallationValidation(path, required == RequiredArchives.Length, checks);
    }

    private HashSet<string> SafeEnumerateRootNames(string path)
    {
        var names = new HashSet<string>(StringComparer.Ordinal);

        foreach (var file in _fileSystem.EnumerateFiles(path))
        {
            var name = Path.GetFileName(file);
            if (!string.IsNullOrEmpty(name))
            {
                names.Add(VfsPath.Canonicalize(name));
            }
        }

        return names;
    }
}
