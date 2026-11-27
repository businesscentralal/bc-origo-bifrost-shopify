namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Inventory.Item;
using System.TestLibraries.Utilities;

/// <summary>Issue 10 fixtures. Only CRONUS demo rows with the reserved BIFT10 prefix are created and removed.</summary>
codeunit 97502 "Shpfy AddVariants MCP ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    /// <summary>Seeds the isolated mock product, shop and two items for MCP samples.</summary>
    [Test]
    procedure A1SeedFixture()
    begin
        Seed();
    end;

    /// <summary>Removes every fixture row after MCP samples.</summary>
    [Test]
    procedure A2RemoveFixture()
    var
        Variant: Record "Shpfy Variant";
        Assert: Codeunit "Library Assert";
    begin
        Cleanup();
        Variant.SetRange("Product Id", 8910000010L);
        Assert.IsTrue(Variant.IsEmpty(), 'Fixture variants removed.');
    end;

    /// <summary>Seeds a product and two items for the mock-only dispatcher tests.</summary>
    procedure Seed()
    var
        Shop: Record "Shpfy Shop";
        Product: Record "Shpfy Product";
    begin
        Cleanup();
        Shop.Init();
        Shop.Code := 'BIFT10';
        Shop.Insert();
        Shop.Enabled := true;
        Shop.Modify();
        Product.Init();
        Product.Id := 8910000010L;
        Product."Shop Code" := Shop.Code;
        Product.Title := 'Bifrost issue 10 mock product';
        Product.Insert();
        AddItem('BIFT10-A');
        AddItem('BIFT10-B');
        Commit();
    end;

    /// <summary>Creates one reserved demo item; callers commit before dispatching.</summary>
    /// <param name="ItemNo">Reserved BIFT10 item number.</param>
    procedure AddItem(ItemNo: Code[20])
    var
        Item: Record Item;
    begin
        if CopyStr(ItemNo, 1, 6) <> 'BIFT10' then
            Error('Fixture item must use the reserved BIFT10 prefix.');
        Item.Init();
        Item."No." := ItemNo;
        Item.Description := 'Bifrost issue 10 mock item';
        Item.Insert();
    end;

    /// <summary>Removes only the reserved fixture product, variants, items and shop.</summary>
    procedure Cleanup()
    var
        Variant: Record "Shpfy Variant";
        Product: Record "Shpfy Product";
        Shop: Record "Shpfy Shop";
        Item: Record Item;
    begin
        Variant.SetRange("Product Id", 8910000010L);
        Variant.DeleteAll(false);
        if Product.Get(8910000010L) then
            Product.Delete(false);
        Item.SetFilter("No.", 'BIFT10*');
        Item.DeleteAll(false);
        if Shop.Get('BIFT10') then
            Shop.Delete(false);
        Commit();
    end;
}
