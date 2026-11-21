namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Inventory.Item;
using Microsoft.Sales.Customer;
using Microsoft.Sales.Document;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue #24 and #59: self-seeded fixture for MCP checks of Shopify.Order.CreateSalesDocument. A1SeedFixture commits
/// shop MCP24 (orders 950000011 and 950000012) and shop MCP24A, which is set to Auto Create Credit Memo (order
/// 950000013). A2RemoveFixture deletes them again together with any sales document that was created.
/// </summary>
codeunit 97471 "Shopify Order MCP Fixture ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        ShopCodeTok: Label 'MCP24', Locked = true;
        AutoShopCodeTok: Label 'MCP24A', Locked = true;

    /// <summary>Seeds shop MCP24 with two unprocessed orders, and shop MCP24A (Auto Create Credit Memo) with one order.</summary>
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
        InsertShop(ShopCodeTok, Customer."No.", "Shpfy ReturnRefund ProcessType"::"Import Only", 'https://mcp24.myshopify.com');
        Variant.Init();
        Variant.Id := 960000011;
        Variant."Shop Code" := ShopCodeTok;
        Variant."Item No." := Item."No.";
        Variant.Insert();
        SeedOrder(ShopCodeTok, 950000011, 970000011, Variant.Id, Item);
        SeedOrder(ShopCodeTok, 950000012, 970000012, Variant.Id, Item);
        LibrarySales.CreateCustomer(Customer);
        InsertShop(AutoShopCodeTok, Customer."No.", "Shpfy ReturnRefund ProcessType"::"Auto Create Credit Memo", 'https://mcp24a.myshopify.com');
        SeedOrder(AutoShopCodeTok, 950000013, 970000013, Variant.Id, Item);
        Commit();
        Assert.IsTrue(Shop.Get(ShopCodeTok), 'Fixture shop exists.');
        Assert.IsTrue(Shop.Get(AutoShopCodeTok), 'Fixture auto credit memo shop exists.');
    end;

    /// <summary>Removes everything A1SeedFixture and the MCP calls created.</summary>
    [Test]
    procedure A2RemoveFixture()
    var
        Shop: Record "Shpfy Shop";
    begin
        RemoveAll();
        Assert.IsFalse(Shop.Get(ShopCodeTok), 'Fixture shop is removed.');
        Assert.IsFalse(Shop.Get(AutoShopCodeTok), 'Fixture auto credit memo shop is removed.');
    end;

    local procedure InsertShop(ShopCode: Code[20]; CustomerNo: Code[20]; RefundProcess: Enum "Shpfy ReturnRefund ProcessType"; Url: Text)
    var
        Shop: Record "Shpfy Shop";
    begin
        Shop.Init();
        Shop.Code := ShopCode;
        Shop.Enabled := true;
        Shop.Insert();
        SetShopUrl(Shop, Url);
        Shop."Customer Mapping Type" := Shop."Customer Mapping Type"::DefaultCustomer;
        Shop."Default Customer No." := CustomerNo;
        Shop."Auto Release Sales Orders" := false;
        // Without this, report 30103 asks Shopify for an access token; the fixture never calls a live shop.
        Shop."Order Attributes To Shopify" := false;
        Shop."Return and Refund Process" := RefundProcess;
        Shop.Modify();
    end;

    local procedure SeedOrder(ShopCode: Code[20]; OrderId: BigInteger; LineId: BigInteger; VariantId: BigInteger; Item: Record Item)
    var
        OrderHeader: Record "Shpfy Order Header";
        OrderLine: Record "Shpfy Order Line";
        Shop: Record "Shpfy Shop";
    begin
        Shop.Get(ShopCode);
        OrderHeader.Init();
        OrderHeader."Shopify Order Id" := OrderId;
        OrderHeader."Shop Code" := ShopCode;
        OrderHeader."Sell-to Customer No." := Shop."Default Customer No.";
        OrderHeader."Bill-to Customer No." := Shop."Default Customer No.";
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
        Variant: Record "Shpfy Variant";
        Item: Record Item;
    begin
        RemoveShop(ShopCodeTok);
        RemoveShop(AutoShopCodeTok);
        if Variant.Get(960000011) then begin
            if Item.Get(Variant."Item No.") then
                Item.Delete(true);
            Variant.Delete(true);
        end;
        Commit();
    end;

    local procedure RemoveShop(ShopCode: Code[20])
    var
        Shop: Record "Shpfy Shop";
        OrderHeader: Record "Shpfy Order Header";
        OrderLine: Record "Shpfy Order Line";
        SalesHeader: Record "Sales Header";
        Customer: Record Customer;
    begin
        OrderHeader.SetRange("Shop Code", ShopCode);
        if OrderHeader.FindSet() then
            repeat
                if OrderHeader."Sales Order No." <> '' then
                    if SalesHeader.Get(SalesHeader."Document Type"::Order, OrderHeader."Sales Order No.") then
                        SalesHeader.Delete(true);
                if OrderHeader."Sales Invoice No." <> '' then
                    if SalesHeader.Get(SalesHeader."Document Type"::Invoice, OrderHeader."Sales Invoice No.") then
                        SalesHeader.Delete(true);
                OrderLine.SetRange("Shopify Order Id", OrderHeader."Shopify Order Id");
                OrderLine.DeleteAll(true);
            until OrderHeader.Next() = 0;
        OrderHeader.DeleteAll(true);
        if Shop.Get(ShopCode) then begin
            if Shop."Default Customer No." <> '' then
                if Customer.Get(Shop."Default Customer No.") then
                    Customer.Delete(true);
            Shop.Delete(true);
        end;
    end;
}
