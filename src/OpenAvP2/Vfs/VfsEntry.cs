namespace OpenAvP2.Vfs;

/// <summary>
/// Diagnostic metadata about a resolved resource. Exposed so that mod load-order
/// problems and unexpected overrides can be diagnosed from a log or a support
/// bundle rather than by guesswork (Technical Design Document, sections 7 and 17).
/// </summary>
/// <param name="Path">The canonical resource path.</param>
/// <param name="SourceName">The archive, mod, or directory that provided the resource.</param>
/// <param name="Priority">The precedence of the mount that won.</param>
/// <param name="Size">Uncompressed size in bytes.</param>
/// <param name="ContentHash">Content hash, used for caching and for server-side content validation.</param>
/// <param name="ShadowedBy">Mounts that also provide this path but lost resolution, highest priority first.</param>
public sealed record VfsEntry(
    string Path,
    string SourceName,
    MountPriority Priority,
    long Size,
    string ContentHash,
    IReadOnlyList<string> ShadowedBy);
