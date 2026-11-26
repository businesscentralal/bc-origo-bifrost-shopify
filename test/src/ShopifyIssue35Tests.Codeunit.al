namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Issue 35: public dispatcher tests with a mock-only connector seam.</summary>
codeunit 97510 "Shopify Issue 35 Tests ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Fixture: Codeunit "Shpfy Metafield MCP ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    /// <summary>AC02: exact Product table mapping and GetDefinitions selection through the dispatcher.</summary>
    [Test]
    procedure AC02_Product_GetDefinitions()
    begin
        HappyPath('Product', 30127, 'GetDefinitions');
    end;

    /// <summary>AC02: exact Product table mapping and SendValues selection through the dispatcher.</summary>
    [Test]
    procedure AC02_Product_SendValues()
    begin
        HappyPath('Product', 30127, 'SendValues');
    end;

    /// <summary>AC02: exact Variant table mapping and GetDefinitions selection through the dispatcher.</summary>
    [Test]
    procedure AC02_Variant_GetDefinitions()
    begin
        HappyPath('Variant', 30129, 'GetDefinitions');
    end;

    /// <summary>AC02: exact Variant table mapping and SendValues selection through the dispatcher.</summary>
    [Test]
    procedure AC02_Variant_SendValues()
    begin
        HappyPath('Variant', 30129, 'SendValues');
    end;

    /// <summary>AC02: exact Customer table mapping and GetDefinitions selection through the dispatcher.</summary>
    [Test]
    procedure AC02_Customer_GetDefinitions()
    begin
        HappyPath('Customer', 30105, 'GetDefinitions');
    end;

    /// <summary>AC02: exact Customer table mapping and SendValues selection through the dispatcher.</summary>
    [Test]
    procedure AC02_Customer_SendValues()
    begin
        HappyPath('Customer', 30105, 'SendValues');
    end;

    /// <summary>AC02: exact Company table mapping and GetDefinitions selection through the dispatcher.</summary>
    [Test]
    procedure AC02_Company_GetDefinitions()
    begin
        HappyPath('Company', 30150, 'GetDefinitions');
    end;

    /// <summary>AC02: exact Company table mapping and SendValues selection through the dispatcher.</summary>
    [Test]
    procedure AC02_Company_SendValues()
    begin
        HappyPath('Company', 30150, 'SendValues');
    end;

    /// <summary>AC03: MissingshopCode is refused before connector writes.</summary>
    [Test]
    procedure AC03_MissingshopCode()
    begin
        Refusal('{"direction":"GetDefinitions","ownerType":"Product","ownerId":8935000035}', 'MissingParameter');
    end;

    /// <summary>AC03: ObjectshopCode is refused before connector writes.</summary>
    [Test]
    procedure AC03_ObjectshopCode()
    begin
        Refusal('{"shopCode":{},"direction":"GetDefinitions","ownerType":"Product","ownerId":8935000035}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: Missingdirection is refused before connector writes.</summary>
    [Test]
    procedure AC03_Missingdirection()
    begin
        Refusal('{"shopCode":"XMF35","ownerType":"Product","ownerId":8935000035}', 'MissingParameter');
    end;

    /// <summary>AC03: Objectdirection is refused before connector writes.</summary>
    [Test]
    procedure AC03_Objectdirection()
    begin
        Refusal('{"shopCode":"XMF35","direction":{},"ownerType":"Product","ownerId":8935000035}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: MissingownerType is refused before connector writes.</summary>
    [Test]
    procedure AC03_MissingownerType()
    begin
        Refusal('{"shopCode":"XMF35","direction":"GetDefinitions","ownerId":8935000035}', 'MissingParameter');
    end;

    /// <summary>AC03: ObjectownerType is refused before connector writes.</summary>
    [Test]
    procedure AC03_ObjectownerType()
    begin
        Refusal('{"shopCode":"XMF35","direction":"GetDefinitions","ownerType":{},"ownerId":8935000035}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: MissingownerId is refused before connector writes.</summary>
    [Test]
    procedure AC03_MissingownerId()
    begin
        Refusal('{"shopCode":"XMF35","direction":"GetDefinitions","ownerType":"Product"}', 'MissingParameter');
    end;

    /// <summary>AC03: ObjectownerId is refused before connector writes.</summary>
    [Test]
    procedure AC03_ObjectownerId()
    begin
        Refusal('{"shopCode":"XMF35","direction":"GetDefinitions","ownerType":"Product","ownerId":{}}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: BadDirection is refused before connector writes.</summary>
    [Test]
    procedure AC03_BadDirection()
    begin
        Refusal('{"shopCode":"XMF35","direction":"bad","ownerType":"Product","ownerId":8935000035}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: BadOwnerType is refused before connector writes.</summary>
    [Test]
    procedure AC03_BadOwnerType()
    begin
        Refusal('{"shopCode":"XMF35","direction":"GetDefinitions","ownerType":"Order","ownerId":8935000035}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: BlankShop is refused before connector writes.</summary>
    [Test]
    procedure AC03_BlankShop()
    begin
        Refusal('{"shopCode":"","direction":"GetDefinitions","ownerType":"Product","ownerId":8935000035}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: LongShop is refused before connector writes.</summary>
    [Test]
    procedure AC03_LongShop()
    begin
        Refusal('{"shopCode":"XXXXXXXXXXXXXXXXXXXXX","direction":"GetDefinitions","ownerType":"Product","ownerId":8935000035}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: NumericShop is refused before connector writes.</summary>
    [Test]
    procedure AC03_NumericShop()
    begin
        Refusal('{"shopCode":35,"direction":"GetDefinitions","ownerType":"Product","ownerId":8935000035}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: StringId is refused before connector writes.</summary>
    [Test]
    procedure AC03_StringId()
    begin
        Refusal('{"shopCode":"XMF35","direction":"GetDefinitions","ownerType":"Product","ownerId":"8935000035"}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: ZeroId is refused before connector writes.</summary>
    [Test]
    procedure AC03_ZeroId()
    begin
        Refusal('{"shopCode":"XMF35","direction":"GetDefinitions","ownerType":"Product","ownerId":0}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: NegativeId is refused before connector writes.</summary>
    [Test]
    procedure AC03_NegativeId()
    begin
        Refusal('{"shopCode":"XMF35","direction":"GetDefinitions","ownerType":"Product","ownerId":-1}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: FractionalId is refused before connector writes.</summary>
    [Test]
    procedure AC03_FractionalId()
    begin
        Refusal('{"shopCode":"XMF35","direction":"GetDefinitions","ownerType":"Product","ownerId":1.5}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: OverflowId is refused before connector writes.</summary>
    [Test]
    procedure AC03_OverflowId()
    begin
        Refusal('{"shopCode":"XMF35","direction":"GetDefinitions","ownerType":"Product","ownerId":9223372036854775808}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: NullId is refused before connector writes.</summary>
    [Test]
    procedure AC03_NullId()
    begin
        Refusal('{"shopCode":"XMF35","direction":"GetDefinitions","ownerType":"Product","ownerId":null}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: UnknownOwner is refused before connector writes.</summary>
    [Test]
    procedure AC03_UnknownOwner()
    begin
        Refusal('{"shopCode":"XMF35","direction":"GetDefinitions","ownerType":"Product","ownerId":8935000036}', 'RecordNotFound');
    end;

    /// <summary>AC03: UnknownShop is refused before connector writes.</summary>
    [Test]
    procedure AC03_UnknownShop()
    begin
        Refusal('{"shopCode":"XMF35-NOTFOUND","direction":"GetDefinitions","ownerType":"Product","ownerId":8935000035}', 'RecordNotFound');
    end;

    /// <summary>AC03: UnknownKey is refused before connector writes.</summary>
    [Test]
    procedure AC03_UnknownKey()
    begin
        Refusal('{"shopCode":"XMF35","direction":"GetDefinitions","ownerType":"Product","ownerId":8935000035,"extra":true}', 'UnknownParameter');
    end;

    /// <summary>AC03: MissingCount is refused before connector writes.</summary>
    [Test]
    procedure AC03_MissingCount()
    begin
        Refusal('{"shopCode":"XMF35","direction":"SendValues","ownerType":"Product","ownerId":8935000035}', 'MissingParameter');
    end;

    /// <summary>AC03: NegativeCount is refused before connector writes.</summary>
    [Test]
    procedure AC03_NegativeCount()
    begin
        Refusal('{"shopCode":"XMF35","direction":"SendValues","ownerType":"Product","ownerId":8935000035,"expectedCount":-1}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: StringCount is refused before connector writes.</summary>
    [Test]
    procedure AC03_StringCount()
    begin
        Refusal('{"shopCode":"XMF35","direction":"SendValues","ownerType":"Product","ownerId":8935000035,"expectedCount":"0"}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: ObjectCount is refused before connector writes.</summary>
    [Test]
    procedure AC03_ObjectCount()
    begin
        Refusal('{"shopCode":"XMF35","direction":"SendValues","ownerType":"Product","ownerId":8935000035,"expectedCount":{}}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: FractionCount is refused before connector writes.</summary>
    [Test]
    procedure AC03_FractionCount()
    begin
        Refusal('{"shopCode":"XMF35","direction":"SendValues","ownerType":"Product","ownerId":8935000035,"expectedCount":0.5}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: CountMismatch is refused before connector writes.</summary>
    [Test]
    procedure AC03_CountMismatch()
    begin
        Refusal('{"shopCode":"XMF35","direction":"SendValues","ownerType":"Product","ownerId":8935000035,"expectedCount":1}', 'PreconditionFailed');
    end;

    /// <summary>AC03: disabled shop is refused.</summary>
    [Test]
    procedure AC03_DisabledShop()
    var
        Shop: Record "Shpfy Shop";
        Response: JsonObject;
    begin
        Fixture.Seed();
        Shop.Get('XMF35');
        Shop.Enabled := false;
        Shop.Modify(false);
        Commit();
        Response := Dispatch(Request('Product', 'GetDefinitions', 0), 1033);
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), 'Disabled shop.');
        AssertNoWrites();
        Fixture.Cleanup();
    end;

    /// <summary>AC03: an owner belonging to another shop is refused.</summary>
    [Test]
    procedure AC03_OtherShopOwner()
    var
        Customer: Record "Shpfy Customer";
        Response: JsonObject;
    begin
        Fixture.Seed();
        Customer.Get(8935000035L);
        Customer."Shop Id" := 893536;
        Customer.Modify(false);
        Commit();
        Response := Dispatch(Request('Customer', 'GetDefinitions', 0), 1033);
        Assert.AreEqual('RecordNotFound', ReadText(Response, 'code'), 'Owner shop isolation.');
        AssertNoWrites();
        Fixture.Cleanup();
    end;

    /// <summary>AC01: a Foundation read-only caller is refused before writes.</summary>
    [Test]
    procedure AC01_ReadCallerIsRefused()
    var
        Response: JsonObject;
    begin
        Fixture.Seed();
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        Response := Dispatch(Request('Product', 'GetDefinitions', 0), 1033);
        LowerPermissions.StopLoggingNAVPermissions();
        Assert.AreEqual('PermissionDenied', ReadText(Response, 'code'), 'Read caller refused.');
        AssertNoWrites();
        Fixture.Cleanup();
    end;

    /// <summary>AC04: connector writes before refusal roll back and preserve the original error.</summary>
    [Test]
    procedure AC04_ConnectorRefusalRollsBack()
    var
        Product: Record "Shpfy Product";
        Response: JsonObject;
    begin
        Fixture.Seed();
        Product.Get(8935000035L);
        Product.Title := 'XREFUSE';
        Product.Modify(false);
        Commit();
        Response := Dispatch(Request('Product', 'SendValues', 0), 1033);
        Assert.AreEqual('BusinessCentralError', ReadText(Response, 'code'), 'Connector error type.');
        Assert.IsTrue(StrPos(ReadText(Response, 'error'), 'Money currency') > 0, 'Original refusal text.');
        AssertNoWrites();
        Fixture.Cleanup();
    end;

    /// <summary>AC05: explicit dispatcher LCIDs select distinct translated refusals.</summary>
    [Test]
    procedure AC05_RefusalIsTranslated()
    var
        English: JsonObject;
        Icelandic: JsonObject;
    begin
        Fixture.Seed();
        English := Dispatch('{}', 1033);
        Icelandic := Dispatch('{}', 1039);
        Assert.AreEqual('MissingParameter', ReadText(English, 'code'), 'English code.');
        Assert.AreEqual('MissingParameter', ReadText(Icelandic, 'code'), 'Icelandic code.');
        Assert.AreNotEqual(ReadText(English, 'error'), ReadText(Icelandic, 'error'), 'Translated refusal.');
        Assert.IsTrue(StrPos(ReadText(Icelandic, 'error'), 'Færibreytan') > 0, 'Icelandic text.');
        Fixture.Cleanup();
    end;

    /// <summary>AC04: existing metafield values are preserved when the connector writes then fails.</summary>
    [Test]
    procedure AC04_ExistingValueRollsBack()
    var
        Product: Record "Shpfy Product";
        Metafield: Record "Shpfy Metafield";
        Response: JsonObject;
    begin
        Fixture.Seed();
        Response := Dispatch(Request('Product', 'GetDefinitions', 0), 1033);
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Prepare existing value.');
        Product.Get(8935000035L);
        Product.Title := 'XREFUSE';
        Product.Modify(false);
        Commit();
        Response := Dispatch(Request('Product', 'SendValues', 1), 1033);
        Assert.AreEqual('BusinessCentralError', ReadText(Response, 'code'), 'Connector error type.');
        Metafield.SetRange("Owner Id", 8935000035L);
        Assert.AreEqual(1, Metafield.Count(), 'Existing row retained.');
        Metafield.FindFirst();
        Assert.AreEqual('', Metafield.Value, 'Failed write was rolled back.');
        Fixture.Cleanup();
    end;

    local procedure HappyPath(OwnerType: Text; ParentTableNo: Integer; Direction: Text)
    var
        Metafield: Record "Shpfy Metafield";
        Response: JsonObject;
    begin
        Fixture.Seed();
        if Direction = 'SendValues' then begin
            Response := Dispatch(Request(OwnerType, 'GetDefinitions', 0), 1033);
            Assert.AreEqual('Success', ReadText(Response, 'status'), 'Seed owner definitions.');
        end;
        if Direction = 'SendValues' then
            Response := Dispatch(Request(OwnerType, Direction, 1), 1033)
        else
            Response := Dispatch(Request(OwnerType, Direction, 0), 1033);
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Happy path: ' + ReadText(Response, 'error'));
        if Direction = 'SendValues' then
            Assert.AreEqual('1', ReadText(Response, 'metafieldsBefore'), 'Local value count.')
        else
            Assert.AreEqual('0', ReadText(Response, 'metafieldsBefore'), 'Empty boundary.');
        Assert.AreEqual('1', ReadText(Response, 'metafieldsAfter'), 'Stand-in row count.');
        Assert.AreEqual(OwnerType, ReadText(Response, 'ownerType'), 'Owner type.');
        Assert.AreEqual(Direction, ReadText(Response, 'direction'), 'Direction.');
        Metafield.SetRange("Parent Table No.", ParentTableNo);
        Metafield.SetRange("Owner Id", 8935000035L);
        Assert.AreEqual(1, Metafield.Count(), 'Exact owner table mapping.');
        Metafield.FindFirst();
        if Direction = 'SendValues' then
            Assert.AreEqual('XMOCK-SENT', Metafield.Value, 'Send procedure was selected.')
        else
            Assert.AreEqual('', Metafield.Value, 'Get procedure was selected.');
        Response := Dispatch(Request(OwnerType, Direction, 1), 1039);
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Repeat in Icelandic.');
        Assert.AreEqual('1', ReadText(Response, 'metafieldsBefore'), 'Repeat before.');
        Assert.AreEqual('1', ReadText(Response, 'metafieldsAfter'), 'Idempotent repeat.');
        Assert.AreEqual(1, Metafield.Count(), 'No duplicate.');
        Fixture.Cleanup();
    end;

    local procedure Refusal(RequestText: Text; ExpectedCode: Text)
    var
        Response: JsonObject;
    begin
        Fixture.Seed();
        Response := Dispatch(RequestText, 1033);
        Assert.AreEqual(ExpectedCode, ReadText(Response, 'code'), 'Typed refusal: ' + ReadText(Response, 'error'));
        AssertNoWrites();
        Fixture.Cleanup();
    end;

    local procedure AssertNoWrites()
    var
        Metafield: Record "Shpfy Metafield";
    begin
        Metafield.SetRange("Owner Id", 8935000035L);
        Assert.IsTrue(Metafield.IsEmpty(), 'No connector write.');
    end;

    local procedure Request(OwnerType: Text; Direction: Text; Count: Integer): Text
    begin
        exit('{"shopCode":"XMF35","direction":"' + Direction + '","ownerType":"' + OwnerType + '","ownerId":8935000035,"expectedCount":' + Format(Count, 0, 9) + '}');
    end;

    local procedure Dispatch(RequestText: Text; LanguageId: Integer) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ContentType: Text[100];
        Version: Enum "Message Version ori";
        EmptyTaskId: Guid;
        MessageId: Guid;
        ResponseTime: Duration;
        ResponseText: Text;
    begin
        RequestContent.AddText(RequestText);
        Dispatcher.EnqueueAndProcess("Message Type ori"::"Shopify.Metafield.Sync", Version, '', '', 'application/json', RequestContent, EmptyTaskId, LanguageId, MessageId, ResponseContent, ContentType, ResponseTime);
        ResponseContent.GetSubText(ResponseText, 1);
        Response.ReadFrom(ResponseText);
    end;

    local procedure ReadText(Response: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        if Response.Get(Name, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsText());
        exit('');
    end;
}
