namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Finance.VAT.Setup;
using Microsoft.Inventory.Item;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue #9: Shopify.Product.SyncPrices. The call that sends changed variant prices to the live Shopify GraphQL API
/// cannot be reached from a container; the tests cover the connector price sync without changed variants, the
/// refusals and the permission check.
/// </summary>
codeunit 97440 "Shpfy Prod SyncPrices Test ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        ShopCodeTok: Label 'BIFT9', Locked = true;

    /// <summary>An enabled shop without mapped products runs the connector price sync and succeeds with nothing to send.</summary>
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
        Assert.AreEqual('0', ReadText(Response, 'productsConsidered'), 'No mapped products.');
        Cleanup();
    end;

    /// <summary>A mapped variant with a changed price makes the connector call Shopify, which a container cannot reach: the failure is returned as a refusal.</summary>
    [Test]
    procedure ConnectorFailureIsRefused()
    var
        ShopifyVariant: Record "Shpfy Variant";
        Response: JsonObject;
    begin
        Initialize();
        SeedShop(true);
        SeedMappedVariant();
        Response := Execute(ShopCodeTok);
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Connector failure status.');
        Assert.AreEqual('BusinessCentralError', ReadText(Response, 'code'), 'Connector failure code.');
        ShopifyVariant.Get(940000010);
        Assert.AreEqual(1, ShopifyVariant.Price, 'A refused sync must leave the stored variant price unchanged.');
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
        Response := Execute('BIFT9-NONE');
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
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Caller without permission status.');
        Assert.AreEqual('PermissionDenied', ReadText(Response, 'code'), 'Caller without permission code.');
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

    local procedure SeedMappedVariant()
    var
        GenProdPostingGroup: Record "Gen. Product Posting Group";
        VATProdPostingGroup: Record "VAT Product Posting Group";
        Item: Record Item;
        ShopifyProduct: Record "Shpfy Product";
        ShopifyVariant: Record "Shpfy Variant";
    begin
        Item.Init();
        Item."No." := 'BIFT9-I';
        Item.Insert();
        Item."Unit Price" := 25;
        if GenProdPostingGroup.FindFirst() then
            Item."Gen. Prod. Posting Group" := GenProdPostingGroup.Code;
        if VATProdPostingGroup.FindFirst() then
            Item."VAT Prod. Posting Group" := VATProdPostingGroup.Code;
        Item.Modify();
        ShopifyProduct.Init();
        ShopifyProduct.Id := 940000009;
        ShopifyProduct."Shop Code" := CopyStr(ShopCodeTok, 1, MaxStrLen(ShopifyProduct."Shop Code"));
        ShopifyProduct."Item SystemId" := Item.SystemId;
        ShopifyProduct.Insert();
        ShopifyVariant.Init();
        ShopifyVariant.Id := 940000010;
        ShopifyVariant."Product Id" := ShopifyProduct.Id;
        ShopifyVariant."Shop Code" := ShopifyProduct."Shop Code";
        ShopifyVariant."Item SystemId" := Item.SystemId;
        ShopifyVariant.Price := 1;
        ShopifyVariant.Insert();
        Commit();
    end;

    local procedure Cleanup()
    var
        Shop: Record "Shpfy Shop";
        Item: Record Item;
        ShopifyProduct: Record "Shpfy Product";
        ShopifyVariant: Record "Shpfy Variant";
    begin
        if ShopifyVariant.Get(940000010) then
            ShopifyVariant.Delete();
        if ShopifyProduct.Get(940000009) then
            ShopifyProduct.Delete();
        if Item.Get('BIFT9-I') then
            Item.Delete();
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
        Dispatcher.Execute("Message Type ori"::"Shopify.Product.SyncPrices", MessageVersion, '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType);
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
