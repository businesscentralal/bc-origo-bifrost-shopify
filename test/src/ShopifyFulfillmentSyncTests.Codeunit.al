namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.History;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue #29: Shopify.Fulfillment.Sync refusals and permissions. The success path calls the live Shopify GraphQL API,
/// which a container cannot reach; it is not covered here and is reported as unverified.
/// </summary>
codeunit 97430 "Shpfy Fulfill Sync Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        ShipmentNoTok: Label 'BIFT29-S1', Locked = true;
        ShopCodeTok: Label 'BIFT29', Locked = true;

    /// <summary>A request without shipmentNo is refused with MissingParameter and changes nothing.</summary>
    [Test]
    procedure MissingKeyIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := ExecuteRaw('{}');
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Missing key status.');
        Assert.AreEqual('MissingParameter', ReadText(Response, 'code'), 'Missing key code.');
        Assert.AreEqual('shipmentNo', ReadText(Response, 'parameter'), 'Missing key parameter.');
    end;

    /// <summary>An unknown key is refused as UnknownParameter.</summary>
    [Test]
    procedure UnknownKeyIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := ExecuteRaw('{"shipmentNo":"X","bogus":true}');
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Unknown key status.');
        Assert.AreEqual('UnknownParameter', ReadText(Response, 'code'), 'Unknown key code.');
    end;

    /// <summary>A shipment that does not exist is refused as RecordNotFound.</summary>
    [Test]
    procedure UnknownShipmentIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := Execute('BIFT29-NONE');
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Unknown shipment status.');
        Assert.AreEqual('RecordNotFound', ReadText(Response, 'code'), 'Unknown shipment code.');
    end;

    /// <summary>A shipment not created from a Shopify order is refused and left untouched.</summary>
    [Test]
    procedure NonShopifyShipmentIsRefused()
    begin
        AssertPreconditionRefusal(0, true, true, 0);
    end;

    /// <summary>A shipment that already has a fulfillment is refused and keeps its Id.</summary>
    [Test]
    procedure AlreadySentShipmentIsRefused()
    begin
        AssertPreconditionRefusal(930000029, true, true, 777);
    end;

    /// <summary>A shipment without item lines is refused and not marked as skipped.</summary>
    [Test]
    procedure ShipmentWithoutLinesIsRefused()
    begin
        AssertPreconditionRefusal(930000029, false, true, 0);
    end;

    /// <summary>A shipment whose Shopify order is not imported is refused.</summary>
    [Test]
    procedure ShipmentWithoutImportedOrderIsRefused()
    begin
        AssertPreconditionRefusal(930000029, true, false, 0);
    end;

    /// <summary>The connector report itself fails when the Shopify shop is not reachable and the shipment keeps Fulfillment Id 0.</summary>
    [Test]
    procedure ShopifyFailureLeavesShipmentUnchanged()
    var
        SalesShipmentHeader: Record "Sales Shipment Header";
        SalesShipmentFilter: Record "Sales Shipment Header";
        SyncReport: Report "Shpfy Sync Shipm. to Shopify";
    begin
        Initialize();
        Seed(930000029, true, true, 0);
        SalesShipmentFilter.SetRange("No.", ShipmentNoTok);
        SyncReport.SetTableView(SalesShipmentFilter);
        SyncReport.UseRequestPage(false);
        asserterror SyncReport.RunModal();
        Assert.AreNotEqual('', GetLastErrorText(), 'The failure has a text.');
        SalesShipmentHeader.Get(ShipmentNoTok);
        Assert.IsTrue(SalesShipmentHeader."Shpfy Fulfillment Id" = 0, 'No partial marker is stored.');
        Cleanup();
    end;

    /// <summary>A caller without the app permissions is refused and the shipment is unchanged.</summary>
    [Test]
    procedure CallerWithoutPermissionIsRefused()
    var
        SalesShipmentHeader: Record "Sales Shipment Header";
        Response: JsonObject;
    begin
        Initialize();
        Seed(930000029, true, true, 0);
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        Response := Execute(ShipmentNoTok);
        LowerPermissions.StopLoggingNAVPermissions();
        Assert.AreNotEqual('Success', ReadText(Response, 'status'), 'Caller without permission must be refused.');
        SalesShipmentHeader.Get(ShipmentNoTok);
        Assert.IsTrue(SalesShipmentHeader."Shpfy Fulfillment Id" = 0, 'Shipment unchanged without permission.');
        Cleanup();
    end;

    local procedure AssertPreconditionRefusal(OrderId: BigInteger; WithLines: Boolean; WithOrder: Boolean; FulfillmentId: BigInteger)
    var
        SalesShipmentHeader: Record "Sales Shipment Header";
        Response: JsonObject;
    begin
        Initialize();
        Seed(OrderId, WithLines, WithOrder, FulfillmentId);
        Response := Execute(ShipmentNoTok);
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Refusal status.');
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), 'Refusal code.');
        SalesShipmentHeader.Get(ShipmentNoTok);
        Assert.IsTrue(SalesShipmentHeader."Shpfy Fulfillment Id" = FulfillmentId, 'Shipment keeps its fulfillment Id.');
        Cleanup();
    end;

    local procedure Initialize()
    begin
        Cleanup();
    end;

    local procedure Seed(OrderId: BigInteger; WithLines: Boolean; WithOrder: Boolean; FulfillmentId: BigInteger)
    var
        Shop: Record "Shpfy Shop";
        OrderHeader: Record "Shpfy Order Header";
        SalesShipmentHeader: Record "Sales Shipment Header";
        SalesShipmentLine: Record "Sales Shipment Line";
    begin
        Shop.Init();
        Shop.Code := CopyStr(ShopCodeTok, 1, MaxStrLen(Shop.Code));
        Shop.Insert();
        if WithOrder and (OrderId <> 0) then begin
            OrderHeader.Init();
            OrderHeader."Shopify Order Id" := OrderId;
            OrderHeader."Shop Code" := Shop.Code;
            OrderHeader."Shopify Order No." := 'BIFT29-1';
            OrderHeader.Insert();
        end;
        SalesShipmentHeader.Init();
        SalesShipmentHeader."No." := CopyStr(ShipmentNoTok, 1, MaxStrLen(SalesShipmentHeader."No."));
        SalesShipmentHeader."Shpfy Order Id" := OrderId;
        SalesShipmentHeader."Shpfy Fulfillment Id" := FulfillmentId;
        SalesShipmentHeader.Insert();
        if WithLines then begin
            SalesShipmentLine.Init();
            SalesShipmentLine."Document No." := SalesShipmentHeader."No.";
            SalesShipmentLine."Line No." := 10000;
            SalesShipmentLine.Type := SalesShipmentLine.Type::Item;
            SalesShipmentLine."No." := 'BIFT29-I';
            SalesShipmentLine.Quantity := 1;
            SalesShipmentLine.Insert();
        end;
        Commit();
    end;

    local procedure Cleanup()
    var
        Shop: Record "Shpfy Shop";
        OrderHeader: Record "Shpfy Order Header";
        SalesShipmentHeader: Record "Sales Shipment Header";
        SalesShipmentLine: Record "Sales Shipment Line";
    begin
        SalesShipmentLine.SetRange("Document No.", ShipmentNoTok);
        SalesShipmentLine.DeleteAll();
        if SalesShipmentHeader.Get(ShipmentNoTok) then
            SalesShipmentHeader.Delete();
        if OrderHeader.Get(930000029) then
            OrderHeader.Delete(true);
        if Shop.Get(ShopCodeTok) then
            Shop.Delete(true);
        Commit();
    end;

    local procedure Execute(ShipmentNo: Text): JsonObject
    begin
        exit(ExecuteRaw('{"shipmentNo":"' + ShipmentNo + '"}'));
    end;

    local procedure ExecuteRaw(RequestText: Text) ResponseJson: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseContentType: Text[100];
        MessageVersion: Enum "Message Version ori";
        ResponseText: Text;
    begin
        RequestContent.AddText(RequestText);
        Dispatcher.Execute("Message Type ori"::"Shopify.Fulfillment.Sync", MessageVersion, '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        ResponseJson.ReadFrom(ResponseText);
    end;

    local procedure ReadText(JsonObj: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not JsonObj.Get(PropertyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        exit(Token.AsValue().AsText());
    end;
}
