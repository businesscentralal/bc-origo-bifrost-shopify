namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Issue #21: public dispatcher coverage with a mock connector; no live Shopify calls.</summary>
codeunit 97530 "Shpfy Catalog Sync Test ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Fixture: Codeunit "Shpfy Catalog Fixture ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    /// <summary>Without imported companies, market catalogs and relations are imported; other-shop companies are excluded.</summary>
    [Test]
    procedure AC02_MarketOnly()
    var
        Relation: Record "Shpfy Market Catalog Relation";
        Response: JsonObject;
    begin
        Fixture.Seed();
        Response := ExecuteRaw('{"shopCode":"BIFT21"}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Market success.');
        Assert.AreEqual('0', ReadText(Response, 'catalogsBefore'), 'Initial count.');
        Assert.AreEqual('1', ReadText(Response, 'catalogsAfter'), 'Market catalog only.');
        Relation.SetRange("Shop Code", 'BIFT21');
        Assert.AreEqual(1, Relation.Count(), 'Market relation imported.');
        Fixture.Remove();
    end;

    /// <summary>Imported companies add their catalogs; repeated calls keep counts and relations stable.</summary>
    [Test]
    procedure AC02_CompanyAndRepeat()
    var
        Relation: Record "Shpfy Market Catalog Relation";
        Response: JsonObject;
    begin
        Fixture.Seed();
        Fixture.AddCompany();
        Response := ExecuteRaw('{"shopCode":"BIFT21"}');
        Assert.AreEqual('2', ReadText(Response, 'catalogsAfter'), 'Market and company.');
        Response := ExecuteRaw('{"shopCode":"BIFT21"}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Repeat succeeds.');
        Assert.AreEqual('2', ReadText(Response, 'catalogsBefore'), 'Repeat before.');
        Assert.AreEqual('2', ReadText(Response, 'catalogsAfter'), 'No duplicate catalogs.');
        Relation.SetRange("Shop Code", 'BIFT21');
        Assert.AreEqual(1, Relation.Count(), 'No duplicate relations.');
        Fixture.Remove();
    end;

    /// <summary>Refuses Missing before local writes.</summary>
    [Test]
    procedure AC03_Missing()
    begin
        Fixture.Seed();
        AssertRefusal('{}', 'MissingParameter');
        Fixture.Remove();
    end;

    /// <summary>Refuses UnknownKey before local writes.</summary>
    [Test]
    procedure AC03_UnknownKey()
    begin
        Fixture.Seed();
        AssertRefusal('{"shopCode":"BIFT21","bogus":true}', 'InvalidParameterFormat');
        Fixture.Remove();
    end;

    /// <summary>Refuses Null before local writes.</summary>
    [Test]
    procedure AC03_Null()
    begin
        Fixture.Seed();
        AssertRefusal('{"shopCode":null}', 'InvalidParameterFormat');
        Fixture.Remove();
    end;

    /// <summary>Refuses Number before local writes.</summary>
    [Test]
    procedure AC03_Number()
    begin
        Fixture.Seed();
        AssertRefusal('{"shopCode":21}', 'InvalidParameterFormat');
        Fixture.Remove();
    end;

    /// <summary>Refuses Boolean before local writes.</summary>
    [Test]
    procedure AC03_Boolean()
    begin
        Fixture.Seed();
        AssertRefusal('{"shopCode":true}', 'InvalidParameterFormat');
        Fixture.Remove();
    end;

    /// <summary>Refuses Array before local writes.</summary>
    [Test]
    procedure AC03_Array()
    begin
        Fixture.Seed();
        AssertRefusal('{"shopCode":[]}', 'InvalidParameterFormat');
        Fixture.Remove();
    end;

    /// <summary>Refuses Object before local writes.</summary>
    [Test]
    procedure AC03_Object()
    begin
        Fixture.Seed();
        AssertRefusal('{"shopCode":{}}', 'InvalidParameterFormat');
        Fixture.Remove();
    end;

    /// <summary>Refuses Empty before local writes.</summary>
    [Test]
    procedure AC03_Empty()
    begin
        Fixture.Seed();
        AssertRefusal('{"shopCode":""}', 'InvalidParameterFormat');
        Fixture.Remove();
    end;

    /// <summary>Refuses Whitespace before local writes.</summary>
    [Test]
    procedure AC03_Whitespace()
    begin
        Fixture.Seed();
        AssertRefusal('{"shopCode":"   "}', 'InvalidParameterFormat');
        Fixture.Remove();
    end;

    /// <summary>Refuses TooLong before local writes.</summary>
    [Test]
    procedure AC03_TooLong()
    begin
        Fixture.Seed();
        AssertRefusal('{"shopCode":"123456789012345678901"}', 'InvalidParameterFormat');
        Fixture.Remove();
    end;

    /// <summary>Refuses UnknownShop before local writes.</summary>
    [Test]
    procedure AC03_UnknownShop()
    begin
        Fixture.Seed();
        AssertRefusal('{"shopCode":"BIFT21MISSING"}', 'RecordNotFound');
        Fixture.Remove();
    end;

    /// <summary>Refuses DisabledShop before local writes.</summary>
    [Test]
    procedure AC03_DisabledShop()
    begin
        Fixture.Seed();
        AssertRefusal('{"shopCode":"BIFT21OFF"}', 'PreconditionFailed');
        Fixture.Remove();
    end;

    /// <summary>Accepts a literal shop code at the valid boundary.</summary>
    [Test]
    procedure AC03_FilterCharacters()
    var
        Response: JsonObject;
    begin
        Fixture.Seed();
        Response := ExecuteRaw('{"shopCode":"BIFT21&<|()"}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Literal shop success.');
        Assert.AreEqual('BIFT21&<|()', ReadText(Response, 'shopCode'), 'Exact shop selected.');
        Fixture.Remove();
    end;

    /// <summary>Accepts a literal shop code at the valid boundary.</summary>
    [Test]
    procedure AC03_MaxLength()
    var
        Response: JsonObject;
    begin
        Fixture.Seed();
        Response := ExecuteRaw('{"shopCode":"BIFT21-1234567890123"}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Literal shop success.');
        Assert.AreEqual('BIFT21-1234567890123', ReadText(Response, 'shopCode'), 'Exact shop selected.');
        Fixture.Remove();
    end;

    /// <summary>Failure after writes rolls back catalogs and restores existing relations.</summary>
    [Test]
    procedure AC04_ConnectorFailure()
    var
        Catalog: Record "Shpfy Catalog";
        Relation: Record "Shpfy Market Catalog Relation";
        EmptyGuid: Guid;
        Response: JsonObject;
    begin
        Fixture.Seed();
        Catalog.Init();
        Catalog.Id := 2100001;
        Catalog."Shop Code" := 'BIFT21FAIL';
        Catalog.Name := 'Original';
        Catalog.Insert();
        Relation.Init();
        Relation."Shop Code" := 'BIFT21FAIL';
        Relation."Catalog Id" := 2100001;
        Relation."Market Id" := 2100099;
        Relation.Insert();
        Commit();
        Response := ExecuteRaw('{"shopCode":"BIFT21FAIL"}');
        Assert.AreEqual('BusinessCentralError', ReadText(Response, 'code'), 'Connector refused.');
        Catalog.Get(2100001, EmptyGuid);
        Assert.AreEqual('Original', Catalog.Name, 'Existing catalog unchanged.');
        Relation.SetRange("Shop Code", 'BIFT21FAIL');
        Assert.AreEqual(1, Relation.Count(), 'Exactly original relation.');
        Relation.FindFirst();
        Assert.AreEqual(2100099L, Relation."Market Id", 'Original relation restored.');
        Fixture.Remove();
    end;

    /// <summary>Failure after writes rolls back catalogs and restores existing relations.</summary>
    [Test]
    procedure AC04_ExplicitCommit()
    var
        Catalog: Record "Shpfy Catalog";
        Relation: Record "Shpfy Market Catalog Relation";
        EmptyGuid: Guid;
        Response: JsonObject;
    begin
        Fixture.Seed();
        Catalog.Init();
        Catalog.Id := 2100001;
        Catalog."Shop Code" := 'BIFT21COMMIT';
        Catalog.Name := 'Original';
        Catalog.Insert();
        Relation.Init();
        Relation."Shop Code" := 'BIFT21COMMIT';
        Relation."Catalog Id" := 2100001;
        Relation."Market Id" := 2100099;
        Relation.Insert();
        Commit();
        Response := ExecuteRaw('{"shopCode":"BIFT21COMMIT"}');
        Assert.AreEqual('BusinessCentralError', ReadText(Response, 'code'), 'Connector refused.');
        Catalog.Get(2100001, EmptyGuid);
        Assert.AreEqual('Original', Catalog.Name, 'Existing catalog unchanged.');
        Relation.SetRange("Shop Code", 'BIFT21COMMIT');
        Assert.AreEqual(1, Relation.Count(), 'Exactly original relation.');
        Relation.FindFirst();
        Assert.AreEqual(2100099L, Relation."Market Id", 'Original relation restored.');
        Fixture.Remove();
    end;

    /// <summary>A caller with the Read role cannot execute this write type.</summary>
    [Test]
    procedure AC01_ReadPermissionDenied()
    var
        Response: JsonObject;
    begin
        Fixture.Seed();
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        Response := ExecuteRaw('{"shopCode":"BIFT21"}');
        LowerPermissions.StopLoggingNAVPermissions();
        Assert.AreEqual('PermissionDenied', ReadText(Response, 'code'), 'Read role denied.');
        Fixture.Remove();
    end;

    local procedure AssertRefusal(Request: Text; Code: Text)
    var
        Catalog: Record "Shpfy Catalog";
        Response: JsonObject;
    begin
        Response := ExecuteRaw(Request);
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Refusal status.');
        Assert.AreEqual(Code, ReadText(Response, 'code'), 'Typed refusal.');
        Catalog.SetFilter("Shop Code", 'BIFT21*');
        Assert.IsTrue(Catalog.IsEmpty(), 'No catalog writes.');
    end;

    local procedure ExecuteRaw(RequestText: Text) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ContentType: Text[100];
        Version: Enum "Message Version ori";
        ResponseText: Text;
    begin
        RequestContent.AddText(RequestText);
        Dispatcher.Execute("Message Type ori"::"Shopify.Catalog.Sync", Version, '', '', 'application/json', RequestContent, ResponseContent, ContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        Response.ReadFrom(ResponseText);
    end;

    local procedure ReadText(Response: JsonObject; ParameterName: Text): Text
    var
        Token: JsonToken;
    begin
        if Response.Get(ParameterName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsText());
        exit('');
    end;
}
