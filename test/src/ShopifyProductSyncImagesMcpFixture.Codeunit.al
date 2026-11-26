namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue #12: self-seeded fixture for MCP checks of Shopify.Product.SyncImages. A1SeedFixture commits the enabled shop MCP12
/// (Sync Item Images = To Shopify, logging disabled) and the disabled-direction shop MCP12D; A2RemoveFixture deletes them.
/// </summary>
codeunit 97542 "Shpfy SyncImg MCP ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Seeds the enabled shop MCP12 (To Shopify) and the enabled shop MCP12D (Sync Item Images Disabled).</summary>
    [Test]
    procedure A1SeedFixture()
    var
        Shop: Record "Shpfy Shop";
    begin
        RemoveAll();
        SeedShop('MCP12', Shop."Sync Item Images"::"To Shopify");
        SeedShop('MCP12D', Shop."Sync Item Images"::" ");
        Commit();
        Assert.IsTrue(Shop.Get('MCP12'), 'Fixture shop exists.');
    end;

    /// <summary>Removes everything A1SeedFixture created.</summary>
    [Test]
    procedure A2RemoveFixture()
    var
        Shop: Record "Shpfy Shop";
    begin
        RemoveAll();
        Assert.IsFalse(Shop.Get('MCP12'), 'Fixture shop is removed.');
        Assert.IsFalse(Shop.Get('MCP12D'), 'Fixture shop is removed.');
    end;

    local procedure SeedShop(ShopCode: Code[20]; Direction: Option)
    var
        Shop: Record "Shpfy Shop";
    begin
        Shop.Init();
        Shop.Code := ShopCode;
        Shop.Insert();
        Shop.Enabled := true;
        Shop."Logging Mode" := Shop."Logging Mode"::Disabled;
        Shop."Sync Item Images" := Direction;
        Shop.Modify();
    end;

    local procedure RemoveAll()
    var
        Shop: Record "Shpfy Shop";
    begin
        if Shop.Get('MCP12') then
            Shop.Delete(true);
        if Shop.Get('MCP12D') then
            Shop.Delete(true);
        Commit();
    end;
}
