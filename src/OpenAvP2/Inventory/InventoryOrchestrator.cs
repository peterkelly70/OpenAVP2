// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors

using Microsoft.Extensions.Logging;
using OpenAvP2.Installation;
using OpenAvP2.Platform;
using OpenAvP2.Vfs;

namespace OpenAvP2.Inventory;

/// <summary>
/// Scans an AvP2 installation and produces the format inventory that is the exit
/// criterion for roadmap stage 0.
/// </summary>
/// <remarks>
/// The orchestrator owns the sequence of the scan and nothing else: validation,
/// filesystem access and file inspection are all injected. Adding a probe for a
/// newly understood format therefore requires no change here.
/// </remarks>
public sealed class InventoryOrchestrator
{
    private readonly IFileSystem _fileSystem;
    private readonly IInstallationValidator _validator;
    private readonly IReadOnlyList<IFormatProbe> _probes;
    private readonly ILogger<InventoryOrchestrator> _logger;

    /// <summary>Initialises the orchestrator.</summary>
    public InventoryOrchestrator(
        IFileSystem fileSystem,
        IInstallationValidator validator,
        IEnumerable<IFormatProbe> probes,
        ILogger<InventoryOrchestrator> logger)
    {
        ArgumentNullException.ThrowIfNull(fileSystem);
        ArgumentNullException.ThrowIfNull(validator);
        ArgumentNullException.ThrowIfNull(probes);
        ArgumentNullException.ThrowIfNull(logger);

        _fileSystem = fileSystem;
        _validator = validator;
        _probes = probes.ToList();
        _logger = logger;
    }

    /// <summary>
    /// Scans an installation directory.
    /// </summary>
    /// <param name="installationPath">The directory to scan.</param>
    /// <param name="options">Scan options, or null for defaults.</param>
    /// <param name="cancellationToken">Cancels a scan of a large installation.</param>
    /// <returns>
    /// A report describing what was found. A directory that fails validation is
    /// still scanned and reported, so that a near-miss can be diagnosed.
    /// </returns>
    public InventoryReport Scan(
        string installationPath,
        InventoryOptions? options = null,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(installationPath);
        options ??= new InventoryOptions();

        var validation = _validator.Validate(installationPath);
        if (!validation.IsValid)
        {
            foreach (var failure in validation.Failures)
            {
                _logger.LogWarning(
                    "[VFS] Installation check failed: {Requirement} ({Detail})",
                    failure.Requirement, failure.Detail);
            }
        }

        var accumulators = new Dictionary<string, ExtensionAccumulator>(StringComparer.Ordinal);
        var unreadable = new Dictionary<string, string>(StringComparer.Ordinal);
        var fileCount = 0;
        var totalBytes = 0L;

        foreach (var path in _fileSystem.EnumerateFiles(installationPath))
        {
            cancellationToken.ThrowIfCancellationRequested();

            var canonical = VfsPath.Canonicalize(Relative(installationPath, path));
            var extension = VfsPath.Extension(canonical);
            if (extension.Length == 0)
            {
                extension = "(none)";
            }

            long size;
            try
            {
                size = _fileSystem.GetFileSize(path);
            }
            catch (IOException ex)
            {
                unreadable[canonical] = ex.Message;
                continue;
            }
            catch (UnauthorizedAccessException ex)
            {
                unreadable[canonical] = ex.Message;
                continue;
            }

            fileCount++;
            totalBytes += size;

            if (!accumulators.TryGetValue(extension, out var accumulator))
            {
                accumulator = new ExtensionAccumulator();
                accumulators[extension] = accumulator;
            }

            accumulator.Add(size);

            if (!options.ProbeContents)
            {
                continue;
            }

            var result = ProbeFile(path, canonical, unreadable);
            if (result is not null)
            {
                accumulator.AddSignature(result.Signature, canonical, options.ExamplesPerSignature);
            }
        }

        _logger.LogInformation(
            "[VFS] Inventory complete: {FileCount} files, {ExtensionCount} extensions, {Unreadable} unreadable",
            fileCount, accumulators.Count, unreadable.Count);

        return new InventoryReport(
            InstallationPath: installationPath,
            GeneratedUtc: DateTimeOffset.UtcNow,
            ToolVersion: typeof(InventoryOrchestrator).Assembly.GetName().Version?.ToString() ?? "unknown",
            IsValidInstallation: validation.IsValid,
            FileCount: fileCount,
            TotalBytes: totalBytes,
            Extensions: accumulators
                .OrderByDescending(pair => pair.Value.Count)
                .ThenBy(pair => pair.Key, StringComparer.Ordinal)
                .Select(pair => pair.Value.ToSummary(pair.Key))
                .ToList(),
            UnreadableFiles: unreadable);
    }

    private ProbeResult? ProbeFile(
        string path, string canonical, Dictionary<string, string> unreadable)
    {
        foreach (var probe in _probes)
        {
            if (!probe.CanProbe(canonical))
            {
                continue;
            }

            try
            {
                using var stream = _fileSystem.OpenRead(path);
                var result = probe.Probe(canonical, stream);
                if (result is not null)
                {
                    return result;
                }
            }
            catch (IOException ex)
            {
                unreadable[canonical] = ex.Message;
                return null;
            }
            catch (UnauthorizedAccessException ex)
            {
                unreadable[canonical] = ex.Message;
                return null;
            }
        }

        return null;
    }

    private static string Relative(string root, string path) =>
        path.StartsWith(root, StringComparison.Ordinal)
            ? path[root.Length..].TrimStart('/', '\\')
            : path;

    /// <summary>Mutable per-extension tally, collapsed into a summary at the end.</summary>
    private sealed class ExtensionAccumulator
    {
        private readonly Dictionary<string, (int Count, List<string> Examples)> _signatures = new(StringComparer.Ordinal);

        public int Count { get; private set; }

        private long _totalBytes;

        public void Add(long size)
        {
            Count++;
            _totalBytes += size;
        }

        public void AddSignature(string signature, string path, int exampleLimit)
        {
            if (!_signatures.TryGetValue(signature, out var entry))
            {
                entry = (0, []);
                _signatures[signature] = entry;
            }

            entry.Count++;
            if (entry.Examples.Count < exampleLimit)
            {
                entry.Examples.Add(path);
            }

            _signatures[signature] = entry;
        }

        public ExtensionSummary ToSummary(string extension) => new(
            extension,
            Count,
            _totalBytes,
            _signatures
                .OrderByDescending(pair => pair.Value.Count)
                .ThenBy(pair => pair.Key, StringComparer.Ordinal)
                .Select(pair => new SignatureGroup(pair.Key, pair.Value.Count, pair.Value.Examples))
                .ToList());
    }
}
