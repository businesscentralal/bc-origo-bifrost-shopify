namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Integration.Shopify;
using Microsoft.Sales.Customer;
using Microsoft.Sales.Document;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue #30: self-seeded fixture for MCP checks of Shopify.Refund.CreateCreditMemo. SeedFixture commits a shop,
/// order and two refunds; RemoveFixture deletes them again together with any credit memo that was created.
/// Run in this order, the two functions leave no data behind.
/// </summary>
codeunit 97402 "Shopify Refund MCP Fixture ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        ShopCodeTok: Label 'MCP30', Locked = true;

    /// <summary>Seeds shop MCP30 with a processed order (refund 940000011) and an unprocessed order (refund 940000012).</summary>
    [Test]
    procedure A1SeedFixture()
    var
        Shop: Record "Shpfy Shop";
        Customer: Record Customer;
        LibrarySales: Codeunit "Library - Sales";
        GLAccount: Record "G/L Account";
    begin
        RemoveAll();
        LibrarySales.CreateCustomer(Customer);
        Shop.Init();
        Shop.Code := ShopCodeTok;
        Shop.Insert();
        Shop."Process Returns As" := Shop."Process Returns As"::"Credit Memo";
        Shop."Return and Refund Process" := Shop."Return and Refund Process"::"Auto Create Credit Memo";
        // An existing posting account is reused: the fixture creates no G/L account, so none has to be deleted.
        GLAccount.SetRange("Account Type", GLAccount."Account Type"::Posting);
        GLAccount.SetRange("Direct Posting", true);
        GLAccount.SetRange(Blocked, false);
        GLAccount.SetFilter("Gen. Prod. Posting Group", '<>%1', '');
        GLAccount.FindFirst();
        Shop."Refund Account" := GLAccount."No.";
        Shop.Modify();
        SeedRefund(940000011, 930000011, Customer."No.", true);
        SeedRefund(940000012, 930000012, Customer."No.", false);
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

    local procedure SeedRefund(RefundId: BigInteger; OrderId: BigInteger; CustomerNo: Code[20]; OrderProcessed: Boolean)
    var
        OrderHeader: Record "Shpfy Order Header";
        RefundHeader: Record "Shpfy Refund Header";
    begin
        OrderHeader.Init();
        OrderHeader."Shopify Order Id" := OrderId;
        OrderHeader."Shop Code" := ShopCodeTok;
        OrderHeader."Shopify Order No." := 'MCP30-' + Format(OrderId, 0, 9);
        OrderHeader."Sell-to Customer No." := CustomerNo;
        OrderHeader."Bill-to Customer No." := CustomerNo;
        OrderHeader.Processed := OrderProcessed;
        OrderHeader."Processed Currency Handling" := "Shpfy Currency Handling"::"Shop Currency";
        OrderHeader.Insert();
        RefundHeader.Init();
        RefundHeader."Refund Id" := RefundId;
        RefundHeader."Order Id" := OrderId;
        RefundHeader."Shop Code" := ShopCodeTok;
        RefundHeader."Created At" := CurrentDateTime();
        RefundHeader."Total Refunded Amount" := 100;
        RefundHeader.Insert();
    end;

    local procedure RemoveAll()
    var
        Shop: Record "Shpfy Shop";
        OrderHeader: Record "Shpfy Order Header";
        RefundHeader: Record "Shpfy Refund Header";
        DocLink: Record "Shpfy Doc. Link To Doc.";
        SalesHeader: Record "Sales Header";
        Customer: Record Customer;
        CustomerNo: Code[20];
    begin
        OrderHeader.SetRange("Shop Code", ShopCodeTok);
        if OrderHeader.FindFirst() then
            CustomerNo := OrderHeader."Sell-to Customer No.";
        DocLink.SetRange("Shopify Document Type", "Shpfy Shop Document Type"::"Shopify Shop Refund");
        DocLink.SetFilter("Shopify Document Id", '940000011|940000012');
        if DocLink.FindSet() then
            repeat
                if SalesHeader.Get(SalesHeader."Document Type"::"Credit Memo", DocLink."Document No.") then
                    SalesHeader.Delete(true);
            until DocLink.Next() = 0;
        DocLink.DeleteAll();
        RefundHeader.SetFilter("Refund Id", '940000011|940000012');
        RefundHeader.DeleteAll(true);
        OrderHeader.DeleteAll(true);
        if Shop.Get(ShopCodeTok) then
            Shop.Delete(true);
        if CustomerNo <> '' then
            if Customer.Get(CustomerNo) then
                Customer.Delete(true);
        Commit();
    end;
}
