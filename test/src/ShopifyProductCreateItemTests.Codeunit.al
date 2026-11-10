namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Inventory.Item;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Issue #8: Shopify.Product.CreateItem request validation, creation, Business Central refusals and permissions.</summary>
codeunit 97420 "Shpfy Prod CreateItem Test ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        ShopCodeTok: Label 'BIFT8', Locked = true;
        TemplateCodeTok: Label 'BIFT8', Locked = true;
        ItemNoTok: Label 'BIFT8-ITEM', Locked = true;

    /// <summary>A request without productId is refused with MissingParameter and changes nothing.</summary>
    [Test]
    procedure MissingKeyIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := ExecuteRaw('{}');
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Missing key status.');
        Assert.AreEqual('MissingParameter', ReadText(Response, 'code'), 'Missing key code.');
        Assert.AreEqual('productId', ReadText(Response, 'parameter'), 'Missing key parameter.');
    end;

    /// <summary>An unknown key is refused as UnknownParameter and changes nothing.</summary>
    [Test]
    procedure UnknownKeyIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := ExecuteRaw('{"productId":1,"bogus":true}');
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Unknown key status.');
        Assert.AreEqual('UnknownParameter', ReadText(Response, 'code'), 'Unknown key code.');
    end;

    /// <summary>A productId that is not a positive whole number is refused as InvalidParameterFormat.</summary>
    [Test]
    procedure InvalidProductIdIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := ExecuteRaw('{"productId":"abc"}');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), 'Text id.');
        Response := ExecuteRaw('{"productId":0}');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), 'Zero id.');
    end;

    /// <summary>A product that does not exist is refused with RecordNotFound.</summary>
    [Test]
    procedure UnknownProductIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := ExecuteRaw('{"productId":987654321}');
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Unknown product status.');
        Assert.AreEqual('RecordNotFound', ReadText(Response, 'code'), 'Unknown product code.');
    end;

    /// <summary>A product of a shop that is not enabled is refused before anything is created.</summary>
    [Test]
    procedure DisabledShopIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Seed(false, true);
        Response := ExecuteRaw('{"productId":' + Format(ProductId()) + '}');
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), 'Disabled shop code.');
        Assert.IsFalse(ItemExists(), 'No item for a disabled shop.');
        Cleanup();
    end;

    /// <summary>The happy path creates the item through the Shopify connector and maps the variant and product.</summary>
    [Test]
    procedure ItemIsCreatedAndMapped()
    var
        Product: Record "Shpfy Product";
        Variant: Record "Shpfy Variant";
        Item: Record Item;
        Response: JsonObject;
    begin
        Initialize();
        Seed(true, true);
        Response := ExecuteRaw('{"productId":' + Format(ProductId()) + '}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Create status: ' + ReadText(Response, 'message'));
        Assert.AreEqual(ItemNoTok, ReadText(Response, 'itemNo'), 'Item number.');
        Assert.AreEqual('1', ReadText(Response, 'variantsMapped'), 'Variants mapped.');
        Assert.IsTrue(Item.Get(ItemNoTok), 'Item exists.');
        Assert.AreEqual('Bifrost test product', Item.Description, 'Item description from the product.');
        Product.Get(ProductId());
        Assert.AreEqual(Item.SystemId, Product."Item SystemId", 'Product mapped.');
        Variant.Get(VariantId());
        Assert.AreEqual(Item.SystemId, Variant."Item SystemId", 'Variant mapped.');
        // Idempotent: a second call maps nothing new and creates no second item.
        Response := ExecuteRaw('{"productId":' + Format(ProductId()) + '}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Second call status.');
        Assert.AreEqual('0', ReadText(Response, 'variantsMapped'), 'Second call maps nothing.');
        Cleanup();
    end;

    /// <summary>A shop without an item template is refused by the Shopify connector and leaves no item or mapping.</summary>
    [Test]
    procedure BusinessCentralRefusalIsReturned()
    var
        Product: Record "Shpfy Product";
        Response: JsonObject;
    begin
        Initialize();
        Seed(true, false);
        Response := ExecuteRaw('{"productId":' + Format(ProductId()) + '}');
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Refusal status.');
        Assert.AreEqual('BusinessCentralError', ReadText(Response, 'code'), 'Refusal code.');
        Assert.IsFalse(ItemExists(), 'No partial item.');
        Product.Get(ProductId());
        Assert.IsTrue(IsNullGuid(Product."Item SystemId"), 'No partial mapping.');
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
        Seed(true, false);
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1039);
        Response := ExecuteRaw('{"productId":' + Format(ProductId()) + '}');
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
        Seed(true, true);
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        Response := ExecuteRaw('{"productId":' + Format(ProductId()) + '}');
        LowerPermissions.StopLoggingNAVPermissions();
        Assert.AreNotEqual('Success', ReadText(Response, 'status'), 'Caller without permission must be refused.');
        Assert.IsFalse(ItemExists(), 'No item for a refused caller.');
        Cleanup();
    end;

    local procedure Initialize()
    begin
        Cleanup();
    end;

    local procedure ProductId(): BigInteger
    begin
        exit(8800000001L);
    end;

    local procedure VariantId(): BigInteger
    begin
        exit(8800000002L);
    end;

    local procedure ItemExists(): Boolean
    var
        Item: Record Item;
    begin
        exit(Item.Get(ItemNoTok));
    end;

    local procedure Seed(Enabled: Boolean; WithTemplate: Boolean)
    var
        Shop: Record "Shpfy Shop";
        Product: Record "Shpfy Product";
        Variant: Record "Shpfy Variant";
    begin
        if WithTemplate then
            SeedTemplate();
        Shop.Init();
        Shop.Code := CopyStr(ShopCodeTok, 1, MaxStrLen(Shop.Code));
        Shop.Insert();
        Shop.Enabled := Enabled;
        Shop."SKU Mapping" := Shop."SKU Mapping"::"Item No.";
        if WithTemplate then
            Shop."Item Templ. Code" := CopyStr(TemplateCodeTok, 1, MaxStrLen(Shop."Item Templ. Code"));
        Shop.Modify();
        Product.Init();
        Product.Id := ProductId();
        Product."Shop Code" := Shop.Code;
        Product.Title := 'Bifrost test product';
        Product.Insert();
        Variant.Init();
        Variant.Id := VariantId();
        Variant."Product Id" := ProductId();
        Variant.SKU := ItemNoTok;
        Variant.Price := 12.5;
        Variant.Insert();
        Commit();
    end;

    local procedure SeedTemplate()
    var
        Source: Record "Item Templ.";
        Template: Record "Item Templ.";
    begin
        Source.SetRange(Type, Source.Type::Inventory);
        Source.FindFirst();
        Template := Source;
        Template.Code := CopyStr(TemplateCodeTok, 1, MaxStrLen(Template.Code));
        Template."No. Series" := '';
        Template.Insert();
    end;

    local procedure Cleanup()
    var
        Shop: Record "Shpfy Shop";
        Product: Record "Shpfy Product";
        Variant: Record "Shpfy Variant";
        Item: Record Item;
        Template: Record "Item Templ.";
    begin
        if Variant.Get(VariantId()) then
            Variant.Delete();
        if Product.Get(ProductId()) then
            Product.Delete();
        if Item.Get(ItemNoTok) then
            Item.Delete(true);
        if Shop.Get(ShopCodeTok) then begin
            Shop.Enabled := false;
            Shop.Modify();
            Shop.Delete(true);
        end;
        if Template.Get(TemplateCodeTok) then
            Template.Delete();
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
        Dispatcher.Execute("Message Type ori"::"Shopify.Product.CreateItem", MessageVersion, '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType);
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
