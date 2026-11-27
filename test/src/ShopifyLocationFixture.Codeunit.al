namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using System.TestLibraries.Utilities;

/// <summary>Seeds and cleans only issue 15 mock data for AL and bilingual MCP verification.</summary>
codeunit 97572 "Shopify Location Fixture ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    /// <summary>Creates fixtures without Shopify credentials.</summary>
    [Test]
    procedure A1SeedFixture()
    var
        Stub: Codeunit "Shopify Location Stub ori";
    begin
        // Story #15, AC06 | Time: none | Risk: None
        Cleanup();
        SeedShop('X15-OK', true);
        SeedShop('X15-FAIL', true);
        SeedShop('X15-DISABLED', false);
        SeedShop('X15-EMPTY', true);
        Stub.SeedLocation('X15-OK', 975700001, 'X15 Existing', true);
        Stub.SeedLocation('X15-OK', 975700003, 'X15 Stale', true);
        Stub.SeedLocation('X15-FAIL', 975700001, 'X15 Existing', true);
        Stub.SeedLocation('X15-FAIL', 975700003, 'X15 Stale', true);
        Stub.SeedLocation('X15-EMPTY', 975700003, 'X15 Stale', true);
        Commit();
    end;

    /// <summary>Removes fixtures and checks both tables are empty for the fixture prefix.</summary>
    [Test]
    procedure A2RemoveFixture()
    var
        Shop: Record "Shpfy Shop";
        Location: Record "Shpfy Shop Location";
        Assert: Codeunit "Library Assert";
    begin
        // Story #15, AC06 | Time: none | Risk: None
        Cleanup();
        Shop.SetFilter(Code, 'X15-*');
        Location.SetFilter("Shop Code", 'X15-*');
        Assert.IsTrue(Shop.IsEmpty(), 'Fixture shops removed.');
        Assert.IsTrue(Location.IsEmpty(), 'Fixture locations and mappings removed.');
    end;

    /// <summary>Seeds one enabled or disabled fixture shop with no credential.</summary>
    /// <param name="ShopCode">Fixture code.</param>
    /// <param name="IsEnabled">Enabled state.</param>
    procedure SeedShop(ShopCode: Code[20]; IsEnabled: Boolean)
    var
        Shop: Record "Shpfy Shop";
    begin
        Shop.Init();
        Shop.Code := ShopCode;
        Shop.Enabled := IsEnabled;
        Shop.Insert();
        Commit();
    end;

    /// <summary>Deletes only issue 15 fixtures, leaving demo and other test data alone.</summary>
    procedure Cleanup()
    var
        Shop: Record "Shpfy Shop";
        Location: Record "Shpfy Shop Location";
    begin
        Location.SetFilter("Shop Code", 'X15-*');
        Location.DeleteAll();
        Shop.SetFilter(Code, 'X15-*');
        Shop.DeleteAll();
        Commit();
    end;
}
