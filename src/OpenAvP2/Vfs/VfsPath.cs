using System.Text;

namespace OpenAvP2.Vfs;

/// <summary>
/// Canonicalisation of LithTech resource paths.
/// </summary>
/// <remarks>
/// Original AvP2 data was authored on a case-insensitive filesystem using
/// backslash separators, and the same resource is referenced with inconsistent
/// case and separators throughout the game data. Every path is canonicalised
/// once at the VFS boundary so that the rest of the runtime compares plain
/// ordinal strings and behaves identically on case-sensitive filesystems
/// (Technical Design Document, sections 6 and 7).
/// </remarks>
public static class VfsPath
{
    /// <summary>
    /// Converts a path as written in game data into its canonical form:
    /// lowercase, forward-slash separated, with no leading, trailing, empty, or
    /// relative ("." / "..") segments.
    /// </summary>
    /// <param name="path">A path in any form found in game data or configuration.</param>
    /// <returns>The canonical form, or an empty string if the path has no segments.</returns>
    /// <exception cref="ArgumentNullException"><paramref name="path"/> is null.</exception>
    /// <exception cref="ArgumentException">The path escapes the root via "..".</exception>
    public static string Canonicalize(string path)
    {
        ArgumentNullException.ThrowIfNull(path);

        var segments = new List<string>();

        foreach (var raw in path.Split('/', '\\'))
        {
            if (raw.Length == 0 || raw == ".")
            {
                continue;
            }

            if (raw == "..")
            {
                if (segments.Count == 0)
                {
                    throw new ArgumentException(
                        $"Path escapes the virtual filesystem root: '{path}'", nameof(path));
                }

                segments.RemoveAt(segments.Count - 1);
                continue;
            }

            segments.Add(raw.ToLowerInvariant());
        }

        return string.Join('/', segments);
    }

    /// <summary>
    /// Determines whether two paths as written in game data refer to the same
    /// resource.
    /// </summary>
    public static bool AreEquivalent(string a, string b) =>
        string.Equals(Canonicalize(a), Canonicalize(b), StringComparison.Ordinal);

    /// <summary>
    /// Returns the file extension of a canonical or raw path, lowercased and
    /// without the leading dot, or an empty string when there is none.
    /// </summary>
    public static string Extension(string path)
    {
        ArgumentNullException.ThrowIfNull(path);

        var lastSeparator = path.LastIndexOfAny(['/', '\\']);
        var lastDot = path.LastIndexOf('.');

        return lastDot <= lastSeparator || lastDot == path.Length - 1
            ? string.Empty
            : path[(lastDot + 1)..].ToLowerInvariant();
    }
}
