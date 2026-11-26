namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.Customer;
using Origo.Bifrost;
using Origo.Bifrost.Shopify;
using System.TestLibraries.Utilities;

/// <summary>Issue #18: mock-only company synchronization through Foundation public dispatcher.</summary>
codeunit 97513 "Shopify Company Sync Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    /// <summary>Import creates company/location rows and echoes the applied settings.</summary>
    [Test]
    procedure Scenario_AC02_ImportOnly()
    begin
        AssertSync(2, false, false, 1, 0, 2);
    end;

    /// <summary>Export updates the existing company without adding a company.</summary>
    [Test]
    procedure Scenario_AC02_ExportOnly()
    begin
        AssertSync(0, true, false, 0, 1, 1);
    end;

    /// <summary>Both settings reach the connector unchanged.</summary>
    [Test]
    procedure Scenario_AC02_BothDirections()
    begin
        AssertSync(2, true, false, 1, 1, 2);
    end;

    /// <summary>Both settings off still succeeds with unchanged company counts.</summary>
    [Test]
    procedure Scenario_AC02_BothOff()
    begin
        AssertSync(0, false, false, 0, 0, 1);
    end;

    /// <summary>WithOrderImport alone does not import companies.</summary>
    [Test]
    procedure Scenario_AC02_OrderImportOff()
    begin
        AssertSync(1, false, false, 0, 0, 1);
    end;

    /// <summary>WithOrderImport plus update permission imports company updates.</summary>
    [Test]
    procedure Scenario_AC02_OrderImportOn()
    begin
        AssertSync(1, false, true, 1, 0, 2);
    end;

    /// <summary>Repeating the import matches existing rows; another shop is excluded from counts.</summary>
    [Test]
    procedure Scenario_AC02_RepeatAndScope()
    var
        Stub: Codeunit "Shopify Company Stub ori";
        Response: JsonObject;
    begin
        Initialize(2, false, false);
        BindSubscription(Stub);
        Response := Execute(ValidRequest());
        Assert.AreEqual('2', ReadText(Response, 'companiesAfter'), 'First import.');
        Response := Execute(ValidRequest());
        UnbindSubscription(Stub);
        Assert.AreEqual('Success', ReadText(Response, 'status'), ReadText(Response, 'error'));
        Assert.AreEqual('2', ReadText(Response, 'companiesBefore'), 'Second before count.');
        Assert.AreEqual('2', ReadText(Response, 'companiesAfter'), 'No duplicate company.');
        Cleanup();
    end;

    /// <summary>Missing required input is refused before the connector.</summary>
    [Test]
    procedure Scenario_AC03_MissingShop()
    var
        Request: JsonObject;
    begin
        Initialize(0, false, false);
        AssertRefused(Request, 'MissingParameter');
        Cleanup();
    end;

    /// <summary>Wrong scalar types, empty/blank strings and overlength input are refused.</summary>
    [Test]
    procedure Scenario_AC03_InvalidShop()
    var
        Request: JsonObject;
        Token: JsonToken;
        Value: Text;
        Values: List of [Text];
    begin
        Initialize(0, false, false);
        Values.Add('null');
        Values.Add('{}');
        Values.Add('[]');
        Values.Add('true');
        Values.Add('18');
        Values.Add('""');
        Values.Add('"   "');
        Values.Add('"123456789012345678901"');
        foreach Value in Values do begin
            Clear(Request);
            Token.ReadFrom(Value);
            Request.Add('shopCode', Token);
            AssertRefused(Request, 'InvalidParameterFormat');
        end;
        Cleanup();
    end;

    /// <summary>A twenty-character code is accepted as input and searched, without truncation.</summary>
    [Test]
    procedure Scenario_AC03_MaximumLength()
    var
        Request: JsonObject;
    begin
        Initialize(0, false, false);
        Request.Add('shopCode', 'X1234567890123456789');
        AssertRefused(Request, 'RecordNotFound');
        Cleanup();
    end;

    /// <summary>Unknown shop and disabled shop have distinct typed refusals.</summary>
    [Test]
    procedure Scenario_AC03_UnknownAndDisabled()
    var
        Shop: Record "Shpfy Shop";
        Request: JsonObject;
    begin
        Initialize(0, false, false);
        Request.Add('shopCode', 'XNO18');
        AssertRefused(Request, 'RecordNotFound');
        Shop.Get('XCOMP18');
        Shop.Enabled := false;
        Shop.Modify();
        Commit();
        AssertRefused(ValidRequest(), 'PreconditionFailed');
        Cleanup();
    end;

    /// <summary>Foundation rejects unknown keys before executing the handler.</summary>
    [Test]
    procedure Scenario_AC03_UnknownKey()
    var
        Request: JsonObject;
    begin
        Initialize(0, false, false);
        Request := ValidRequest();
        Request.Add('unexpected', true);
        AssertRefused(Request, 'UnknownParameter');
        Cleanup();
    end;

    /// <summary>A connector failure rolls back inserts, modifications and its explicit commit.</summary>
    [Test]
    procedure Scenario_AC04_FailureRollsBack()
    var
        Company: Record "Shpfy Company";
        Location: Record "Shpfy Company Location";
        Stub: Codeunit "Shopify Company Stub ori";
        Response: JsonObject;
    begin
        Initialize(2, true, false);
        Stub.Configure(true);
        BindSubscription(Stub);
        Response := Execute(ValidRequest());
        UnbindSubscription(Stub);
        Assert.AreEqual('BusinessCentralError', ReadText(Response, 'code'), ReadText(Response, 'error'));
        Assert.IsTrue(ReadText(Response, 'error').Contains('XCompany connector failure after commit'), 'Connector text retained.');
        Assert.IsFalse(Company.Get(975130018), 'New company rolled back.');
        Assert.IsFalse(Location.Get(975130018), 'New location rolled back.');
        Company.Get(975130017);
        Assert.AreEqual('XOriginal company', Company.Name, 'Existing company unchanged.');
        Cleanup();
    end;

    /// <summary>Read-only callers cannot execute the new write type.</summary>
    [Test]
    procedure Scenario_AC01_PermissionRefusal()
    var
        Stub: Codeunit "Shopify Company Stub ori";
        Response: JsonObject;
    begin
        Initialize(0, false, false);
        BindSubscription(Stub);
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        Response := Execute(ValidRequest());
        LowerPermissions.StopLoggingNAVPermissions();
        UnbindSubscription(Stub);
        Assert.AreEqual('PermissionDenied', ReadText(Response, 'code'), ReadText(Response, 'error'));
        Assert.AreEqual(0, Stub.CallCount(), 'No connector call.');
        Cleanup();
    end;

    /// <summary>Contract and discovery declare a write, Full permission and all response fields.</summary>
    [Test]
    procedure Scenario_AC01_Contract()
    var
        Impl: Codeunit "Company Sync Impl ori";
        Effect: JsonObject;
        Response: JsonObject;
        Parameters: JsonArray;
    begin
        Assert.IsTrue(Impl.GetEffect(Effect), 'Effect chapter.');
        Assert.AreEqual('write', ReadText(Effect, 'effect'), 'Write operation.');
        Assert.AreEqual('SHOPIFY Full ori', ReadText(Effect, 'permissionSet'), 'Full required.');
        Assert.IsTrue(Impl.GetParameters(Parameters), 'Parameters supplied.');
        Assert.AreEqual(1, Parameters.Count(), 'Only shopCode.');
        Assert.IsTrue(Impl.GetResponse(Response), 'Response supplied.');
    end;

    local procedure AssertSync(ImportOrdinal: Integer; ExportEnabled: Boolean; UpdateEnabled: Boolean; ExpectedImports: Integer; ExpectedExports: Integer; ExpectedAfter: Integer)
    var
        Shop: Record "Shpfy Shop";
        Company: Record "Shpfy Company";
        Customer: Record Customer;
        Stub: Codeunit "Shopify Company Stub ori";
        Response: JsonObject;
        ImportName: Text;
    begin
        Initialize(ImportOrdinal, ExportEnabled, UpdateEnabled);
        Shop.Get('XCOMP18');
        ImportName := Shop."Company Import From Shopify".Names().Get(Shop."Company Import From Shopify".Ordinals().IndexOf(ImportOrdinal));
        BindSubscription(Stub);
        Response := Execute(ValidRequest());
        UnbindSubscription(Stub);
        Assert.AreEqual('Success', ReadText(Response, 'status'), ReadText(Response, 'error'));
        Assert.AreEqual(1, Stub.CallCount(), 'One connector invocation.');
        Assert.AreEqual(ExpectedImports, Stub.Imports(), 'Import setting applied.');
        Assert.AreEqual(ExpectedExports, Stub.Exports(), 'Export setting applied.');
        Assert.AreEqual(ImportName, ReadText(Response, 'companyImportFromShopify'), 'Import echo.');
        Assert.AreEqual(Format(ExportEnabled, 0, 9), ReadText(Response, 'canUpdateShopifyCompanies'), 'Export echo.');
        Assert.AreEqual('1', ReadText(Response, 'companiesBefore'), 'Only this shop counted.');
        Assert.AreEqual(Format(ExpectedAfter, 0, 9), ReadText(Response, 'companiesAfter'), 'After count.');
        if ExpectedImports > 0 then begin
            Customer.Get('XCOMPCUST18');
            Company.Get(975130018);
            Assert.AreEqual(Customer.SystemId, Company."Customer SystemId", 'Company links to BC customer.');
        end;
        Shop.Get('XCOMP18');
        Assert.AreEqual(ImportOrdinal, Shop."Company Import From Shopify".AsInteger(), 'Import setting unchanged.');
        Assert.AreEqual(ExportEnabled, Shop."Can Update Shopify Companies", 'Export setting unchanged.');
        Company.Get(975130017);
        if ExportEnabled then
            Assert.AreEqual('XExported company', Company.Name, 'Export stand-in updated company.');
        Cleanup();
    end;

    local procedure AssertRefused(Request: JsonObject; Expected: Text)
    var
        Company: Record "Shpfy Company";
        Stub: Codeunit "Shopify Company Stub ori";
        Response: JsonObject;
    begin
        BindSubscription(Stub);
        Response := Execute(Request);
        UnbindSubscription(Stub);
        Assert.AreEqual(Expected, ReadText(Response, 'code'), ReadText(Response, 'error'));
        Assert.AreEqual(0, Stub.CallCount(), 'Refused before connector.');
        Company.Get(975130017);
        Assert.AreEqual('XOriginal company', Company.Name, 'No changes on refusal.');
    end;

    local procedure Initialize(ImportOrdinal: Integer; ExportEnabled: Boolean; UpdateEnabled: Boolean)
    var
        Shop: Record "Shpfy Shop";
        Company: Record "Shpfy Company";
        Customer: Record Customer;
    begin
        Cleanup();
        Shop.Init();
        Shop.Code := 'XCOMP18';
        Shop.Insert();
        Shop.Enabled := true;
        Shop."Logging Mode" := Shop."Logging Mode"::Disabled;
        Shop."Company Import From Shopify" := "Shpfy Company Import Range".FromInteger(ImportOrdinal);
        Shop."Can Update Shopify Companies" := ExportEnabled;
        Shop."Shopify Can Update Companies" := UpdateEnabled;
        Shop.Modify();
        Customer.Init();
        Customer."No." := 'XCOMPCUST18';
        Customer.Insert();
        Company.Init();
        Company.Id := 975130017;
        Company."Shop Code" := Shop.Code;
        Company.Name := 'XOriginal company';
        Company.Insert();
        Company.Init();
        Company.Id := 975130019;
        Company."Shop Code" := 'XOTHER18';
        Company.Insert();
        Commit();
    end;

    local procedure Cleanup()
    var
        Shop: Record "Shpfy Shop";
        Company: Record "Shpfy Company";
        Customer: Record Customer;
        Location: Record "Shpfy Company Location";
    begin
        if Location.Get(975130018) then
            Location.Delete();
        Company.SetRange(Id, 975130017, 975130019);
        Company.DeleteAll();
        if Customer.Get('XCOMPCUST18') then
            Customer.Delete();
        if Shop.Get('XCOMP18') then
            Shop.Delete();
        Commit();
    end;

    local procedure ValidRequest() Request: JsonObject
    begin
        Request.Add('shopCode', 'XCOMP18');
    end;

    local procedure Execute(Request: JsonObject) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseContentType: Text[100];
        MessageVersion: Enum "Message Version ori";
        RequestText: Text;
        ResponseText: Text;
    begin
        Request.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Dispatcher.Execute("Message Type ori"::"Shopify.Company.Sync", MessageVersion, '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        Response.ReadFrom(ResponseText);
    end;

    local procedure ReadText(Object: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        if Object.Get(Name, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsText());
        exit('');
    end;
}
