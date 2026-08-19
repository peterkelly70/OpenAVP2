// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors

using OpenAvP2.Installation;
using Xunit;

namespace OpenAvP2.Tests.Installation;

public class InstallationValidatorTests
{
    private const string Root = "/games/avp2";

    private static InstallationValidator Validator(FakeFileSystem fileSystem) => new(fileSystem);

    [Fact]
    public void Validate_AcceptsAnInstallationContainingTheBaseArchive()
    {
        var fs = new FakeFileSystem()
            .WithFile($"{Root}/AVP2.REZ", "archive")
            .WithDirectory($"{Root}/Sound");

        var result = Validator(fs).Validate(Root);

        Assert.True(result.IsValid);
        Assert.Empty(result.Failures.Where(f => f.Requirement.Contains("avp2.rez")));
    }

    [Fact]
    public void Validate_IsCaseInsensitiveAboutArchiveNames()
    {
        // The shipped casing cannot be relied on, and on Linux and macOS the
        // filesystem will not paper over a mismatch.
        var fs = new FakeFileSystem().WithFile($"{Root}/avp2.rez", "archive");

        Assert.True(Validator(fs).Validate(Root).IsValid);
    }

    [Fact]
    public void Validate_RejectsADirectoryWithoutTheBaseArchive()
    {
        var fs = new FakeFileSystem().WithFile($"{Root}/readme.txt", "not a game");

        var result = Validator(fs).Validate(Root);

        Assert.False(result.IsValid);
        Assert.Contains(result.Failures, f => f.Requirement.Contains("avp2.rez"));
    }

    [Fact]
    public void Validate_RejectsAMissingDirectoryWithoutThrowing()
    {
        var result = Validator(new FakeFileSystem()).Validate("/nonexistent");

        Assert.False(result.IsValid);
        Assert.Contains(result.Failures, f => f.Requirement.Contains("directory exists"));
    }

    [Fact]
    public void Validate_ReportsEveryCheckSoTheUserCanSeeWhatIsMissing()
    {
        var fs = new FakeFileSystem().WithFile($"{Root}/AVP2.REZ", "archive");

        var result = Validator(fs).Validate(Root);

        // Directory exists, the required archive, and each expected directory.
        Assert.Equal(4, result.Checks.Count);
        Assert.All(result.Checks, c => Assert.False(string.IsNullOrWhiteSpace(c.Detail)));
    }

    [Fact]
    public void Validate_TreatsMissingOptionalDirectoriesAsAdvisoryOnly()
    {
        // Content may live entirely in archives, so absent directories must not
        // disqualify an otherwise valid installation.
        var fs = new FakeFileSystem().WithFile($"{Root}/avp2.rez", "archive");

        var result = Validator(fs).Validate(Root);

        Assert.True(result.IsValid);
        Assert.Contains(result.Failures, f => f.Requirement.Contains("Directory"));
    }
}
