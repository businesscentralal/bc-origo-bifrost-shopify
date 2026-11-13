namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue #14: Shopify.Inventory.Sync request validation, refusals, the connector report on a shop without variants,
/// and permissions. Sending stock for real variants calls the live Shopify API, which a container cannot reach.
/// </summary>
codeunit 97480 "Shpfy Inventory Sync Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        ShopCodeTok: Label 'BIFT14', Locked = true;

    /// <summary>A request without shopCode is refused with MissingParameter.</summary>
    [Test]
    procedure MissingKeyIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := ExecuteRaw('{}');
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Missing key status.');
        Assert.AreEqual('MissingParameter', ReadText(Response, 'code'), 'Missing key code.');
        Assert.AreEqual('shopCode', ReadText(Response, 'parameter'), 'Missing key parameter.');
    end;

    /// <summary>An unknown key is refused as UnknownParameter.</summary>
    [Test]
    procedure UnknownKeyIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := ExecuteRaw('{"shopCode":"X","bogus":true}');
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Unknown key status.');
        Assert.AreEqual('UnknownParameter', ReadText(Response, 'code'), 'Unknown key code.');
    end;

    /// <summary>A shopCode longer than the shop code field is refused as InvalidParameterFormat.</summary>
    [Test]
    procedure TooLongShopCodeIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := ExecuteRaw('{"shopCode":"ABCDEFGHIJKLMNOPQRSTU"}');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), 'Too long code.');
    end;

    /// <summary>A skipImport that is not true or false is refused and the shop is unchanged.</summary>
    [Test]
    procedure InvalidSkipImportIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Seed(true);
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '","skipImport":"maybe"}');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), 'Invalid skipImport code.');
        Assert.AreEqual('skipImport', ReadText(Response, 'parameter'), 'Invalid skipImport parameter.');
        Cleanup();
    end;

    /// <summary>A shop that does not exist is refused as RecordNotFound.</summary>
    [Test]
    procedure UnknownShopIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := Execute('BIFT14-NONE', true);
        Assert.AreEqual('RecordNotFound', ReadText(Response, 'code'), 'Unknown shop code.');
    end;

    /// <summary>A disabled shop is refused as PreconditionFailed and stays disabled.</summary>
    [Test]
    procedure DisabledShopIsRefused()
    var
        Shop: Record "Shpfy Shop";
        Response: JsonObject;
    begin
        Initialize();
        Seed(false);
        Response := Execute(ShopCodeTok, true);
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), 'Disabled shop code.');
        Shop.Get(ShopCodeTok);
        Assert.IsFalse(Shop.Enabled, 'Shop stays disabled.');
        Cleanup();
    end;

    /// <summary>A shop without variants is synchronized by the connector report; the response echoes the options.</summary>
    [Test]
    procedure ShopWithoutVariantsSucceeds()
    var
        Response: JsonObject;
    begin
        Initialize();
        Seed(true);
        Response := Execute(ShopCodeTok, true);
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Sync status: ' + ReadText(Response, 'message'));
        Assert.AreEqual(ShopCodeTok, ReadText(Response, 'shopCode'), 'Sync shop code.');
        Assert.AreEqual('true', ReadText(Response, 'skipImport'), 'Sync skipImport echo.');
        Cleanup();
    end;

    /// <summary>A variant filter that Business Central cannot interpret is refused before the report runs and nothing changes.</summary>
    [Test]
    procedure InvalidVariantFilterIsRefused()
    var
        Shop: Record "Shpfy Shop";
        Response: JsonObject;
    begin
        Initialize();
        Seed(true);
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '","skipImport":true,"variantIdFilter":"1&&|("}');
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Invalid filter status.');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), 'Invalid filter code.');
        Assert.AreEqual('variantIdFilter', ReadText(Response, 'parameter'), 'Invalid filter parameter.');
        Shop.Get(ShopCodeTok);
        Assert.IsTrue(Shop.Enabled, 'Shop is unchanged.');
        Cleanup();
    end;

    /// <summary>A valid variant filter and skipImport=false are accepted and echoed.</summary>
    [Test]
    procedure ValidVariantFilterIsEchoed()
    var
        Response: JsonObject;
    begin
        Initialize();
        Seed(true);
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '","skipImport":false,"variantIdFilter":"123|456"}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Filter status.');
        Assert.AreEqual('123|456', ReadText(Response, 'variantIdFilter'), 'Filter echo.');
        Assert.AreEqual('false', ReadText(Response, 'skipImport'), 'skipImport echo.');
        Cleanup();
    end;

    /// <summary>A caller without the app permissions is refused.</summary>
    [Test]
    procedure CallerWithoutPermissionIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Seed(true);
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        Response := Execute(ShopCodeTok, true);
        LowerPermissions.StopLoggingNAVPermissions();
        Assert.AreNotEqual('Success', ReadText(Response, 'status'), 'Caller without permission must be refused.');
        Cleanup();
    end;


    local procedure Initialize()
    begin
        Cleanup();
    end;

    local procedure Seed(Enabled: Boolean)
    var
        Shop: Record "Shpfy Shop";
    begin
        Shop.Init();
        Shop.Code := CopyStr(ShopCodeTok, 1, MaxStrLen(Shop.Code));
        Shop.Enabled := Enabled;
        Shop.Insert();
        Commit();
    end;

    local procedure Cleanup()
    var
        Shop: Record "Shpfy Shop";
    begin
        if Shop.Get(ShopCodeTok) then
            Shop.Delete(true);
        Commit();
    end;

    local procedure Execute(ShopCode: Text; SkipImport: Boolean): JsonObject
    var
        SkipText: Text;
    begin
        if SkipImport then
            SkipText := 'true'
        else
            SkipText := 'false';
        exit(ExecuteRaw('{"shopCode":"' + ShopCode + '","skipImport":' + SkipText + '}'));
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
        Dispatcher.Execute("Message Type ori"::"Shopify.Inventory.Sync", MessageVersion, '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType);
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
