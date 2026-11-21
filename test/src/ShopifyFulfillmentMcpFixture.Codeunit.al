namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.History;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue #29: self-seeded fixture for MCP checks of Shopify.Fulfillment.Sync. A1SeedFixture commits a shop, an imported order
/// and three posted shipments (with lines, without lines, already sent); A2RemoveFixture deletes them again.
/// </summary>
codeunit 97431 "Shpfy Fulfill MCP Fixture ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        ShopCodeTok: Label 'MCP29', Locked = true;

    /// <summary>Seeds shop MCP29, order 930000039 and shipments MCP29-S1 (lines), MCP29-S2 (no lines), MCP29-S3 (already sent).</summary>
    [Test]
    procedure A1SeedFixture()
    var
        Shop: Record "Shpfy Shop";
        OrderHeader: Record "Shpfy Order Header";
    begin
        RemoveAll();
        Shop.Init();
        Shop.Code := ShopCodeTok;
        Shop.Insert();
        OrderHeader.Init();
        OrderHeader."Shopify Order Id" := 930000039;
        OrderHeader."Shop Code" := ShopCodeTok;
        OrderHeader."Shopify Order No." := 'MCP29-1';
        OrderHeader.Insert();
        SeedShipment('MCP29-S1', true, 0);
        SeedShipment('MCP29-S2', false, 0);
        SeedShipment('MCP29-S3', true, 888);
        Commit();
        Assert.IsTrue(Shop.Get(ShopCodeTok), 'Fixture shop exists.');
    end;

    /// <summary>Removes everything A1SeedFixture created.</summary>
    [Test]
    procedure A2RemoveFixture()
    var
        Shop: Record "Shpfy Shop";
    begin
        RemoveAll();
        Assert.IsFalse(Shop.Get(ShopCodeTok), 'Fixture shop is removed.');
    end;

    local procedure SeedShipment(ShipmentNo: Code[20]; WithLine: Boolean; FulfillmentId: BigInteger)
    var
        SalesShipmentHeader: Record "Sales Shipment Header";
        SalesShipmentLine: Record "Sales Shipment Line";
    begin
        SalesShipmentHeader.Init();
        SalesShipmentHeader."No." := ShipmentNo;
        SalesShipmentHeader."Shpfy Order Id" := 930000039;
        SalesShipmentHeader."Shpfy Fulfillment Id" := FulfillmentId;
        SalesShipmentHeader.Insert();
        if WithLine then begin
            SalesShipmentLine.Init();
            SalesShipmentLine."Document No." := ShipmentNo;
            SalesShipmentLine."Line No." := 10000;
            SalesShipmentLine.Type := SalesShipmentLine.Type::Item;
            SalesShipmentLine."No." := 'MCP29-I';
            SalesShipmentLine.Quantity := 1;
            SalesShipmentLine.Insert();
        end;
    end;

    local procedure RemoveAll()
    var
        Shop: Record "Shpfy Shop";
        OrderHeader: Record "Shpfy Order Header";
        SalesShipmentHeader: Record "Sales Shipment Header";
        SalesShipmentLine: Record "Sales Shipment Line";
    begin
        SalesShipmentLine.SetFilter("Document No.", 'MCP29-S*');
        SalesShipmentLine.DeleteAll();
        SalesShipmentHeader.SetFilter("No.", 'MCP29-S*');
        SalesShipmentHeader.DeleteAll();
        if OrderHeader.Get(930000039) then
            OrderHeader.Delete(true);
        if Shop.Get(ShopCodeTok) then
            Shop.Delete(true);
        Commit();
    end;
}
