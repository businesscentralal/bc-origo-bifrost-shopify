namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue #12: Shopify.Product.SyncImages. The live Shopify API is not called: the connector run is replaced by the stand-in
/// 97541 through OnBeforeRunConnector; the request refusals and the permission check run against the real type.
/// </summary>
codeunit 97540 "Shpfy Prod SyncImg Test ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        ShopCodeTok: Label 'BIFT12', Locked = true;

    /// <summary>A shop set To Shopify runs the export path and reports ToShopify.</summary>
    [Test]
    procedure ExportDirectionRuns()
    var
        Shop: Record "Shpfy Shop";
        Stub: Codeunit "Shpfy SyncImg Stub ori";
        Response: JsonObject;
    begin
        Initialize();
        SeedShop(true, Shop."Sync Item Images"::"To Shopify");
        BindSubscription(Stub);
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '"}');
        UnbindSubscription(Stub);
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Success status: ' + ReadText(Response, 'error'));
        Assert.AreEqual('ToShopify', ReadText(Response, 'syncDirection'), 'Direction.');
        Assert.AreEqual(ShopCodeTok, ReadText(Response, 'shopCode'), 'Shop code echoed.');
        Assert.AreEqual('', ReadText(Response, 'productIdFilter'), 'No filter.');
        Assert.AreEqual(1, Stub.GetCalls(), 'Connector reached once.');
        Assert.AreEqual(ShopCodeTok, Format(Stub.GetLastShopCode()), 'Connector shop.');
        Cleanup();
    end;

    /// <summary>A shop set From Shopify runs the import path; the filter reaches the connector and limits productsConsidered.</summary>
    [Test]
    procedure ImportDirectionRunsWithFilter()
    var
        Shop: Record "Shpfy Shop";
        Stub: Codeunit "Shpfy SyncImg Stub ori";
        Response: JsonObject;
    begin
        Initialize();
        SeedShop(true, Shop."Sync Item Images"::"From Shopify");
        SeedProduct(974912001);
        SeedProduct(974912002);
        SeedProduct(974912003);
        BindSubscription(Stub);
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '","productIdFilter":"974912001|974912003"}');
        UnbindSubscription(Stub);
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Success status: ' + ReadText(Response, 'error'));
        Assert.AreEqual('FromShopify', ReadText(Response, 'syncDirection'), 'Direction.');
        Assert.AreEqual('974912001|974912003', ReadText(Response, 'productIdFilter'), 'Filter echoed.');
        Assert.AreEqual('2', ReadText(Response, 'productsConsidered'), 'Two products within the filter.');
        Assert.AreEqual('974912001|974912003', Stub.GetLastFilter(), 'Filter reached the connector.');
        Cleanup();
    end;

    /// <summary>Sync Item Images Disabled is refused with PreconditionFailed and the connector is not reached.</summary>
    [Test]
    procedure DisabledSettingIsRefused()
    var
        Shop: Record "Shpfy Shop";
        Stub: Codeunit "Shpfy SyncImg Stub ori";
        Response: JsonObject;
    begin
        Initialize();
        SeedShop(true, Shop."Sync Item Images"::" ");
        BindSubscription(Stub);
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '"}');
        UnbindSubscription(Stub);
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Refusal status.');
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), 'Refusal code.');
        Assert.AreEqual(0, Stub.GetCalls(), 'Connector not reached.');
        Cleanup();
    end;

    /// <summary>A malformed productIdFilter is refused with InvalidParameterFormat before the connector runs.</summary>
    [Test]
    procedure InvalidFilterIsRefused()
    var
        Shop: Record "Shpfy Shop";
        Stub: Codeunit "Shpfy SyncImg Stub ori";
        Response: JsonObject;
    begin
        Initialize();
        SeedShop(true, Shop."Sync Item Images"::"To Shopify");
        BindSubscription(Stub);
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '","productIdFilter":"abc|(("}');
        UnbindSubscription(Stub);
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), 'Invalid filter code.');
        Assert.AreEqual('productIdFilter', ReadText(Response, 'parameter'), 'Invalid filter parameter.');
        Assert.AreEqual(0, Stub.GetCalls(), 'Connector not reached.');
        Cleanup();
    end;

    /// <summary>A request without shopCode is refused with MissingParameter.</summary>
    [Test]
    procedure MissingShopCodeIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := ExecuteRaw('{"productIdFilter":"1"}');
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Missing key status.');
        Assert.AreEqual('MissingParameter', ReadText(Response, 'code'), 'Missing key code.');
        Assert.AreEqual('shopCode', ReadText(Response, 'parameter'), 'Missing key parameter.');
    end;

    /// <summary>A shop code that is empty or longer than 20 characters is refused with InvalidParameterFormat.</summary>
    [Test]
    procedure MalformedShopCodeIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := ExecuteRaw('{"shopCode":""}');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), 'Empty shop code.');
        Response := ExecuteRaw('{"shopCode":"123456789012345678901"}');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), 'Too long shop code.');
    end;

    /// <summary>An unknown key is refused as UnknownParameter.</summary>
    [Test]
    procedure UnknownKeyIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := ExecuteRaw('{"shopCode":"X","direction":"ToShopify"}');
        Assert.AreEqual('UnknownParameter', ReadText(Response, 'code'), 'Unknown key code (direction is not a request key).');
    end;

    /// <summary>An unknown shop is refused as RecordNotFound; a disabled shop as PreconditionFailed.</summary>
    [Test]
    procedure UnknownOrDisabledShopIsRefused()
    var
        Shop: Record "Shpfy Shop";
        Response: JsonObject;
    begin
        Initialize();
        Response := ExecuteRaw('{"shopCode":"BIFT12-NONE"}');
        Assert.AreEqual('RecordNotFound', ReadText(Response, 'code'), 'Unknown shop code.');
        SeedShop(false, Shop."Sync Item Images"::"To Shopify");
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '"}');
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), 'Disabled shop code.');
        Cleanup();
    end;

    /// <summary>A failing connector run is returned as BusinessCentralError with its text.</summary>
    [Test]
    procedure ConnectorFailureIsReturned()
    var
        Shop: Record "Shpfy Shop";
        Stub: Codeunit "Shpfy SyncImg Stub ori";
        Response: JsonObject;
    begin
        Initialize();
        SeedShop(true, Shop."Sync Item Images"::"To Shopify");
        Stub.SetFailRun(true);
        BindSubscription(Stub);
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '"}');
        UnbindSubscription(Stub);
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Refusal status.');
        Assert.AreEqual('BusinessCentralError', ReadText(Response, 'code'), 'Refusal code.');
        Assert.IsTrue(StrPos(ReadText(Response, 'error'), 'Stub connector failure') > 0, 'Connector text returned: ' + ReadText(Response, 'error'));
        Cleanup();
    end;

    /// <summary>A caller without the app permissions is refused and the connector is not reached.</summary>
    [Test]
    procedure CallerWithoutPermissionIsRefused()
    var
        Shop: Record "Shpfy Shop";
        Stub: Codeunit "Shpfy SyncImg Stub ori";
        Response: JsonObject;
    begin
        Initialize();
        SeedShop(true, Shop."Sync Item Images"::"To Shopify");
        BindSubscription(Stub);
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '"}');
        LowerPermissions.StopLoggingNAVPermissions();
        UnbindSubscription(Stub);
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Caller without permission must be refused.');
        Assert.AreEqual(0, Stub.GetCalls(), 'Connector not reached.');
        Cleanup();
    end;

    local procedure Initialize()
    begin
        Cleanup();
    end;

    local procedure SeedShop(Enabled: Boolean; Direction: Option)
    var
        Shop: Record "Shpfy Shop";
    begin
        if not Shop.Get(ShopCodeTok) then begin
            Shop.Init();
            Shop.Code := ShopCodeTok;
            Shop.Insert();
        end;
        Shop.Enabled := Enabled;
        Shop."Sync Item Images" := Direction;
        Shop.Modify();
        Commit();
    end;

    local procedure SeedProduct(ProductId: BigInteger)
    var
        Product: Record "Shpfy Product";
    begin
        Product.Init();
        Product.Id := ProductId;
        Product."Shop Code" := ShopCodeTok;
        Product.Insert();
        Commit();
    end;

    local procedure Cleanup()
    var
        Shop: Record "Shpfy Shop";
        Product: Record "Shpfy Product";
    begin
        Product.SetRange("Shop Code", ShopCodeTok);
        Product.DeleteAll();
        if Shop.Get(ShopCodeTok) then
            Shop.Delete(true);
        Commit();
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
        Dispatcher.Execute("Message Type ori"::"Shopify.Product.SyncImages", MessageVersion, '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType);
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
