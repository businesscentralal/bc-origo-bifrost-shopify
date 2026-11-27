namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Origo.Bifrost;
using Origo.Bifrost.Shopify;
using System.TestLibraries.Utilities;

/// <summary>Issue 22: dispatcher contract, filters, permissions, skip logs and connector rollback with mocks only.</summary>
codeunit 97520 "Shopify Issue 22 Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>AC02/04/06: AllCatalogs, including excluded shops, disabled catalogs and old skip logs.</summary>
    [Test]
    procedure Scenario_AC02_AllCatalogs()
    var
        Stub: Codeunit "Shpfy Catalog Prices Stub ori";
        Response: JsonObject;
    begin
        Stub.Seed('XSC22-TEST');
        BindSubscription(Stub);
        Response := Execute('{"shopCode":"XSC22-TEST"}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Success.');
        Assert.AreEqual('3', ReadText(Response, 'catalogsConsidered'), 'Filtered count.');
        Assert.AreEqual('1', ReadText(Response, 'skippedRecords'), 'Only new selected skip records.');
        Assert.AreEqual(3, Stub.GetSeenCount(), 'Connector receives the same selection.');
        UnbindSubscription(Stub);
        Stub.Cleanup();
    end;

    /// <summary>AC02/04/06: OneCatalog, including excluded shops, disabled catalogs and old skip logs.</summary>
    [Test]
    procedure Scenario_AC02_OneCatalog()
    var
        Stub: Codeunit "Shpfy Catalog Prices Stub ori";
        Response: JsonObject;
    begin
        Stub.Seed('XSC22-TEST');
        BindSubscription(Stub);
        Response := Execute('{"shopCode":"XSC22-TEST","catalogId":97520002}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Success.');
        Assert.AreEqual('1', ReadText(Response, 'catalogsConsidered'), 'Filtered count.');
        Assert.AreEqual('0', ReadText(Response, 'skippedRecords'), 'Only new selected skip records.');
        Assert.AreEqual(1, Stub.GetSeenCount(), 'Connector receives the same selection.');
        UnbindSubscription(Stub);
        Stub.Cleanup();
    end;

    /// <summary>AC02/04/06: CompanyType, including excluded shops, disabled catalogs and old skip logs.</summary>
    [Test]
    procedure Scenario_AC02_CompanyType()
    var
        Stub: Codeunit "Shpfy Catalog Prices Stub ori";
        Response: JsonObject;
    begin
        Stub.Seed('XSC22-TEST');
        BindSubscription(Stub);
        Response := Execute('{"shopCode":"XSC22-TEST","catalogType":"Company"}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Success.');
        Assert.AreEqual('2', ReadText(Response, 'catalogsConsidered'), 'Filtered count.');
        Assert.AreEqual('1', ReadText(Response, 'skippedRecords'), 'Only new selected skip records.');
        Assert.AreEqual(2, Stub.GetSeenCount(), 'Connector receives the same selection.');
        Assert.IsTrue(Stub.GetParameters().Contains('<Field name="ShopifyCatalogType">1</Field>'), 'Locale-independent type option.');
        UnbindSubscription(Stub);
        Stub.Cleanup();
    end;

    /// <summary>AC02/04/06: MarketType, including excluded shops, disabled catalogs and old skip logs.</summary>
    [Test]
    procedure Scenario_AC02_MarketType()
    var
        Stub: Codeunit "Shpfy Catalog Prices Stub ori";
        Response: JsonObject;
    begin
        Stub.Seed('XSC22-TEST');
        BindSubscription(Stub);
        Response := Execute('{"shopCode":"XSC22-TEST","catalogType":"Market"}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Success.');
        Assert.AreEqual('1', ReadText(Response, 'catalogsConsidered'), 'Filtered count.');
        Assert.AreEqual('0', ReadText(Response, 'skippedRecords'), 'Only new selected skip records.');
        Assert.AreEqual(1, Stub.GetSeenCount(), 'Connector receives the same selection.');
        Assert.IsTrue(Stub.GetParameters().Contains('<Field name="ShopifyCatalogType">2</Field>'), 'Locale-independent type option.');
        UnbindSubscription(Stub);
        Stub.Cleanup();
    end;

    /// <summary>AC02/04/06: CompanyId, including excluded shops, disabled catalogs and old skip logs.</summary>
    [Test]
    procedure Scenario_AC02_CompanyId()
    var
        Stub: Codeunit "Shpfy Catalog Prices Stub ori";
        Response: JsonObject;
    begin
        Stub.Seed('XSC22-TEST');
        BindSubscription(Stub);
        Response := Execute('{"shopCode":"XSC22-TEST","companyId":97520001}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Success.');
        Assert.AreEqual('2', ReadText(Response, 'catalogsConsidered'), 'Filtered count.');
        Assert.AreEqual('1', ReadText(Response, 'skippedRecords'), 'Only new selected skip records.');
        Assert.AreEqual(2, Stub.GetSeenCount(), 'Connector receives the same selection.');
        UnbindSubscription(Stub);
        Stub.Cleanup();
    end;

    /// <summary>AC02/04/06: IntersectedFilters, including excluded shops, disabled catalogs and old skip logs.</summary>
    [Test]
    procedure Scenario_AC02_IntersectedFilters()
    var
        Stub: Codeunit "Shpfy Catalog Prices Stub ori";
        Response: JsonObject;
    begin
        Stub.Seed('XSC22-TEST');
        BindSubscription(Stub);
        Response := Execute('{"shopCode":"XSC22-TEST","catalogId":97520001,"companyId":97520001,"catalogType":"Company"}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Success.');
        Assert.AreEqual('1', ReadText(Response, 'catalogsConsidered'), 'Filtered count.');
        Assert.AreEqual('0', ReadText(Response, 'skippedRecords'), 'Only new selected skip records.');
        Assert.AreEqual(1, Stub.GetSeenCount(), 'Connector receives the same selection.');
        UnbindSubscription(Stub);
        Stub.Cleanup();
    end;

    /// <summary>AC02/04/06: CurrencyMismatch, including excluded shops, disabled catalogs and old skip logs.</summary>
    [Test]
    procedure Scenario_AC02_CurrencyMismatch()
    var
        Stub: Codeunit "Shpfy Catalog Prices Stub ori";
        Response: JsonObject;
    begin
        Stub.Seed('XSC22-TEST');
        BindSubscription(Stub);
        Response := Execute('{"shopCode":"XSC22-TEST","catalogId":97520004}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Success.');
        Assert.AreEqual('1', ReadText(Response, 'catalogsConsidered'), 'Filtered count.');
        Assert.AreEqual('1', ReadText(Response, 'skippedRecords'), 'Only new selected skip records.');
        Assert.AreEqual(1, Stub.GetSeenCount(), 'Connector receives the same selection.');
        UnbindSubscription(Stub);
        Stub.Cleanup();
    end;

    /// <summary>AC03/06: MissingShop is refused before the connector runs.</summary>
    [Test]
    procedure Scenario_AC03_MissingShop()
    begin
        AssertRefusal('{}', 'MissingParameter');
    end;

    /// <summary>AC03/06: UnknownKey is refused before the connector runs.</summary>
    [Test]
    procedure Scenario_AC03_UnknownKey()
    begin
        AssertRefusal('{"shopCode":"XSC22-TEST","bogus":true}', 'UnknownParameter');
    end;

    /// <summary>AC03/06: EmptyShop is refused before the connector runs.</summary>
    [Test]
    procedure Scenario_AC03_EmptyShop()
    begin
        AssertRefusal('{"shopCode":""}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03/06: MalformedShop is refused before the connector runs.</summary>
    [Test]
    procedure Scenario_AC03_MalformedShop()
    begin
        AssertRefusal('{"shopCode":{}}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03/06: LongShop is refused before the connector runs.</summary>
    [Test]
    procedure Scenario_AC03_LongShop()
    begin
        AssertRefusal('{"shopCode":"123456789012345678901"}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03/06: UnknownShop is refused before the connector runs.</summary>
    [Test]
    procedure Scenario_AC03_UnknownShop()
    begin
        AssertRefusal('{"shopCode":"XSC22-UNKNOWN"}', 'RecordNotFound');
    end;

    /// <summary>AC03/06: UnknownCatalog is refused before the connector runs.</summary>
    [Test]
    procedure Scenario_AC03_UnknownCatalog()
    begin
        AssertRefusal('{"shopCode":"XSC22-TEST","catalogId":1}', 'RecordNotFound');
    end;

    /// <summary>AC03/06: ForeignCatalog is refused before the connector runs.</summary>
    [Test]
    procedure Scenario_AC03_ForeignCatalog()
    begin
        AssertRefusal('{"shopCode":"XSC22-TEST","catalogId":97520005}', 'RecordNotFound');
    end;

    /// <summary>AC03/06: DisabledCatalog is refused before the connector runs.</summary>
    [Test]
    procedure Scenario_AC03_DisabledCatalog()
    begin
        AssertRefusal('{"shopCode":"XSC22-TEST","catalogId":97520003}', 'PreconditionFailed');
    end;

    /// <summary>AC03/06: NoTypeMatch is refused before the connector runs.</summary>
    [Test]
    procedure Scenario_AC03_NoTypeMatch()
    begin
        AssertRefusal('{"shopCode":"XSC22-TEST","companyId":97520001,"catalogType":"Market"}', 'PreconditionFailed');
    end;

    /// <summary>AC03/06: UnknownCompany is refused before the connector runs.</summary>
    [Test]
    procedure Scenario_AC03_UnknownCompany()
    begin
        AssertRefusal('{"shopCode":"XSC22-TEST","companyId":1}', 'RecordNotFound');
    end;

    /// <summary>AC03/06: InvalidType is refused before the connector runs.</summary>
    [Test]
    procedure Scenario_AC03_InvalidType()
    begin
        AssertRefusal('{"shopCode":"XSC22-TEST","catalogType":"company"}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03/06: NullType is refused before the connector runs.</summary>
    [Test]
    procedure Scenario_AC03_NullType()
    begin
        AssertRefusal('{"shopCode":"XSC22-TEST","catalogType":null}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03/06: ZeroId is refused before the connector runs.</summary>
    [Test]
    procedure Scenario_AC03_ZeroId()
    begin
        AssertRefusal('{"shopCode":"XSC22-TEST","catalogId":0}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03/06: NegativeId is refused before the connector runs.</summary>
    [Test]
    procedure Scenario_AC03_NegativeId()
    begin
        AssertRefusal('{"shopCode":"XSC22-TEST","companyId":-1}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03/06: FractionId is refused before the connector runs.</summary>
    [Test]
    procedure Scenario_AC03_FractionId()
    begin
        AssertRefusal('{"shopCode":"XSC22-TEST","catalogId":1.5}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03/06: StringId is refused before the connector runs.</summary>
    [Test]
    procedure Scenario_AC03_StringId()
    begin
        AssertRefusal('{"shopCode":"XSC22-TEST","catalogId":"12"}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03/06: OverflowId is refused before the connector runs.</summary>
    [Test]
    procedure Scenario_AC03_OverflowId()
    begin
        AssertRefusal('{"shopCode":"XSC22-TEST","catalogId":9223372036854775808}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03/06: MaxId is refused before the connector runs.</summary>
    [Test]
    procedure Scenario_AC03_MaxId()
    begin
        AssertRefusal('{"shopCode":"XSC22-TEST","catalogId":9223372036854775807}', 'RecordNotFound');
    end;

    /// <summary>AC03: a disabled shop cannot run the connector.</summary>
    [Test]
    procedure Scenario_AC03_DisabledShop()
    var
        Shop: Record "Shpfy Shop";
        Stub: Codeunit "Shpfy Catalog Prices Stub ori";
        Response: JsonObject;
    begin
        Stub.Seed('XSC22-TEST');
        Shop.Get('XSC22-TEST');
        Shop.Enabled := false;
        Shop.Modify();
        Commit();
        Response := Execute('{"shopCode":"XSC22-TEST"}');
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), 'Disabled shop.');
        Stub.Cleanup();
    end;

    /// <summary>AC04: connector error text is preserved and its uncommitted log write rolls back.</summary>
    [Test]
    procedure Scenario_AC04_ConnectorFailureRollsBack()
    var
        Stub: Codeunit "Shpfy Catalog Prices Stub ori";
        Skipped: RecordRef;
        Response: JsonObject;
        ResponseText: Text;
    begin
        Stub.Seed('XSC22-TEST');
        Stub.SetFailure(true);
        BindSubscription(Stub);
        Response := Execute('{"shopCode":"XSC22-TEST"}');
        Assert.AreEqual('BusinessCentralError', ReadText(Response, 'code'), 'Connector refusal.');
        Response.WriteTo(ResponseText);
        Assert.IsTrue(ResponseText.Contains('XSC22 mock connector failure'), 'Connector text retained.');
        Skipped.Open(30159);
        Skipped.Field(2).SetRange(97520001, 97520005);
        Assert.AreEqual(1, Skipped.Count(), 'Only historical skip remains after rollback.');
        UnbindSubscription(Stub);
        Stub.Cleanup();
    end;

    /// <summary>AC01: a read-only caller receives a typed permission refusal.</summary>
    [Test]
    procedure Scenario_AC01_PermissionDenied()
    var
        Stub: Codeunit "Shpfy Catalog Prices Stub ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Response: JsonObject;
    begin
        Stub.Seed('XSC22-TEST');
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        Response := Execute('{"shopCode":"XSC22-TEST"}');
        LowerPermissions.StopLoggingNAVPermissions();
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Refused.');
        Assert.AreEqual('PermissionDenied', ReadText(Response, 'code'), 'Typed refusal.');
        Stub.Cleanup();
    end;

    /// <summary>AC01/05: discovery declares a write requiring the full permission set, with help chapters.</summary>
    [Test]
    procedure Scenario_AC01_ContractAndHelp()
    var
        Impl: Codeunit "Catalog SyncPrices Impl ori";
        Effect: JsonObject;
        Parameters: JsonArray;
        Examples: JsonArray;
        HelpText: Text;
    begin
        Assert.IsTrue(Impl.GetEffect(Effect), 'Effect supplied.');
        Assert.AreEqual('write', ReadText(Effect, 'effect'), 'Write type.');
        Assert.AreEqual('SHOPIFY Full ori', ReadText(Effect, 'permissionSet'), 'Full permission set.');
        Assert.IsTrue(Impl.GetParameters(Parameters), 'Parameters supplied.');
        Assert.AreEqual(4, Parameters.Count(), 'Four supported parameters.');
        Assert.IsTrue(Impl.GetOverview(HelpText), 'Overview.');
        Assert.IsTrue(Impl.GetNotes(HelpText), 'Notes.');
        Assert.IsTrue(HelpText.Contains('Idempotent'), 'Idempotency explained.');
        Assert.IsTrue(Impl.GetExamples(Examples), 'Examples.');
    end;

    /// <summary>AC02: XML metacharacters in a shop code preserve its exact filter.</summary>
    [Test]
    procedure Scenario_AC02_XmlEscaping()
    var
        Shop: Record "Shpfy Shop";
        Stub: Codeunit "Shpfy Catalog Prices Stub ori";
        Response: JsonObject;
    begin
        Stub.Seed('XSC22&TEST');
        BindSubscription(Stub);
        Response := Execute('{"shopCode":"XSC22&TEST","catalogId":97520002}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Escaped shop works.');
        Assert.IsTrue(Stub.GetParameters().Contains('XSC22&amp;TEST'), 'XML escaped.');
        UnbindSubscription(Stub);
        Stub.Cleanup();
        Assert.IsFalse(Shop.Get('XSC22&TEST'), 'Cleanup removes the literal shop code, including the ampersand.');
    end;

    /// <summary>AC03: scalar JSON values cannot masquerade as a text shop code.</summary>
    [Test]
    procedure Scenario_AC03_NumericShopIsInvalid()
    begin
        AssertRefusal('{"shopCode":123}', 'InvalidParameterFormat');
    end;

    local procedure AssertRefusal(RequestText: Text; ExpectedCode: Text)
    var
        Stub: Codeunit "Shpfy Catalog Prices Stub ori";
        Response: JsonObject;
    begin
        Stub.Seed('XSC22-TEST');
        BindSubscription(Stub);
        Response := Execute(RequestText);
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Error status.');
        Assert.AreEqual(ExpectedCode, ReadText(Response, 'code'), 'Typed refusal.');
        Assert.AreEqual(0, Stub.GetSeenCount(), 'Connector did not run.');
        UnbindSubscription(Stub);
        Stub.Cleanup();
    end;

    local procedure Execute(RequestText: Text) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseContentType: Text[100];
        MessageVersion: Enum "Message Version ori";
        ResponseText: Text;
    begin
        RequestContent.AddText(RequestText);
        Dispatcher.Execute("Message Type ori"::"Shopify.Catalog.SyncPrices", MessageVersion, '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        Response.ReadFrom(ResponseText);
    end;

    local procedure ReadText(Object: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if Object.Get(PropertyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsText());
    end;
}
