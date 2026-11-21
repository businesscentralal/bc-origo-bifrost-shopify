namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue #6: self-seeded fixture for MCP checks of Shopify.Product.Sync. A1SeedFixture commits an enabled shop
/// MCP6 and a disabled shop MCP6OFF; A2RemoveFixture deletes them again.
/// </summary>
codeunit 97461 "Shpfy Prod Sync MCP ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Seeds the enabled shop MCP6 and the disabled shop MCP6OFF.</summary>
    [Test]
    procedure A1SeedFixture()
    var
        Shop: Record "Shpfy Shop";
    begin
        RemoveAll();
        SeedShop('MCP6', true);
        SeedShop('MCP6OFF', false);
        Commit();
        Assert.IsTrue(Shop.Get('MCP6'), 'Fixture shop exists.');
    end;

    /// <summary>Removes everything A1SeedFixture created.</summary>
    [Test]
    procedure A2RemoveFixture()
    var
        Shop: Record "Shpfy Shop";
    begin
        RemoveAll();
        Assert.IsFalse(Shop.Get('MCP6'), 'Fixture shop is removed.');
        Assert.IsFalse(Shop.Get('MCP6OFF'), 'Disabled fixture shop is removed.');
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
        if Shop.Get('MCP6') then
            Shop.Delete(true);
        if Shop.Get('MCP6OFF') then
            Shop.Delete(true);
        Commit();
    end;
}
