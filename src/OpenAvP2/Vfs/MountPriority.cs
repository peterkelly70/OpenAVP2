namespace OpenAvP2.Vfs;

/// <summary>
/// Virtual filesystem mount precedence, lowest to highest priority, as defined
/// by the Technical Design Document, section 7. A resource is resolved from the
/// highest-priority mount that provides it.
/// </summary>
/// <remarks>
/// The numeric values are deliberately ordered and stable: mod tooling and
/// diagnostics report precedence by this ordering, so values must not be
/// reassigned once content depends on them.
/// </remarks>
public enum MountPriority
{
    /// <summary>Archives shipped with the retail game.</summary>
    BaseGame = 0,

    /// <summary>Official patch archives, which override base content.</summary>
    OfficialPatch = 1,

    /// <summary>Expansion archives, mounted only when the expansion is enabled.</summary>
    Expansion = 2,

    /// <summary>Content supplied by OpenAvP2 itself for compatibility purposes.</summary>
    CompatibilityContent = 3,

    /// <summary>Installed mods, ordered among themselves by declared load order.</summary>
    Mod = 4,

    /// <summary>Loose files supplied by the user. Always wins.</summary>
    UserOverride = 5,
}
