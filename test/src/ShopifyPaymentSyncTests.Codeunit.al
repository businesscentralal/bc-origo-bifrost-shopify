namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Origo.Bifrost;
using Origo.Bifrost.Shopify;
using System.TestLibraries.Utilities;

/// <summary>Issue 32: public Dispatcher tests with a mock-only connector, including commit rollback.</summary>
codeunit 97550 "Shpfy Pay Sync Test ori"
{
    Subtype = Test;
    TestPermissions = Disabled;
    RequiredTestIsolation = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Fixture: Codeunit "Shpfy Pay Sync MCP ori";
        Stub: Codeunit "Shpfy Pay Sync Stub ori";

    /// <summary>New payouts and payment transactions stay on the selected shop, and a repeat adds nothing.</summary>
    [Test]
    procedure Scenario_AC02_ImportAndRepeat()
    var
        Response: JsonObject;
        BeforeRepeat: Text;
    begin
        // [GIVEN] An enabled shop with one payout and one payment transaction, and another shop
        // Story #32, AC02/AC06 | Time: none | Risk: None
        Fixture.Cleanup();
        Fixture.SeedShop('X32-OK', true);
        Fixture.SeedShop('X32-OTHER', true);
        Stub.InsertPayout(975320001, 'X32-OK', 1);
        Stub.InsertTransaction(975320011, 'X32-OK', 975320001);
        Stub.InsertPayout(975320003, 'X32-OTHER', 1);
        Stub.InsertTransaction(975320013, 'X32-OTHER', 975320003);
        Commit();

        // [WHEN] The payout import runs, then runs again
        Response := Execute('{"shopCode":"X32-OK"}');

        // [THEN] The selected shop gains one payout and one transaction, and a repeat changes nothing
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Import succeeds.');
        Assert.AreEqual('X32-OK', ReadText(Response, 'shopCode'), 'Shop code returned.');
        Assert.AreEqual('1', ReadText(Response, 'payoutsBefore'), 'Payout count excludes the other shop.');
        Assert.AreEqual('2', ReadText(Response, 'payoutsAfter'), 'One new payout.');
        Assert.AreEqual('1', ReadText(Response, 'paymentTransactionsBefore'), 'Transaction count excludes the other shop.');
        Assert.AreEqual('2', ReadText(Response, 'paymentTransactionsAfter'), 'One new payment transaction.');
        Assert.AreEqual('3', PayoutStatus(975320001), 'Scheduled payout moved to paid.');
        Assert.AreEqual('1', PayoutStatus(975320003), 'Other shop payout unchanged.');
        BeforeRepeat := Snapshot('X32-OK');
        Response := Execute('{"shopCode":"X32-OK"}');
        Assert.AreEqual(BeforeRepeat, Snapshot('X32-OK'), 'Repeat preserves stored rows.');
        Assert.AreEqual('2', ReadText(Response, 'payoutsBefore'), 'Repeat starts with two payouts.');
        Assert.AreEqual('2', ReadText(Response, 'payoutsAfter'), 'Repeat adds no payout.');
        Assert.AreEqual('2', ReadText(Response, 'paymentTransactionsBefore'), 'Repeat starts with two transactions.');
        Assert.AreEqual('2', ReadText(Response, 'paymentTransactionsAfter'), 'Repeat adds no transaction.');
        Fixture.Cleanup();
    end;

    /// <summary>A shop without a Payments account succeeds without changing its counts.</summary>
    [Test]
    procedure Scenario_AC04_NoPaymentsAccount()
    var
        Response: JsonObject;
    begin
        // [GIVEN] An enabled shop with no payout rows
        // Story #32, AC04/AC06 | Time: none | Risk: None
        Fixture.Cleanup();
        Fixture.SeedShop('X32-NONE', true);

        // [WHEN] The import runs and the stand-in adds nothing
        Response := Execute('{"shopCode":"X32-NONE"}');

        // [THEN] The call succeeds and both counts stay at zero
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'No Payments account is not an error.');
        Assert.AreEqual('0', ReadText(Response, 'payoutsBefore'), 'No payouts before.');
        Assert.AreEqual('0', ReadText(Response, 'payoutsAfter'), 'No payouts after.');
        Assert.AreEqual('0', ReadText(Response, 'paymentTransactionsBefore'), 'No transactions before.');
        Assert.AreEqual('0', ReadText(Response, 'paymentTransactionsAfter'), 'No transactions after.');
        Fixture.Cleanup();
    end;

    /// <summary>Rows and a log entry written after Commit roll back when the connector then fails.</summary>
    [Test]
    procedure Scenario_AC04_CommitThenFailRollsBack()
    var
        Response: JsonObject;
        BeforeRows: Text;
    begin
        // [GIVEN] A shop with one payout and one payment transaction
        // Story #32, AC04/AC06 | Time: none | Risk: None
        Fixture.Cleanup();
        Fixture.SeedShop('X32-FAIL', true);
        Stub.InsertPayout(975320001, 'X32-FAIL', 1);
        Stub.InsertTransaction(975320011, 'X32-FAIL', 975320001);
        Commit();
        BeforeRows := Snapshot('X32-FAIL');

        // [WHEN] The stand-in writes, commits and then fails
        Response := Execute('{"shopCode":"X32-FAIL"}');

        // [THEN] The refusal keeps the connector text and the rows are exactly as before
        Assert.AreEqual('BusinessCentralError', ReadText(Response, 'code'), 'Connector error is typed.');
        Assert.IsTrue(ReadText(Response, 'error').Contains('X32 mock connector failure after commit.'), 'Original connector text retained.');
        Assert.AreEqual(BeforeRows, Snapshot('X32-FAIL'), 'Payout and payment transaction rows are exactly as before.');
        Assert.AreEqual(0, MockLogCount(), 'Failed-run Shopify log entries rolled back.');
        Fixture.Cleanup();
    end;

    /// <summary>Absent and malformed keys are typed refusals before any write.</summary>
    [Test]
    procedure Scenario_AC03_InvalidRequests()
    var
        Response: JsonObject;
        RequestText: Text;
        InvalidValues: List of [Text];
    begin
        // [GIVEN] An enabled shop
        // Story #32, AC03 | Time: none | Risk: None
        Fixture.Cleanup();
        Fixture.SeedShop('X32-OK', true);

        // [WHEN] The key is missing, malformed or unknown
        Response := Execute('{}');
        Assert.AreEqual('MissingParameter', ReadText(Response, 'code'), 'Missing key.');
        InvalidValues.Add('null');
        InvalidValues.Add('true');
        InvalidValues.Add('32');
        InvalidValues.Add('[]');
        InvalidValues.Add('{}');
        InvalidValues.Add('""');
        InvalidValues.Add('"   "');
        InvalidValues.Add('"123456789012345678901"');
        foreach RequestText in InvalidValues do begin
            Response := Execute('{"shopCode":' + RequestText + '}');
            Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), 'Malformed code: ' + RequestText);
        end;
        Response := Execute('{"shopCode":"X32-OK","bogus":true}');
        Assert.AreEqual('UnknownParameter', ReadText(Response, 'code'), 'Unknown parameter.');

        // [THEN] Nothing was written
        Assert.AreEqual('', Snapshot('X32-OK'), 'Refusals change nothing.');
        Fixture.Cleanup();
    end;

    /// <summary>Unknown and disabled shops fail before the connector event.</summary>
    [Test]
    procedure Scenario_AC03_UnknownDisabledShop()
    var
        Response: JsonObject;
    begin
        // [GIVEN] A missing shop and a disabled shop
        // Story #32, AC03 | Time: none | Risk: None
        Fixture.Cleanup();

        // [WHEN] Each is requested
        Response := Execute('{"shopCode":"X32-MISSING"}');
        Assert.AreEqual('RecordNotFound', ReadText(Response, 'code'), 'Unknown shop.');
        Fixture.SeedShop('X32-DISABLED', false);
        Response := Execute('{"shopCode":"X32-DISABLED"}');

        // [THEN] The disabled shop is refused and nothing is written
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), 'Disabled shop.');
        Assert.AreEqual('', Snapshot('X32-DISABLED'), 'Disabled shop has no writes.');
        Fixture.Cleanup();
    end;

    /// <summary>Read-only permission refuses this write before any changes.</summary>
    [Test]
    procedure Scenario_AC01_AC03_ReadPermission()
    var
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Response: JsonObject;
    begin
        // [GIVEN] An enabled shop and a caller without SHOPIFY Full ori
        // Story #32, AC01/AC03 | Time: none | Risk: None
        Fixture.Cleanup();
        Fixture.SeedShop('X32-OK', true);
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');

        // [WHEN] The import is requested
        Response := Execute('{"shopCode":"X32-OK"}');
        LowerPermissions.StopLoggingNAVPermissions();

        // [THEN] The caller is refused and nothing is written
        Assert.AreEqual('PermissionDenied', ReadText(Response, 'code'), 'Read-only caller refused.');
        Assert.AreEqual('', Snapshot('X32-OK'), 'No payout was written.');
        Fixture.Cleanup();
    end;

    /// <summary>A shop code of the maximum length, including filter characters, selects that one shop.</summary>
    [Test]
    procedure Scenario_AC03_ShopCodeBoundaries()
    var
        Response: JsonObject;
    begin
        // [GIVEN] Shop codes that look like filters and a 20-character code
        // Story #32, AC03 | Time: none | Risk: None
        Fixture.Cleanup();
        Fixture.SeedShop('X32-&|()<>', true);
        Response := Execute('{"shopCode":"X32-&|()<>"}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Filter characters are a literal shop code.');
        Assert.AreEqual('X32-&|()<>', ReadText(Response, 'shopCode'), 'The same shop is returned.');
        Fixture.Cleanup();
        Fixture.SeedShop('X32-1234567890123456', true);
        Response := Execute('{"shopCode":"X32-1234567890123456"}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Maximum length accepted.');
        Fixture.Cleanup();
    end;

    /// <summary>The public contract declares a write, rollback and the no-account case.</summary>
    [Test]
    procedure Scenario_AC01_AC05_Contract()
    var
        Impl: Codeunit "Payment Sync Impl ori";
        Effect: JsonObject;
        Response: JsonObject;
        Notes: Text;
        Serialized: Text;
    begin
        // Story #32, AC01/AC05 | Time: none | Risk: None
        Impl.GetEffect(Effect);
        Assert.AreEqual('write', ReadText(Effect, 'effect'), 'Write classification.');
        Assert.AreEqual('SHOPIFY Full ori', ReadText(Effect, 'permissionSet'), 'Full permission only.');
        Assert.IsTrue(ReadText(Effect, 'idempotent') = 'true', 'Idempotent.');
        Impl.GetNotes(Notes);
        Assert.IsTrue(Notes.Contains('no Shopify Payments account'), 'No-account ambiguity documented.');
        Assert.IsTrue(Notes.Contains('Shopify log entries'), 'Log rollback documented.');
        Impl.GetResponse(Response);
        Response.WriteTo(Serialized);
        Assert.IsTrue(Serialized.Contains('payoutsBefore') and Serialized.Contains('payoutsAfter'), 'Payout counts documented.');
        Assert.IsTrue(Serialized.Contains('paymentTransactionsBefore') and Serialized.Contains('paymentTransactionsAfter'), 'Transaction counts documented.');
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
        Dispatcher.Execute("Message Type ori"::"Shopify.Payment.Sync", MessageVersion, '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        Response.ReadFrom(ResponseText);
    end;

    local procedure ReadText(Response: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if Response.Get(PropertyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure PayoutStatus(PayoutId: BigInteger): Text
    var
        Payout: Record "Shpfy Payout";
    begin
        Payout.SetLoadFields(Status);
        Payout.Get(PayoutId);
        exit(Format(Payout.Status.AsInteger(), 0, 9));
    end;

    local procedure Snapshot(ShopCode: Code[20]): Text
    var
        Rows: TextBuilder;
    begin
        AppendPayouts(ShopCode, Rows);
        AppendTransactions(ShopCode, Rows);
        exit(Rows.ToText());
    end;

    local procedure AppendPayouts(ShopCode: Code[20]; var Rows: TextBuilder)
    var
        Payout: Record "Shpfy Payout";
    begin
        Payout.SetRange("Shop Code", ShopCode);
        if Payout.FindSet() then
            repeat
                Rows.Append('P|' + Format(Payout.Id, 0, 9) + '|' + Format(Payout.Status.AsInteger(), 0, 9) + '|' + Format(Payout.Date, 0, 9) + '|' + Payout.Currency + '|' + Format(Payout.Amount, 0, 9) + '|' + Payout."Shop Code");
                Rows.AppendLine();
            until Payout.Next() = 0;
    end;

    local procedure AppendTransactions(ShopCode: Code[20]; var Rows: TextBuilder)
    var
        PaymentTransaction: Record "Shpfy Payment Transaction";
    begin
        PaymentTransaction.SetRange("Shop Code", ShopCode);
        if PaymentTransaction.FindSet() then
            repeat
                Rows.Append('T|' + Format(PaymentTransaction.Id, 0, 9) + '|' + Format(PaymentTransaction.Type.AsInteger(), 0, 9) + '|' + Format(PaymentTransaction."Payout Id", 0, 9) + '|' + PaymentTransaction.Currency + '|' + Format(PaymentTransaction.Amount, 0, 9) + '|' + PaymentTransaction."Shop Code");
                Rows.AppendLine();
            until PaymentTransaction.Next() = 0;
    end;

    local procedure MockLogCount(): Integer
    var
        LogEntry: RecordRef;
        FieldValue: FieldRef;
        EntryCount: Integer;
    begin
        LogEntry.Open(30115);
        FieldValue := LogEntry.Field(9);
        FieldValue.SetRange('X32 rollback log');
        EntryCount := LogEntry.Count();
        LogEntry.Close();
        exit(EntryCount);
    end;
}
