namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue #9: self-seeded fixture for MCP checks of Shopify.Product.SyncPrices. A1SeedFixture commits an enabled shop
/// MCP9 and a disabled shop MCP9OFF; A2RemoveFixture deletes them again.
/// </summary>
codeunit 97441 "Shpfy Prod SyncPrices MCP ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Seeds the enabled shop MCP9 and the disabled shop MCP9OFF.</summary>
    [Test]
    procedure A1SeedFixture()
    var
        Shop: Record "Shpfy Shop";
    begin
        RemoveAll();
        SeedShop('MCP9', true);
        SeedShop('MCP9OFF', false);
        Commit();
        Assert.IsTrue(Shop.Get('MCP9'), 'Fixture shop exists.');
    end;

    /// <summary>Removes everything A1SeedFixture created.</summary>
    [Test]
    procedure A2RemoveFixture()
    var
        Shop: Record "Shpfy Shop";
    begin
        RemoveAll();
        Assert.IsFalse(Shop.Get('MCP9'), 'Fixture shop is removed.');
        Assert.IsFalse(Shop.Get('MCP9OFF'), 'Disabled fixture shop is removed.');
    end;

    local procedure SeedShop(ShopCode: Code[20]; Enabled: Boolean)
    var
        Shop: Record "Shpfy Shop";
    begin
        Shop.Init();
        Shop.Code := ShopCode;
        Shop.Insert();
        Shop.Enabled := Enabled;
        Shop.Modify();
    end;

    local procedure RemoveAll()
    var
        Shop: Record "Shpfy Shop";
    begin
        if Shop.Get('MCP9') then
            Shop.Delete(true);
        if Shop.Get('MCP9OFF') then
            Shop.Delete(true);
        Commit();
    end;
}
