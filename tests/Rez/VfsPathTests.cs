using OpenAvP2.Vfs;
using Xunit;

namespace OpenAvP2.Tests.Rez;

/// <summary>
/// Path canonicalisation is the defence against the cross-platform case and
/// separator bugs called out as a standing risk in the Technical Design
/// Document, section 23.
/// </summary>
public class VfsPathTests
{
    [Theory]
    [InlineData(@"Worlds\SinglePlayer\Marine\m1s1.dat", "worlds/singleplayer/marine/m1s1.dat")]
    [InlineData("Textures/Characters/Marine.dtx", "textures/characters/marine.dtx")]
    [InlineData(@"MODELS\CHARACTERS\ALIEN.ABC", "models/characters/alien.abc")]
    public void Canonicalize_LowercasesAndNormalizesSeparators(string input, string expected) =>
        Assert.Equal(expected, VfsPath.Canonicalize(input));

    [Theory]
    [InlineData("/worlds/m1s1.dat")]
    [InlineData(@"\worlds\m1s1.dat")]
    [InlineData("worlds//m1s1.dat")]
    [InlineData(@"worlds\/m1s1.dat")]
    [InlineData("./worlds/m1s1.dat")]
    [InlineData("worlds/./m1s1.dat")]
    public void Canonicalize_StripsEmptyAndCurrentDirectorySegments(string input) =>
        Assert.Equal("worlds/m1s1.dat", VfsPath.Canonicalize(input));

    [Fact]
    public void Canonicalize_ResolvesParentSegments() =>
        Assert.Equal("worlds/m1s1.dat", VfsPath.Canonicalize("worlds/multiplayer/../m1s1.dat"));

    [Fact]
    public void Canonicalize_RejectsPathsEscapingTheRoot() =>
        Assert.Throws<ArgumentException>(() => VfsPath.Canonicalize("../../etc/passwd"));

    [Fact]
    public void Canonicalize_ReturnsEmptyForPathsWithoutSegments() =>
        Assert.Equal(string.Empty, VfsPath.Canonicalize("/"));

    [Fact]
    public void AreEquivalent_MatchesPathsDifferingOnlyByCaseAndSeparator() =>
        Assert.True(VfsPath.AreEquivalent(@"Worlds\Marine\M1S1.DAT", "worlds/marine/m1s1.dat"));

    [Theory]
    [InlineData("worlds/m1s1.dat", "dat")]
    [InlineData(@"Textures\Wall01.DTX", "dtx")]
    [InlineData("readme", "")]
    [InlineData("worlds/m1s1.", "")]
    [InlineData("some.dir/readme", "")]
    public void Extension_ReturnsLowercasedExtensionWithoutDot(string input, string expected) =>
        Assert.Equal(expected, VfsPath.Extension(input));
}
