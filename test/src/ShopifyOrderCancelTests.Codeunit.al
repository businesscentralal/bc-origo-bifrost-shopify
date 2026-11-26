namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.Document;
using Origo.Bifrost;
using Origo.Bifrost.Shopify;
using System.TestLibraries.Utilities;

/// <summary>Issue #27: mock-only public-dispatcher cancellation tests. No credential or external Shopify call is used.</summary>
codeunit 97503 "Shopify Order Cancel Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        OrderIdTok: Label '975030027', Locked = true;
        ShopCodeTok: Label 'XCANCEL27', Locked = true;

    /// <summary>All eight boolean combinations and all six reasons reach the API unchanged; local records stay unchanged.</summary>
    [Test]
    procedure Scenario_AC02_AllChoicesReachAPI()
    var
        OrderHeader: Record "Shpfy Order Header";
        SalesHeader: Record "Sales Header";
        Stub: Codeunit "Shopify Cancel Stub ori";
        Response: JsonObject;
        Request: JsonObject;
        Reason: Enum "Shpfy Cancel Reason";
        ReasonName: Text;
        Choice: Integer;
        ReasonOrdinal: Integer;
    begin
        Initialize();
        // Assumption: all valid choices are explicit; the stand-in must receive exactly those choices.
        for ReasonOrdinal := 1 to 6 do begin
            Reason := "Shpfy Cancel Reason".FromInteger(ReasonOrdinal);
            ReasonName := Reason.Names().Get(Reason.Ordinals().IndexOf(ReasonOrdinal));
            for Choice := 0 to 7 do begin
                Request := ValidRequest();
                Request.Replace('reason', ReasonName);
                Request.Replace('notifyCustomer', (Choice mod 2) = 1);
                Request.Replace('refund', ((Choice div 2) mod 2) = 1);
                Request.Replace('restock', ((Choice div 4) mod 2) = 1);
                Stub.Configure(OrderId(), ShopCodeTok, Reason, (Choice mod 2) = 1, ((Choice div 2) mod 2) = 1, ((Choice div 4) mod 2) = 1, false, false);
                BindSubscription(Stub);
                Response := Execute(Request);
                UnbindSubscription(Stub);
                Assert.AreEqual('Success', ReadText(Response, 'status'), ReadText(Response, 'error'));
                Assert.AreEqual(1, Stub.CallCount(), 'Exactly one API call.');
                Assert.AreEqual(OrderIdTok, ReadText(Response, 'orderId'), 'Echo ID.');
                Assert.AreEqual(ShopCodeTok, ReadText(Response, 'shopCode'), 'Echo shop.');
                Assert.AreEqual(ReasonName, ReadText(Response, 'reason'), 'Invariant reason name.');
                Assert.AreEqual(ReadText(Request, 'notifyCustomer'), ReadText(Response, 'notifyCustomer'), 'Echo notification.');
                Assert.AreEqual(ReadText(Request, 'refund'), ReadText(Response, 'refund'), 'Echo refund.');
                Assert.AreEqual(ReadText(Request, 'restock'), ReadText(Response, 'restock'), 'Echo restock.');
                OrderHeader.Get(OrderId());
                Assert.AreEqual(0DT, OrderHeader."Cancelled At", 'Imported order is unchanged.');
                Assert.AreEqual('XCANCEL27', OrderHeader."Sales Order No.", 'BC document link is unchanged.');
                SalesHeader.Get(SalesHeader."Document Type"::Order, 'XCANCEL27');
                Assert.AreEqual(SalesHeader.Status::Open, SalesHeader.Status, 'Linked BC sales order is unchanged.');
            end;
        end;
        Cleanup();
    end;

    /// <summary>Each of the six keys is mandatory, even when its Boolean value would be false.</summary>
    [Test]
    procedure Scenario_AC03_EachMissingKey()
    var
        Request: JsonObject;
        Name: Text;
        Names: List of [Text];
    begin
        Initialize();
        Request := ValidRequest();
        Names := Request.Keys();
        foreach Name in Names do begin
            Request := ValidRequest();
            Request.Remove(Name);
            AssertRefused(Request, 'MissingParameter', Name);
        end;
        Cleanup();
    end;

    /// <summary>Null, object and array values are invalid for every scalar key.</summary>
    [Test]
    procedure Scenario_AC03_MalformedScalars()
    var
        Request: JsonObject;
        Names: List of [Text];
        Name: Text;
        Bad: JsonToken;
        BadText: Text;
        BadValues: List of [Text];
    begin
        Initialize();
        Request := ValidRequest();
        Names := Request.Keys();
        BadValues.Add('null');
        BadValues.Add('{}');
        BadValues.Add('[]');
        foreach Name in Names do
            foreach BadText in BadValues do begin
                Request := ValidRequest();
                Bad.ReadFrom(BadText);
                Request.Replace(Name, Bad);
                AssertRefused(Request, 'InvalidParameterFormat', Name);
            end;
        Cleanup();
    end;

    /// <summary>Unsupported names, blanks, casing changes and enum ordinals never reach Shopify.</summary>
    [Test]
    procedure Scenario_AC03_InvalidReasons()
    var
        Request: JsonObject;
        BadReason: Text;
        Reasons: List of [Text];
    begin
        Initialize();
        Reasons.Add('');
        Reasons.Add(' ');
        Reasons.Add('Unknown');
        Reasons.Add('customer');
        Reasons.Add('Invalid');
        foreach BadReason in Reasons do begin
            Request := ValidRequest();
            Request.Replace('reason', BadReason);
            AssertRefused(Request, 'InvalidParameterFormat', 'reason');
        end;
        Request := ValidRequest();
        Request.Replace('reason', 1);
        AssertRefused(Request, 'InvalidParameterFormat', 'reason');
        Cleanup();
    end;

    /// <summary>Wrong integer types and confirmation boundaries are rejected before the connector.</summary>
    [Test]
    procedure Scenario_AC03_IntegerBoundaries()
    var
        Request: JsonObject;
        Value: Integer;
    begin
        Initialize();
        for Value := -1 to 2 do
            if Value <> 1 then begin
                Request := ValidRequest();
                Request.Replace('expectedCount', Value);
                AssertRefused(Request, 'InvalidParameterFormat', 'expectedCount');
            end;
        Request := ValidRequest();
        Request.Replace('orderId', 0);
        AssertRefused(Request, 'InvalidParameterFormat', 'orderId');
        Request.Replace('orderId', -1);
        AssertRefused(Request, 'InvalidParameterFormat', 'orderId');
        Request.Replace('orderId', 1.5);
        AssertRefused(Request, 'InvalidParameterFormat', 'orderId');
        Request.Replace('orderId', OrderIdTok);
        AssertRefused(Request, 'InvalidParameterFormat', 'orderId');
        Request := ValidRequest();
        Request.Replace('expectedCount', '1');
        AssertRefused(Request, 'InvalidParameterFormat', 'expectedCount');
        Request.Replace('expectedCount', 1.5);
        AssertRefused(Request, 'InvalidParameterFormat', 'expectedCount');
        Cleanup();
    end;

    /// <summary>BigInteger maximum is a valid ID; overflow is refused before any lookup or connector call.</summary>
    [Test]
    procedure Scenario_AC03_BigIntegerLimits()
    var
        Request: JsonObject;
        Number: JsonToken;
    begin
        Initialize();
        Request := ValidRequest();
        Number.ReadFrom('9223372036854775807');
        Request.Replace('orderId', Number);
        AssertRefused(Request, 'RecordNotFound', 'orderId');
        Number.ReadFrom('9223372036854775808');
        Request.Replace('orderId', Number);
        AssertRefused(Request, 'InvalidParameterFormat', 'orderId');
        Cleanup();
    end;

    /// <summary>Strings and numeric truth values never stand in for JSON booleans.</summary>
    [Test]
    procedure Scenario_AC03_StrictBooleans()
    var
        Request: JsonObject;
        Names: List of [Text];
        Name: Text;
    begin
        Initialize();
        Names.Add('notifyCustomer');
        Names.Add('refund');
        Names.Add('restock');
        foreach Name in Names do begin
            Request := ValidRequest();
            Request.Replace(Name, 'false');
            AssertRefused(Request, 'InvalidParameterFormat', Name);
            Request.Replace(Name, 0);
            AssertRefused(Request, 'InvalidParameterFormat', Name);
            Request.Replace(Name, 1);
            AssertRefused(Request, 'InvalidParameterFormat', Name);
        end;
        Cleanup();
    end;

    /// <summary>The public dispatcher refuses undeclared keys on this write type.</summary>
    [Test]
    procedure Scenario_AC03_UnknownKey()
    var
        Request: JsonObject;
    begin
        Initialize();
        Request := ValidRequest();
        Request.Add('refnd', true);
        AssertRefused(Request, 'UnknownParameter', '');
        Cleanup();
    end;

    /// <summary>Unknown order is refused before the stand-in sees a call.</summary>
    [Test]
    procedure Scenario_AC03_UnknownOrder()
    var
        Request: JsonObject;
    begin
        Initialize();
        Request := ValidRequest();
        Request.Replace('orderId', OrderId() + 1);
        AssertRefused(Request, 'RecordNotFound', 'orderId');
        Cleanup();
    end;

    /// <summary>An imported order whose shop no longer exists is a typed not-found refusal.</summary>
    [Test]
    procedure Scenario_AC03_UnknownShop()
    var
        OrderHeader: Record "Shpfy Order Header";
    begin
        Initialize();
        OrderHeader.Get(OrderId());
        OrderHeader."Shop Code" := 'XNOSHOP27';
        OrderHeader.Modify();
        Commit();
        AssertRefused(ValidRequest(), 'RecordNotFound', 'orderId');
        Cleanup();
    end;

    /// <summary>A disabled shop is refused before the connector.</summary>
    [Test]
    procedure Scenario_AC03_DisabledShop()
    var
        Shop: Record "Shpfy Shop";
    begin
        Initialize();
        Shop.Get(ShopCodeTok);
        Shop.Enabled := false;
        Shop.Modify();
        Commit();
        AssertRefused(ValidRequest(), 'PreconditionFailed', 'orderId');
        Cleanup();
    end;

    /// <summary>An already cancelled imported order is refused before Shopify.</summary>
    [Test]
    procedure Scenario_AC03_AlreadyCancelled()
    var
        OrderHeader: Record "Shpfy Order Header";
    begin
        Initialize();
        OrderHeader.Get(OrderId());
        OrderHeader."Cancelled At" := CurrentDateTime();
        OrderHeader.Modify();
        Commit();
        AssertRefused(ValidRequest(), 'PreconditionFailed', 'orderId');
        Cleanup();
    end;

    /// <summary>The Boolean false API result produces a typed refusal and rolls back local writes.</summary>
    [Test]
    procedure Scenario_AC04_UserErrorsRollback()
    begin
        Initialize();
        VerifyRollback(true, false);
        Cleanup();
    end;

    /// <summary>An exception inside the connector also rolls back local writes.</summary>
    [Test]
    procedure Scenario_AC04_ExceptionRollback()
    begin
        Initialize();
        VerifyRollback(false, true);
        Cleanup();
    end;

    /// <summary>A Read-role caller is refused through the public dispatcher.</summary>
    [Test]
    procedure Scenario_AC01_PermissionRefusal()
    var
        Stub: Codeunit "Shopify Cancel Stub ori";
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
        Assert.AreEqual(0, Stub.CallCount(), 'Unauthorized caller never reaches Shopify.');
        Cleanup();
    end;

    /// <summary>Discovery declares write permission, irreversibility, side effects and non-idempotency.</summary>
    [Test]
    procedure Scenario_AC01_Contract()
    var
        Impl: Codeunit "Order Cancel Impl ori";
        Effect: JsonObject;
        Parameters: JsonArray;
        Notes: Text;
        Overview: Text;
        Examples: JsonArray;
    begin
        Assert.IsTrue(Impl.GetEffect(Effect), 'Effect exists.');
        Assert.AreEqual('write', ReadText(Effect, 'effect'), 'Write classification.');
        Assert.AreEqual('SHOPIFY Full ori', ReadText(Effect, 'permissionSet'), 'Full role only.');
        Assert.AreEqual('false', ReadText(Effect, 'idempotent'), 'Not idempotent.');
        Assert.IsTrue(StrPos(ReadText(Effect, 'changes'), 'Irreversibly') > 0, 'Irreversible effect documented.');
        Assert.IsTrue(StrPos(ReadText(Effect, 'changes'), 'refund') > 0, 'Refund documented.');
        Assert.IsTrue(StrPos(ReadText(Effect, 'changes'), 'email') > 0, 'Email documented.');
        Assert.IsTrue(Impl.GetParameters(Parameters), 'Parameters exist.');
        Assert.AreEqual(6, Parameters.Count(), 'All six parameters declared.');
        Assert.IsTrue(Impl.GetNotes(Notes), 'Notes exist.');
        Assert.IsTrue(StrPos(Notes, 'not cancelled') > 0, 'BC document limit documented.');
        Assert.IsTrue(Impl.GetOverview(Overview), 'Overview exists.');
        Assert.IsTrue(Impl.GetExamples(Examples), 'Examples exist.');
    end;

    local procedure AssertRefused(Request: JsonObject; ExpectedCode: Text; ExpectedParameter: Text)
    var
        Stub: Codeunit "Shopify Cancel Stub ori";
        Response: JsonObject;
    begin
        BindSubscription(Stub);
        Response := Execute(Request);
        UnbindSubscription(Stub);
        Assert.AreEqual(ExpectedCode, ReadText(Response, 'code'), ReadText(Response, 'error'));
        if ExpectedParameter <> '' then
            Assert.AreEqual(ExpectedParameter, ReadText(Response, 'parameter'), 'Typed parameter.');
        Assert.AreEqual(0, Stub.CallCount(), 'Refusal precedes any connector call.');
    end;

    local procedure VerifyRollback(Refuse: Boolean; ThrowError: Boolean)
    var
        OrderHeader: Record "Shpfy Order Header";
        Stub: Codeunit "Shopify Cancel Stub ori";
        Response: JsonObject;
    begin
        Stub.Configure(OrderId(), ShopCodeTok, "Shpfy Cancel Reason"::Customer, false, false, false, Refuse, ThrowError);
        BindSubscription(Stub);
        Response := Execute(ValidRequest());
        UnbindSubscription(Stub);
        Assert.AreEqual('BusinessCentralError', ReadText(Response, 'code'), ReadText(Response, 'error'));
        Assert.IsTrue(StrPos(ReadText(Response, 'nextStep'), '30115') > 0, 'Names connector log table.');
        OrderHeader.Get(OrderId());
        Assert.AreEqual(0DT, OrderHeader."Cancelled At", 'Connector local write rolled back.');
        Assert.AreEqual('XCANCEL27', OrderHeader."Sales Order No.", 'Sales document link preserved.');
    end;

    local procedure Initialize()
    var
        Shop: Record "Shpfy Shop";
        OrderHeader: Record "Shpfy Order Header";
        SalesHeader: Record "Sales Header";
    begin
        Cleanup();
        Shop.Init();
        Shop.Code := ShopCodeTok;
        Shop.Insert();
        Shop.Enabled := true;
        Shop."Logging Mode" := Shop."Logging Mode"::Disabled;
        Shop.Modify();
        OrderHeader.Init();
        OrderHeader."Shopify Order Id" := OrderId();
        OrderHeader."Shop Code" := ShopCodeTok;
        OrderHeader."Sales Order No." := 'XCANCEL27';
        OrderHeader.Insert();
        SalesHeader.Init();
        SalesHeader."Document Type" := SalesHeader."Document Type"::Order;
        SalesHeader."No." := 'XCANCEL27';
        SalesHeader.Insert();
        Commit();
    end;

    local procedure Cleanup()
    var
        Shop: Record "Shpfy Shop";
        OrderHeader: Record "Shpfy Order Header";
        SalesHeader: Record "Sales Header";
    begin
        if OrderHeader.Get(OrderId()) then
            OrderHeader.Delete();
        if SalesHeader.Get(SalesHeader."Document Type"::Order, 'XCANCEL27') then
            SalesHeader.Delete();
        if Shop.Get(ShopCodeTok) then
            Shop.Delete();
        Commit();
    end;

    local procedure OrderId() Value: BigInteger
    begin
        Evaluate(Value, OrderIdTok, 9);
    end;

    local procedure ValidRequest() Request: JsonObject
    begin
        Request.Add('orderId', OrderId());
        Request.Add('reason', 'Customer');
        Request.Add('notifyCustomer', false);
        Request.Add('refund', false);
        Request.Add('restock', false);
        Request.Add('expectedCount', 1);
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
        Dispatcher.Execute("Message Type ori"::"Shopify.Order.Cancel", MessageVersion, '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType);
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
