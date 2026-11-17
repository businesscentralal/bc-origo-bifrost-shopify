namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Inventory.Item;
using Microsoft.Sales.Customer;
using Microsoft.Sales.Document;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue #24: self-seeded fixture for MCP checks of Shopify.Order.CreateSalesDocument. A1SeedFixture commits shop
/// MCP24 with a customer, an item and two orders (950000011 and 950000012); A2RemoveFixture deletes them again
/// together with any sales order that was created. Run in this order, the two functions leave no data behind.
/// </summary>
codeunit 97471 "Shopify Order MCP Fixture ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        ShopCodeTok: Label 'MCP24', Locked = true;

    /// <summary>Seeds shop MCP24 with two unprocessed orders, each with one line.</summary>
    [Test]
    procedure A1SeedFixture()
    var
        Shop: Record "Shpfy Shop";
        Variant: Record "Shpfy Variant";
        Customer: Record Customer;
        Item: Record Item;
        LibrarySales: Codeunit "Library - Sales";
        LibraryInventory: Codeunit "Library - Inventory";
    begin
        RemoveAll();
        LibrarySales.CreateCustomer(Customer);
        LibraryInventory.CreateItem(Item);
        Shop.Init();
        Shop.Code := ShopCodeTok;
        Shop.Enabled := true;
        Shop.Insert();
        SetShopUrl(Shop, 'https://mcp24.myshopify.com');
        Shop."Customer Mapping Type" := Shop."Customer Mapping Type"::DefaultCustomer;
        Shop."Default Customer No." := Customer."No.";
        Shop.Modify();
        Variant.Init();
        Variant.Id := 960000011;
        Variant."Shop Code" := ShopCodeTok;
        Variant."Item No." := Item."No.";
        Variant.Insert();
        SeedOrder(950000011, 970000011, Variant.Id, Item);
        SeedOrder(950000012, 970000012, Variant.Id, Item);
        Commit();
        Assert.IsTrue(Shop.Get(ShopCodeTok), 'Fixture shop exists.');
    end;

    /// <summary>Removes everything A1SeedFixture and the MCP calls created.</summary>
    [Test]
    procedure A2RemoveFixture()
    var
        Shop: Record "Shpfy Shop";
    begin
        RemoveAll();
        Assert.IsFalse(Shop.Get(ShopCodeTok), 'Fixture shop is removed.');
    end;

    local procedure SeedOrder(OrderId: BigInteger; LineId: BigInteger; VariantId: BigInteger; Item: Record Item)
    var
        OrderHeader: Record "Shpfy Order Header";
        OrderLine: Record "Shpfy Order Line";
    begin
        OrderHeader.Init();
        OrderHeader."Shopify Order Id" := OrderId;
        OrderHeader."Shop Code" := ShopCodeTok;
        OrderHeader."Shopify Order No." := 'MCP24-' + Format(OrderId, 0, 9);
        OrderHeader."Document Date" := WorkDate();
        OrderHeader."Processed Currency Handling" := "Shpfy Currency Handling"::"Shop Currency";
        OrderHeader.Insert();
        OrderLine.Init();
        OrderLine."Shopify Order Id" := OrderId;
        OrderLine."Line Id" := LineId;
        OrderLine."Shopify Variant Id" := VariantId;
        OrderLine.Description := Item.Description;
        OrderLine.Quantity := 2;
        OrderLine."Unit Price" := 10;
        OrderLine."Item No." := Item."No.";
        OrderLine.Insert();
    end;

    local procedure SetShopUrl(var Shop: Record "Shpfy Shop"; Url: Text)
    var
        ShopRef: RecordRef;
        UrlField: FieldRef;
    begin
        // The Shopify URL field is internal to Microsoft's app; the field reference reaches it without writing around any validation.
        ShopRef.GetTable(Shop);
        UrlField := ShopRef.Field(2);
        UrlField.Value := Url;
        ShopRef.Modify();
        ShopRef.SetTable(Shop);
    end;

    local procedure RemoveAll()
    var
        Shop: Record "Shpfy Shop";
        OrderHeader: Record "Shpfy Order Header";
        OrderLine: Record "Shpfy Order Line";
        Variant: Record "Shpfy Variant";
        SalesHeader: Record "Sales Header";
        Customer: Record Customer;
        Item: Record Item;
    begin
        OrderHeader.SetRange("Shop Code", ShopCodeTok);
        if OrderHeader.FindSet() then
            repeat
                if OrderHeader."Sales Order No." <> '' then
                    if SalesHeader.Get(SalesHeader."Document Type"::Order, OrderHeader."Sales Order No.") then
                        SalesHeader.Delete(true);
                OrderLine.SetRange("Shopify Order Id", OrderHeader."Shopify Order Id");
                OrderLine.DeleteAll(true);
            until OrderHeader.Next() = 0;
        OrderHeader.DeleteAll(true);
        if Variant.Get(960000011) then begin
            if Item.Get(Variant."Item No.") then
                Item.Delete(true);
            Variant.Delete(true);
        end;
        if Shop.Get(ShopCodeTok) then begin
            if Shop."Default Customer No." <> '' then
                if Customer.Get(Shop."Default Customer No.") then
                    Customer.Delete(true);
            Shop.Delete(true);
        end;
        Commit();
    end;
}
