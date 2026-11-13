namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue #6: Shopify.Product.Sync. The connector's calls to the live Shopify API cannot be reached from a container;
/// the tests cover the product sync of a shop that has nothing to sync, a connector failure returned as a refusal,
/// the refusals and the permission check.
/// </summary>
codeunit 97460 "Shpfy Prod Sync Test ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        ShopCodeTok: Label 'BIFT6', Locked = true;

    /// <summary>An enabled shop without products runs the connector product sync and succeeds.</summary>
    [Test]
    procedure EnabledShopSucceeds()
    var
        Response: JsonObject;
    begin
        Initialize();
        SeedShop(true);
        Response := Execute(ShopCodeTok);
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Success status.');
        Assert.AreEqual(ShopCodeTok, ReadText(Response, 'shopCode'), 'Shop code echoed.');
        Assert.AreEqual('0', ReadText(Response, 'productsInShop'), 'No products stored for the shop.');
        Cleanup();
    end;

    /// <summary>A shop set to import products makes the connector call Shopify, which a container cannot reach: the failure is returned as a refusal.</summary>
    [Test]
    procedure ConnectorFailureIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        SeedShop(true);
        SetSyncFromShopify();
        Response := Execute(ShopCodeTok);
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Connector failure status.');
        Assert.AreEqual('BusinessCentralError', ReadText(Response, 'code'), 'Connector failure code.');
        Cleanup();
    end;

    /// <summary>A request without shopCode is refused with MissingParameter and changes nothing.</summary>
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

    /// <summary>A shop that does not exist is refused as RecordNotFound.</summary>
    [Test]
    procedure UnknownShopIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := Execute('BIFT6-NONE');
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Unknown shop status.');
        Assert.AreEqual('RecordNotFound', ReadText(Response, 'code'), 'Unknown shop code.');
    end;

    /// <summary>A shop that is not enabled is refused as PreconditionFailed and left unchanged.</summary>
    [Test]
    procedure DisabledShopIsRefused()
    var
        Shop: Record "Shpfy Shop";
        Response: JsonObject;
    begin
        Initialize();
        SeedShop(false);
        Response := Execute(ShopCodeTok);
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Disabled shop status.');
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), 'Disabled shop code.');
        Shop.Get(ShopCodeTok);
        Assert.IsFalse(Shop.Enabled, 'Shop stays disabled.');
        Cleanup();
    end;

    /// <summary>A caller without the app permissions is refused and nothing runs.</summary>
    [Test]
    procedure CallerWithoutPermissionIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        SeedShop(true);
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        Response := Execute(ShopCodeTok);
        LowerPermissions.StopLoggingNAVPermissions();
        Assert.AreNotEqual('Success', ReadText(Response, 'status'), 'Caller without permission must be refused.');
        Cleanup();
    end;

    local procedure Initialize()
    begin
        Cleanup();
    end;

    local procedure SeedShop(Enabled: Boolean)
    var
        Shop: Record "Shpfy Shop";
    begin
        Shop.Init();
        Shop.Code := CopyStr(ShopCodeTok, 1, MaxStrLen(Shop.Code));
        Shop.Insert();
        Shop.Enabled := Enabled;
        Shop.Modify();
        Commit();
    end;

    local procedure SetSyncFromShopify()
    var
        Shop: Record "Shpfy Shop";
    begin
        Shop.Get(ShopCodeTok);
        Shop."Sync Item" := Shop."Sync Item"::"From Shopify";
        Shop.Modify();
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

    local procedure Execute(ShopCode: Text): JsonObject
    begin
        exit(ExecuteRaw('{"shopCode":"' + ShopCode + '"}'));
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
        Dispatcher.Execute("Message Type ori"::"Shopify.Product.Sync", MessageVersion, '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType);
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
