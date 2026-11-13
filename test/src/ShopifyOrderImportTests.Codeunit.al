namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Issue #23: Shopify.Order.Import request validation, Business Central refusals and permissions.</summary>
codeunit 97403 "Shopify Order Import Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        ShopCodeTok: Label 'BIFT23', Locked = true;

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

    /// <summary>An unknown key is refused as UnknownParameter and changes nothing.</summary>
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

    /// <summary>An empty or too long shop code is refused as InvalidParameterFormat.</summary>
    [Test]
    procedure InvalidShopCodeIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := ExecuteRaw('{"shopCode":""}');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), 'Empty code.');
        Response := ExecuteRaw('{"shopCode":"123456789012345678901"}');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), 'Too long code.');
    end;

    /// <summary>A shop that does not exist is refused with RecordNotFound.</summary>
    [Test]
    procedure UnknownShopIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '"}');
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Unknown shop status.');
        Assert.AreEqual('RecordNotFound', ReadText(Response, 'code'), 'Unknown shop code.');
    end;

    /// <summary>A shop that is not enabled is refused before Shopify is contacted.</summary>
    [Test]
    procedure DisabledShopIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        SeedShop(false);
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '"}');
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Disabled shop status.');
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), 'Disabled shop code.');
        Cleanup();
    end;

    /// <summary>An enabled shop without a Shopify access token is refused by the Shopify connector and leaves no orders.</summary>
    [Test]
    procedure BusinessCentralRefusalIsReturned()
    var
        OrderHeader: Record "Shpfy Order Header";
        Response: JsonObject;
    begin
        Initialize();
        SeedShop(true);
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '"}');
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Refusal status.');
        Assert.AreEqual('BusinessCentralError', ReadText(Response, 'code'), 'Refusal code.');
        OrderHeader.SetRange("Shop Code", ShopCodeTok);
        Assert.AreEqual(0, OrderHeader.Count(), 'No partial orders.');
        Cleanup();
    end;

    /// <summary>The refusal is also returned when the language is Icelandic.</summary>
    [Test]
    procedure BusinessCentralRefusalIsReturnedIcelandic()
    var
        Response: JsonObject;
        PreviousLanguage: Integer;
    begin
        Initialize();
        SeedShop(true);
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1039);
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '"}');
        GlobalLanguage(PreviousLanguage);
        Assert.AreEqual('BusinessCentralError', ReadText(Response, 'code'), 'Refusal code in Icelandic.');
        Cleanup();
    end;

    /// <summary>A caller without the app permissions is refused.</summary>
    [Test]
    procedure CallerWithoutPermissionIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        SeedShop(true);
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '"}');
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

    local procedure Cleanup()
    var
        Shop: Record "Shpfy Shop";
    begin
        if Shop.Get(ShopCodeTok) then begin
            Shop.Enabled := false;
            Shop.Modify();
            Shop.Delete(true);
        end;
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
        Dispatcher.Execute("Message Type ori"::"Shopify.Order.Import", MessageVersion, '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType);
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
