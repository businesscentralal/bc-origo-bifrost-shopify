namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.Document;
using System.TestLibraries.Utilities;

/// <summary>Own-tenant demo fixtures for issue 28; no credentials or live Shopify access.</summary>
codeunit 97526 "Shopify ForceSync Fixture ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    /// <summary>Seeds reserved orders for bilingual MCP verification.</summary>
    [Test]
    procedure A1SeedFixture()
    begin
        Seed();
    end;

    /// <summary>Removes reserved data and proves cleanup.</summary>
    [Test]
    procedure A2RemoveFixture()
    var
        Header: Record "Shpfy Order Header";
        Line: Record "Shpfy Order Line";
        Attribute: Record "Shpfy Order Attribute";
        Assert: Codeunit "Library Assert";
        Log: RecordRef;
    begin
        Cleanup();
        Header.SetRange("Shopify Order Id", 8928000028L, 8928000039L);
        Line.SetRange("Shopify Order Id", 8928000028L, 8928000039L);
        Attribute.SetRange("Order Id", 8928000028L, 8928000039L);
        Log.Open(30115);
        Log.Field(1).SetRange(928000000, 928000011);
        Assert.IsTrue(Header.IsEmpty() and Line.IsEmpty() and Attribute.IsEmpty() and Log.IsEmpty(), 'All reserved order data removed.');
    end;

    /// <summary>Creates distinct happy, failure, guard and processed-order cases.</summary>
    procedure Seed()
    var
        Shop: Record "Shpfy Shop";
        Header: Record "Shpfy Order Header";
        Line: Record "Shpfy Order Line";
        Attribute: Record "Shpfy Order Attribute";
        Sales: Record "Sales Header";
        SalesLine: Record "Sales Line";
        Link: Record "Shpfy Doc. Link To Doc.";
        Index: Integer;
    begin
        Cleanup();
        for Index := 0 to 11 do begin
            Shop.Init();
            Shop.Code := CopyStr('XFS28-' + Format(Index, 0, 9), 1, MaxStrLen(Shop.Code));
            Shop.Enabled := Index <> 6;
            Shop."Archive Processed Orders" := Index in [3, 4, 8];
            Shop."Allow Outgoing Requests" := Index in [5, 9];
            Shop."Fulfillment Service Activated" := Index = 9;
            if Index <> 7 then
                Shop.Insert(false);
            Header.Init();
            Header."Shopify Order Id" := 8928000028L + Index;
            Header."Shop Code" := Shop.Code;
            Header."Shopify Order No." := 'XORIGINAL';
            Header.Processed := Index = 1;
            if Index in [1, 3] then
                Header."Sales Order No." := 'XFS28DOC';
            if Index = 4 then
                Header."Sales Invoice No." := 'XFS28INV';
            Header.Insert(false);
            Line.Init();
            Line."Shopify Order Id" := Header."Shopify Order Id";
            Line."Line Id" := 1;
            Line.Description := 'XORIGINAL';
            Line.Quantity := 1;
            Line.Insert(false);
            Attribute.Init();
            Attribute."Order Id" := Header."Shopify Order Id";
            Attribute."Key" := 'XFS28';
            Attribute."Attribute Value" := 'XORIGINAL';
            Attribute.Insert(false);
        end;
        Sales.Init();
        Sales."Document Type" := Sales."Document Type"::Order;
        Sales."No." := 'XFS28DOC';
        Sales."Your Reference" := 'XUNCHANGED';
        Sales.Insert(false);
        SalesLine.Init();
        SalesLine."Document Type" := Sales."Document Type";
        SalesLine."Document No." := Sales."No.";
        SalesLine."Line No." := 10000;
        SalesLine.Description := 'XUNCHANGED';
        SalesLine.Insert(false);
        Link.Init();
        Link."Shopify Document Type" := Link."Shopify Document Type"::"Shopify Shop Order";
        Link."Shopify Document Id" := 8928000039L;
        Link."Document No." := 'XFS28DOC';
        Link.Insert(false);
        Commit();
    end;

    /// <summary>Deletes only this fixture's reserved records.</summary>
    procedure Cleanup()
    var
        Shop: Record "Shpfy Shop";
        Header: Record "Shpfy Order Header";
        Line: Record "Shpfy Order Line";
        Attribute: Record "Shpfy Order Attribute";
        Link: Record "Shpfy Doc. Link To Doc.";
        Sales: Record "Sales Header";
        SalesLine: Record "Sales Line";
        Log: RecordRef;
    begin
        Line.SetRange("Shopify Order Id", 8928000028L, 8928000039L);
        Line.DeleteAll(false);
        Attribute.SetRange("Order Id", 8928000028L, 8928000039L);
        Attribute.DeleteAll(false);
        Header.SetRange("Shopify Order Id", 8928000028L, 8928000039L);
        Header.DeleteAll(false);
        Log.Open(30115);
        Log.Field(1).SetRange(928000000, 928000011);
        Log.DeleteAll(false);
        Link.SetRange("Shopify Document Id", 8928000028L, 8928000039L);
        Link.DeleteAll(false);
        Shop.SetFilter(Code, 'XFS28-*');
        Shop.DeleteAll(false);
        SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
        SalesLine.SetRange("Document No.", 'XFS28DOC');
        SalesLine.DeleteAll(false);
        if Sales.Get(Sales."Document Type"::Order, 'XFS28DOC') then
            Sales.Delete(false);
        Commit();
    end;
}
