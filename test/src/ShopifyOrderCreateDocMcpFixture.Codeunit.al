namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.Customer;
using Microsoft.Sales.Document;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue #24: self-seeded fixture for MCP checks of Shopify.Order.CreateSalesDocument. A1SeedFixture commits shop
/// MCP24 with order 950000011 (a customer that can be used) and order 950000012 (a blocked customer); A2RemoveFixture
/// deletes them again together with the customers and any sales document that was created.
/// </summary>
codeunit 97471 "Shpfy Order CreateDoc MCP ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        ShopCodeTok: Label 'MCP24', Locked = true;

    /// <summary>Seeds shop MCP24 with orders 950000011 (usable customer) and 950000012 (blocked customer).</summary>
    [Test]
    procedure A1SeedFixture()
    var
        Shop: Record "Shpfy Shop";
    begin
        RemoveAll();
        Shop.Init();
        Shop.Code := ShopCodeTok;
        Shop."Auto Release Sales Orders" := false;
        // Assigned without validation: no Shopify connection is set up and no Shopify call is made.
        Shop.Enabled := true;
        // The shop does not write the BC document number back to Shopify as an order attribute.
        Shop."Order Attributes To Shopify" := false;
        Shop.Insert();
        SetShopUrl(Shop);
        SeedOrder(950000011, false);
        SeedOrder(950000012, true);
        Commit();
        Assert.IsTrue(Shop.Get(ShopCodeTok), 'Fixture shop exists.');
    end;

    /// <summary>Removes everything A1SeedFixture and the MCP calls created.</summary>
    [Test]
    procedure A2RemoveFixture()
    var
        Shop: Record "Shpfy Shop";
        OrderHeader: Record "Shpfy Order Header";
    begin
        RemoveAll();
        Assert.IsFalse(Shop.Get(ShopCodeTok), 'Fixture shop is removed.');
        OrderHeader.SetRange("Shop Code", ShopCodeTok);
        Assert.IsTrue(OrderHeader.IsEmpty(), 'Fixture orders are removed.');
    end;

    local procedure SeedOrder(OrderId: BigInteger; BlockCustomer: Boolean)
    var
        OrderHeader: Record "Shpfy Order Header";
        Customer: Record Customer;
        LibrarySales: Codeunit "Library - Sales";
    begin
        LibrarySales.CreateCustomer(Customer);
        if BlockCustomer then begin
            Customer.Blocked := Customer.Blocked::All;
            Customer.Modify();
        end;
        OrderHeader.Init();
        OrderHeader."Shopify Order Id" := OrderId;
        OrderHeader."Shop Code" := ShopCodeTok;
        OrderHeader."Shopify Order No." := 'MCP24-' + Format(OrderId, 0, 9);
        OrderHeader."Sell-to Customer No." := Customer."No.";
        OrderHeader."Bill-to Customer No." := Customer."No.";
        OrderHeader."Document Date" := WorkDate();
        OrderHeader."Processed Currency Handling" := "Shpfy Currency Handling"::"Shop Currency";
        OrderHeader.Insert();
    end;

    local procedure RemoveAll()
    var
        OrderHeader: Record "Shpfy Order Header";
        SalesHeader: Record "Sales Header";
        Customer: Record Customer;
        Shop: Record "Shpfy Shop";
    begin
        OrderHeader.SetRange("Shop Code", ShopCodeTok);
        if OrderHeader.FindSet() then
            repeat
                if OrderHeader."Sales Order No." <> '' then
                    if SalesHeader.Get(SalesHeader."Document Type"::Order, OrderHeader."Sales Order No.") then
                        SalesHeader.Delete(true);
                if OrderHeader."Sales Invoice No." <> '' then
                    if SalesHeader.Get(SalesHeader."Document Type"::Invoice, OrderHeader."Sales Invoice No.") then
                        SalesHeader.Delete(true);
                if Customer.Get(OrderHeader."Sell-to Customer No.") then
                    Customer.Delete(true);
            until OrderHeader.Next() = 0;
        OrderHeader.DeleteAll(true);
        if Shop.Get(ShopCodeTok) then
            Shop.Delete(true);
        Commit();
    end;

    local procedure SetShopUrl(var Shop: Record "Shpfy Shop")
    var
        ShopRef: RecordRef;
        UrlRef: FieldRef;
        UrlTok: Label 'https://%1.myshopify.com', Locked = true;
    begin
        // Shopify URL (field 2, caption Shopify Admin URL) is Access = Internal; the order process requires a value. No Shopify call is made.
        ShopRef.GetTable(Shop);
        UrlRef := ShopRef.Field(2);
        UrlRef.Value := StrSubstNo(UrlTok, LowerCase(Shop.Code));
        ShopRef.Modify();
        ShopRef.SetTable(Shop);
    end;
}
