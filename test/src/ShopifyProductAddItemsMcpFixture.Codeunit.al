namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Inventory.Item;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue #7: self-seeded fixture for MCP checks of Shopify.Product.AddItems. A1SeedFixture commits the enabled shop MCP7 with
/// logging disabled, the blocked item MCP7-BLK and the item MCP7-A; A2RemoveFixture deletes them and any product stored for them.
/// </summary>
codeunit 97492 "Shpfy AddItems MCP ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Seeds the enabled shop MCP7 and the items MCP7-BLK (blocked) and MCP7-A.</summary>
    [Test]
    procedure A1SeedFixture()
    var
        Shop: Record "Shpfy Shop";
    begin
        RemoveAll();
        Shop.Init();
        Shop.Code := 'MCP7';
        Shop.Insert();
        Shop.Enabled := true;
        Shop."Logging Mode" := Shop."Logging Mode"::Disabled;
        Shop.Modify();
        SeedItem('MCP7-BLK', true);
        SeedItem('MCP7-A', false);
        Commit();
        Assert.IsTrue(Shop.Get('MCP7'), 'Fixture shop exists.');
    end;

    /// <summary>Removes everything A1SeedFixture created.</summary>
    [Test]
    procedure A2RemoveFixture()
    var
        Shop: Record "Shpfy Shop";
        Item: Record Item;
    begin
        RemoveAll();
        Assert.IsFalse(Shop.Get('MCP7'), 'Fixture shop is removed.');
        Assert.IsFalse(Item.Get('MCP7-A'), 'Fixture item is removed.');
    end;

    local procedure SeedItem(ItemNo: Code[20]; IsBlocked: Boolean)
    var
        Item: Record Item;
    begin
        Item.Init();
        Item."No." := ItemNo;
        Item.Description := 'Bifrost MCP item ' + ItemNo;
        Item.Blocked := IsBlocked;
        Item.Insert();
    end;

    local procedure RemoveAll()
    var
        Shop: Record "Shpfy Shop";
        Product: Record "Shpfy Product";
        Item: Record Item;
    begin
        Product.SetRange("Shop Code", 'MCP7');
        Product.DeleteAll();
        if Shop.Get('MCP7') then
            Shop.Delete(true);
        if Item.Get('MCP7-BLK') then
            Item.Delete();
        if Item.Get('MCP7-A') then
            Item.Delete();
        Commit();
    end;
}
