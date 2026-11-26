namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.Customer;
using Origo.Bifrost;
using Origo.Bifrost.Shopify;
using System.TestLibraries.Utilities;

/// <summary>Issue #17: dispatcher contract, preflight, idempotency and per-customer rollback with mocks only.</summary>
codeunit 97590 "Shopify Customer Add Tests ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    /// <summary>Creates one link with the returned Shopify identifier; repeat skips the connector.</summary>
    [Test]
    procedure Scenario_AC02_CreateAndRepeat()
    var
        Link: Record "Shpfy Customer";
        Stub: Codeunit "Shopify Customer Add Stub ori";
        Response: JsonObject;
        Results: JsonToken;
        Row: JsonToken;
    begin
        Initialize();
        BindSubscription(Stub);
        Response := Execute(ValidRequest());
        Assert.AreEqual('1', ReadText(Response, 'created'), 'One new link.');
        Response.Get('results', Results);
        Results.AsArray().Get(0, Row);
        Assert.AreEqual('created', ReadText(Row.AsObject(), 'outcome'), 'Created result.');
        Link.Get(975900001);
        Assert.AreEqual(Format(Link.Id, 0, 9), ReadText(Row.AsObject(), 'shopifyCustomerId'), 'Actual link ID.');
        Response := Execute(ValidRequest());
        UnbindSubscription(Stub);
        Assert.AreEqual('1', ReadText(Response, 'alreadyLinked'), 'Repeat linked.');
        Assert.AreEqual('0', ReadText(Response, 'created'), 'No duplicate.');
        Assert.AreEqual(1, Stub.CallCount(), 'Report called only for first request.');
        Cleanup();
    end;

    /// <summary>One failing customer does not prevent later customers and rolls back an explicit commit.</summary>
    [Test]
    procedure Scenario_AC04_PartialFailure()
    var
        Link: Record "Shpfy Customer";
        Customer: Record Customer;
        Stub: Codeunit "Shopify Customer Add Stub ori";
        Response: JsonObject;
        Results: JsonToken;
        Row: JsonToken;
    begin
        Initialize();
        Stub.Configure('XCA17-2', '');
        BindSubscription(Stub);
        Response := Execute(RequestFor('["XCA17-1","XCA17-2","XCA17-3"]', '3'));
        UnbindSubscription(Stub);
        Assert.AreEqual('Success', ReadText(Response, 'status'), ReadText(Response, 'error'));
        Assert.AreEqual('2', ReadText(Response, 'created'), 'Other customers continue.');
        Assert.AreEqual('1', ReadText(Response, 'failed'), 'One failure.');
        Response.Get('results', Results);
        Results.AsArray().Get(1, Row);
        Assert.IsTrue(ReadText(Row.AsObject(), 'error').Contains('XConnector failure after link and commit'), 'Connector text preserved.');
        Customer.Get('XCA17-2');
        Link.SetRange("Customer SystemId", Customer.SystemId);
        Assert.IsTrue(Link.IsEmpty(), 'No half-made link after explicit commit.');
        Cleanup();
    end;

    /// <summary>A silent connector skip returns its fresh reason and removes its local writes.</summary>
    [Test]
    procedure Scenario_AC04_SkippedReason()
    var
        Customer: Record Customer;
        Stub: Codeunit "Shopify Customer Add Stub ori";
        Skipped: RecordRef;
        Response: JsonObject;
        Results: JsonToken;
        Row: JsonToken;
    begin
        Initialize();
        Stub.Configure('', 'XCA17-1');
        BindSubscription(Stub);
        Response := Execute(ValidRequest());
        UnbindSubscription(Stub);
        Assert.AreEqual('1', ReadText(Response, 'failed'), 'Logged skip failed.');
        Response.Get('results', Results);
        Results.AsArray().Get(0, Row);
        Assert.IsTrue(ReadText(Row.AsObject(), 'error').Contains('XConnector: customer has no usable e-mail.'), 'Skipped text preserved.');
        Customer.Get('XCA17-1');
        Skipped.Open(30159);
        Skipped.Field(5).SetRange(Customer.RecordId());
        Assert.IsTrue(Skipped.IsEmpty(), 'Skip write rolled back with customer.');
        Cleanup();
    end;

    /// <summary>One hundred customers are accepted at the upper bound.</summary>
    [Test]
    procedure Scenario_AC03_MaximumSelection()
    var
        Customer: Record Customer;
        Stub: Codeunit "Shopify Customer Add Stub ori";
        Request: JsonObject;
        Nos: JsonArray;
        Response: JsonObject;
        Index: Integer;
    begin
        Initialize();
        for Index := 1 to 100 do begin
            Customer.Init();
            Customer."No." := CopyStr('XCA17-M' + Format(Index, 0, 9), 1, 20);
            Customer.Insert();
            Nos.Add(Customer."No.");
        end;
        Commit();
        Request.Add('shopCode', 'XCA17');
        Request.Add('customerNos', Nos);
        Request.Add('expectedCount', 100);
        BindSubscription(Stub);
        Response := Execute(Request);
        UnbindSubscription(Stub);
        Assert.AreEqual('100', ReadText(Response, 'created'), ReadText(Response, 'error'));
        Assert.AreEqual(100, Stub.CallCount(), 'One report per customer.');
        Cleanup();
    end;

    /// <summary>An existing link in another shop does not skip the requested shop.</summary>
    [Test]
    procedure Scenario_AC04_OtherShopLink()
    var
        Link: Record "Shpfy Customer";
        Customer: Record Customer;
        Shop: Record "Shpfy Shop";
        Stub: Codeunit "Shopify Customer Add Stub ori";
        Response: JsonObject;
    begin
        Initialize();
        Shop.Init();
        Shop.Code := 'XCA17OTHER';
        Shop.Insert();
        Customer.Get('XCA17-1');
        Link.Init();
        Link.Id := 975900100;
        Link."Shop Id" := Shop."Shop Id";
        Link."Customer SystemId" := Customer.SystemId;
        Link.Insert();
        Commit();
        BindSubscription(Stub);
        Response := Execute(ValidRequest());
        UnbindSubscription(Stub);
        Assert.AreEqual('1', ReadText(Response, 'created'), 'Shop-scoped matching.');
        Assert.AreEqual('0', ReadText(Response, 'alreadyLinked'), 'Other shop excluded.');
        Cleanup();
    end;

    /// <summary>A read-only caller is refused before any connector invocation.</summary>
    [Test]
    procedure Scenario_AC01_PermissionRefused()
    var
        Stub: Codeunit "Shopify Customer Add Stub ori";
        Response: JsonObject;
    begin
        Initialize();
        BindSubscription(Stub);
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        Response := Execute(ValidRequest());
        LowerPermissions.StopLoggingNAVPermissions();
        UnbindSubscription(Stub);
        Assert.AreEqual('PermissionDenied', ReadText(Response, 'code'), ReadText(Response, 'error'));
        Assert.AreEqual(0, Stub.CallCount(), 'No report call.');
        Cleanup();
    end;

    /// <summary>The contract declares a write and a Full role with three required parameters.</summary>
    [Test]
    procedure Scenario_AC01_Contract()
    var
        Impl: Codeunit "Customer Add Impl ori";
        Effect: JsonObject;
        Parameters: JsonArray;
    begin
        Assert.IsTrue(Impl.GetEffect(Effect), 'Effect supplied.');
        Assert.AreEqual('write', ReadText(Effect, 'effect'), 'Write effect.');
        Assert.AreEqual('SHOPIFY Full ori', ReadText(Effect, 'permissionSet'), 'Full permission.');
        Assert.IsTrue(Impl.GetParameters(Parameters), 'Parameters supplied.');
        Assert.AreEqual(3, Parameters.Count(), 'Three parameters.');
    end;

    /// <summary>MissingShop: refused before any connector call or link write.</summary>
    [Test]
    procedure Scenario_AC03_MissingShop()
    var
        Request: JsonObject;
    begin
        Initialize();
        Request.ReadFrom('{"customerNos":["XCA17-1"],"expectedCount":1}');
        AssertRefused(Request, 'MissingParameter');
        Cleanup();
    end;

    /// <summary>MissingCustomers: refused before any connector call or link write.</summary>
    [Test]
    procedure Scenario_AC03_MissingCustomers()
    var
        Request: JsonObject;
    begin
        Initialize();
        Request.ReadFrom('{"shopCode":"XCA17","expectedCount":1}');
        AssertRefused(Request, 'MissingParameter');
        Cleanup();
    end;

    /// <summary>MissingCount: refused before any connector call or link write.</summary>
    [Test]
    procedure Scenario_AC03_MissingCount()
    var
        Request: JsonObject;
    begin
        Initialize();
        Request.ReadFrom('{"shopCode":"XCA17","customerNos":["XCA17-1"]}');
        AssertRefused(Request, 'MissingParameter');
        Cleanup();
    end;

    /// <summary>UnknownKey: refused before any connector call or link write.</summary>
    [Test]
    procedure Scenario_AC03_UnknownKey()
    var
        Request: JsonObject;
    begin
        Initialize();
        Request.ReadFrom('{"shopCode":"XCA17","customerNos":["XCA17-1"],"expectedCount":1,"unknown":true}');
        AssertRefused(Request, 'UnknownParameter');
        Cleanup();
    end;

    /// <summary>UnknownShop: refused before any connector call or link write.</summary>
    [Test]
    procedure Scenario_AC03_UnknownShop()
    var
        Request: JsonObject;
    begin
        Initialize();
        Request.ReadFrom('{"shopCode":"XNO17","customerNos":["XCA17-1"],"expectedCount":1}');
        AssertRefused(Request, 'RecordNotFound');
        Cleanup();
    end;

    /// <summary>UnknownCustomer: refused before any connector call or link write.</summary>
    [Test]
    procedure Scenario_AC03_UnknownCustomer()
    var
        Request: JsonObject;
    begin
        Initialize();
        Request.ReadFrom('{"shopCode":"XCA17","customerNos":["XCA17-1","XNO17"],"expectedCount":2}');
        AssertRefused(Request, 'RecordNotFound');
        Cleanup();
    end;

    /// <summary>Mismatch: refused before any connector call or link write.</summary>
    [Test]
    procedure Scenario_AC03_Mismatch()
    var
        Request: JsonObject;
    begin
        Initialize();
        Request.ReadFrom('{"shopCode":"XCA17","customerNos":["XCA17-1"],"expectedCount":2}');
        AssertRefused(Request, 'PreconditionFailed');
        Cleanup();
    end;

    /// <summary>Disabled shops are refused before writes.</summary>
    [Test]
    procedure Scenario_AC03_DisabledShop()
    var
        Shop: Record "Shpfy Shop";
    begin
        Initialize();
        Shop.Get('XCA17');
        Shop.Enabled := false;
        Shop.Modify();
        Commit();
        AssertRefused(ValidRequest(), 'PreconditionFailed');
        Cleanup();
    end;

    /// <summary>Malformed ShopCode values have typed refusals without writes.</summary>
    [Test]
    procedure Scenario_AC03_InvalidShopCode()
    var
        Values: List of [Text];
        Value: Text;
        Request: JsonObject;
        Token: JsonToken;
    begin
        Initialize();
        Values.Add('null');
        Values.Add('true');
        Values.Add('12');
        Values.Add('{}');
        Values.Add('[]');
        Values.Add('""');
        Values.Add('"   "');
        Values.Add('"X12345678901234567890"');
        foreach Value in Values do begin
            Request := ValidRequest();
            Token.ReadFrom(Value);
            Request.Replace('shopCode', Token);
            AssertRefused(Request, 'InvalidParameterFormat');
        end;
        Cleanup();
    end;

    /// <summary>Malformed CustomerArray values have typed refusals without writes.</summary>
    [Test]
    procedure Scenario_AC03_InvalidCustomerArray()
    var
        Values: List of [Text];
        Value: Text;
        Request: JsonObject;
        Token: JsonToken;
    begin
        Initialize();
        Values.Add('null');
        Values.Add('true');
        Values.Add('"XCA17-1"');
        Values.Add('{}');
        Values.Add('[]');
        Values.Add('[null]');
        Values.Add('[true]');
        Values.Add('[12]');
        Values.Add('[{}]');
        Values.Add('[[]]');
        Values.Add('[""]');
        Values.Add('["  "]');
        Values.Add('["X12345678901234567890"]');
        Values.Add('["XCA17-1","xca17-1"]');
        Values.Add('["XCA17-1"," XCA17-1 "]');
        foreach Value in Values do begin
            Request := ValidRequest();
            Token.ReadFrom(Value);
            Request.Replace('customerNos', Token);
            AssertRefused(Request, 'InvalidParameterFormat');
        end;
        Cleanup();
    end;

    /// <summary>Malformed Count values have typed refusals without writes.</summary>
    [Test]
    procedure Scenario_AC03_InvalidCount()
    var
        Values: List of [Text];
        Value: Text;
        Request: JsonObject;
        Token: JsonToken;
    begin
        Initialize();
        Values.Add('null');
        Values.Add('true');
        Values.Add('"1"');
        Values.Add('{}');
        Values.Add('[]');
        Values.Add('0');
        Values.Add('-1');
        Values.Add('1.5');
        Values.Add('101');
        Values.Add('2147483648');
        Values.Add('9999999999999999999999');
        foreach Value in Values do begin
            Request := ValidRequest();
            Token.ReadFrom(Value);
            Request.Replace('expectedCount', Token);
            AssertRefused(Request, 'InvalidParameterFormat');
        end;
        Cleanup();
    end;

    /// <summary>One hundred and one customers exceed the limit before lookups or writes.</summary>
    [Test]
    procedure Scenario_AC03_OversizeSelection()
    var
        Request: JsonObject;
        Nos: JsonArray;
        Index: Integer;
    begin
        Initialize();
        for Index := 1 to 101 do
            Nos.Add('XCA17-' + Format(Index, 0, 9));
        Request := ValidRequest();
        Request.Replace('customerNos', Nos);
        Request.Replace('expectedCount', 101);
        AssertRefused(Request, 'InvalidParameterFormat');
        Cleanup();
    end;

    /// <summary>Filter metacharacters in customer numbers remain literal and never widen the report selection.</summary>
    [Test]
    procedure Scenario_AC03_LiteralFilter()
    var
        Customer: Record Customer;
        Stub: Codeunit "Shopify Customer Add Stub ori";
        Response: JsonObject;
    begin
        Initialize();
        Customer.Init();
        Customer."No." := 'XCA17-A|B&<>*';
        Customer.Insert();
        Commit();
        BindSubscription(Stub);
        Response := Execute(RequestFor('["XCA17-A|B&<>*"]', '1'));
        UnbindSubscription(Stub);
        Assert.AreEqual('1', ReadText(Response, 'created'), ReadText(Response, 'error'));
        Assert.AreEqual(1, Stub.CallCount(), 'Literal selection.');
        Cleanup();
    end;

    /// <summary>Twenty-character shop and customer codes are searched without truncation.</summary>
    [Test]
    procedure Scenario_AC03_MaximumCodeLength()
    var
        Request: JsonObject;
    begin
        Initialize();
        Request := ValidRequest();
        Request.Replace('shopCode', 'X1234567890123456789');
        AssertRefused(Request, 'RecordNotFound');
        AssertRefused(RequestFor('["X1234567890123456789"]', '1'), 'RecordNotFound');
        Cleanup();
    end;

    /// <summary>A missing link without a fresh log returns guidance rather than a stale connector reason.</summary>
    [Test]
    procedure Scenario_AC04_NoResultAndStaleLog()
    var
        Customer: Record Customer;
        Stub: Codeunit "Shopify Customer Add Stub ori";
        Response: JsonObject;
        Results: JsonToken;
        Row: JsonToken;
    begin
        Initialize();
        Customer.Get('XCA17-1');
        Stub.InsertSkipped(Customer.RecordId(), 'XStale reason must not be returned');
        Commit();
        Stub.Configure('XNOOUTPUT', '');
        BindSubscription(Stub);
        Response := Execute(ValidRequest());
        UnbindSubscription(Stub);
        Assert.AreEqual('1', ReadText(Response, 'failed'), 'Missing link is a failure.');
        Response.Get('results', Results);
        Results.AsArray().Get(0, Row);
        Assert.IsFalse(ReadText(Row.AsObject(), 'error').Contains('XStale'), 'Old log excluded.');
        Assert.IsTrue(ReadText(Row.AsObject(), 'error') <> '', 'Actionable fallback.');
        Cleanup();
    end;

    local procedure Initialize()
    var
        Shop: Record "Shpfy Shop";
        Fixture: Codeunit "Shopify CustAdd Fixture ori";
    begin
        Fixture.A1SeedFixture();
        Shop.Init();
        Shop.Code := 'XCA17';
        Shop.Insert();
        Shop.Enabled := true;
        Shop."Logging Mode" := Shop."Logging Mode"::Disabled;
        Shop.Modify();
        Commit();
    end;

    local procedure Cleanup()
    var
        Fixture: Codeunit "Shopify CustAdd Fixture ori";
    begin
        Fixture.A2RemoveFixture();
    end;

    local procedure AssertRefused(Request: JsonObject; ExpectedCode: Text)
    var
        Link: Record "Shpfy Customer";
        Stub: Codeunit "Shopify Customer Add Stub ori";
        Response: JsonObject;
    begin
        BindSubscription(Stub);
        Response := Execute(Request);
        UnbindSubscription(Stub);
        Assert.AreEqual(ExpectedCode, ReadText(Response, 'code'), ReadText(Response, 'error'));
        Assert.AreEqual(0, Stub.CallCount(), 'No connector call on refusal.');
        Link.SetRange(Id, 975900001, 975900200);
        Assert.IsTrue(Link.IsEmpty(), 'No write on refusal.');
    end;

    local procedure ValidRequest(): JsonObject
    begin
        exit(RequestFor('["XCA17-1"]', '1'));
    end;

    local procedure RequestFor(Nos: Text; CountText: Text) Request: JsonObject
    begin
        Request.ReadFrom('{"shopCode":"XCA17","customerNos":' + Nos + ',"expectedCount":' + CountText + '}');
    end;

    local procedure Execute(Request: JsonObject) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ContentType: Text[100];
        Version: Enum "Message Version ori";
        RequestText: Text;
        ResponseText: Text;
    begin
        Request.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Dispatcher.Execute("Message Type ori"::"Shopify.Customer.Add", Version, '', '', 'application/json', RequestContent, ResponseContent, ContentType);
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
