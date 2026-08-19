namespace OpenAvP2.Vfs;

/// <summary>
/// Read-only access to game content, regardless of whether a resource came from
/// a REZ archive, an official patch, a mod package, or a loose override file
/// (Technical Design Document, section 7).
/// </summary>
/// <remarks>
/// The virtual filesystem never writes to the original installation. OpenAvP2
/// caches, converted resources, logs and saves live in OpenAvP2-owned platform
/// directories.
/// </remarks>
public interface IVfs
{
    /// <summary>
    /// Opens a resource for reading, resolved from the highest-priority mount
    /// that provides it.
    /// </summary>
    /// <param name="path">A resource path in any form found in game data; it is canonicalised internally.</param>
    /// <returns>A readable, seekable stream owned by the caller.</returns>
    /// <exception cref="FileNotFoundException">No mount provides the resource.</exception>
    Stream Open(string path);

    /// <summary>Determines whether any mount provides the resource.</summary>
    bool Exists(string path);

    /// <summary>
    /// Returns diagnostic metadata for the resource as it would be resolved,
    /// including which mount won and which mounts were shadowed.
    /// </summary>
    /// <returns>The entry, or null when no mount provides the resource.</returns>
    VfsEntry? Describe(string path);

    /// <summary>
    /// Enumerates the canonical paths of all resources beneath a directory
    /// prefix, after override resolution.
    /// </summary>
    IEnumerable<string> Enumerate(string prefix);
}
