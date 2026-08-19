// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors

using System.Text;
using OpenAvP2.Platform;

namespace OpenAvP2.Tests.Installation;

/// <summary>
/// In-memory <see cref="IFileSystem"/> so that installation and inventory
/// services can be tested without a real AvP2 installation, and therefore
/// without any game data in the repository.
/// </summary>
internal sealed class FakeFileSystem : IFileSystem
{
    private readonly Dictionary<string, byte[]> _files = new(StringComparer.Ordinal);
    private readonly HashSet<string> _directories = new(StringComparer.Ordinal);
    private readonly HashSet<string> _unreadable = new(StringComparer.Ordinal);

    /// <summary>
    /// Normalises separators so the fake behaves identically on Windows, where
    /// <see cref="Path.GetDirectoryName(string)"/> and <see cref="Path.Combine(string, string)"/>
    /// return backslashes and would otherwise not match forward-slash keys.
    /// </summary>
    private static string Normalize(string path) => path.Replace('\\', '/');

    /// <summary>Adds a file with the given contents, creating parent directories.</summary>
    public FakeFileSystem WithFile(string path, byte[]? contents = null)
    {
        path = Normalize(path);
        _files[path] = contents ?? [];

        var directory = Path.GetDirectoryName(path);
        while (!string.IsNullOrEmpty(directory))
        {
            _directories.Add(Normalize(directory));
            directory = Path.GetDirectoryName(directory);
        }

        return this;
    }

    /// <summary>Adds a file whose contents are the given ASCII text.</summary>
    public FakeFileSystem WithFile(string path, string contents) =>
        WithFile(path, Encoding.ASCII.GetBytes(contents));

    /// <summary>Adds an empty directory.</summary>
    public FakeFileSystem WithDirectory(string path)
    {
        _directories.Add(Normalize(path));
        return this;
    }

    /// <summary>Marks a file as throwing on open, to exercise error handling.</summary>
    public FakeFileSystem WithUnreadableFile(string path)
    {
        WithFile(path, [1, 2, 3, 4]);
        _unreadable.Add(Normalize(path));
        return this;
    }

    public bool DirectoryExists(string path) => _directories.Contains(Normalize(path));

    public bool FileExists(string path) => _files.ContainsKey(Normalize(path));

    public IEnumerable<string> EnumerateFiles(string directory) =>
        _files.Keys.Where(p => p.StartsWith(Normalize(directory) + '/', StringComparison.Ordinal));

    public Stream OpenRead(string path)
    {
        path = Normalize(path);
        if (_unreadable.Contains(path))
        {
            throw new IOException($"Simulated read failure: {path}");
        }

        return _files.TryGetValue(path, out var contents)
            ? new MemoryStream(contents, writable: false)
            : throw new FileNotFoundException(path);
    }

    public long GetFileSize(string path) =>
        _files.TryGetValue(Normalize(path), out var contents)
            ? contents.Length
            : throw new FileNotFoundException(path);
}
