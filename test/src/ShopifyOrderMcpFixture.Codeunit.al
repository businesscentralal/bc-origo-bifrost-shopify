namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue #23: self-seeded fixture for MCP checks of Shopify.Order.Import. A1SeedFixture commits an enabled shop MCP23ON
/// and a disabled shop MCP23OFF; A2RemoveFixture deletes them again. Run in this order, nothing is left behind.
/// </summary>
codeunit 97404 "Shopify Order MCP Fixture ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        EnabledShopTok: Label 'MCP23ON', Locked = true;
        DisabledShopTok: Label 'MCP23OFF', Locked = true;

    /// <summary>Seeds the enabled shop MCP23ON (no Shopify connection) and the disabled shop MCP23OFF.</summary>
    [Test]
    procedure A1SeedFixture()
    begin
        RemoveAll();
        SeedShop(EnabledShopTok, true);
        SeedShop(DisabledShopTok, false);
        Commit();
        Assert.IsTrue(true, 'Fixture seeded.');
    end;

    /// <summary>Removes everything A1SeedFixture created.</summary>
    [Test]
    procedure A2RemoveFixture()
    var
        Shop: Record "Shpfy Shop";
    begin
        RemoveAll();
        Assert.IsFalse(Shop.Get(EnabledShopTok) or Shop.Get(DisabledShopTok), 'Fixture removed.');
    end;

    local procedure SeedShop(ShopCode: Text; Enabled: Boolean)
    var
        Shop: Record "Shpfy Shop";
    begin
        Shop.Init();
        Shop.Code := CopyStr(ShopCode, 1, MaxStrLen(Shop.Code));
        Shop.Insert();
        Shop.Enabled := Enabled;
        Shop.Modify();
    end;

    local procedure RemoveAll()
    var
        Shop: Record "Shpfy Shop";
    begin
        if Shop.Get(EnabledShopTok) then begin
            Shop.Enabled := false;
            Shop.Modify();
            Shop.Delete(true);
        end;
        if Shop.Get(DisabledShopTok) then
            Shop.Delete(true);
        Commit();
    end;
}
