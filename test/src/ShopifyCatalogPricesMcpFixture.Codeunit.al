namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using System.TestLibraries.Utilities;

/// <summary>Seeds and removes the reserved catalog-price MCP fixtures; no tokens or live calls.</summary>
codeunit 97522 "Shpfy Catalog MCP Fixture ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    /// <summary>Seeds owned demo records for bilingual MCP checks.</summary>
    [Test]
    procedure A1SeedFixture()
    var
        Stub: Codeunit "Shpfy Catalog Prices Stub ori";
    begin
        Stub.Seed('XSC22-MCP');
    end;

    /// <summary>Removes fixture records and verifies absence.</summary>
    [Test]
    procedure A2RemoveFixture()
    var
        Shop: Record "Shpfy Shop";
        Catalog: Record "Shpfy Catalog";
        Stub: Codeunit "Shpfy Catalog Prices Stub ori";
        Assert: Codeunit "Library Assert";
        Skipped: RecordRef;
    begin
        Stub.Cleanup();
        Assert.IsFalse(Shop.Get('XSC22-MCP'), 'Fixture shop removed.');
        Catalog.SetRange(Id, 97520001, 97520005);
        Assert.IsTrue(Catalog.IsEmpty(), 'Fixture catalogs removed.');
        Skipped.Open(30159);
        Skipped.Field(2).SetRange(97520001, 97520005);
        Assert.IsTrue(Skipped.IsEmpty(), 'Fixture skip logs removed.');
    end;
}
