namespace Origo.Bifrost.Shopify.Test;

using Origo.Bifrost;
using Origo.Bifrost.Shopify;
using System.TestLibraries.Utilities;

/// <summary>Issue 33: public Dispatcher tests with a mock-only connector, including commit rollback.</summary>
codeunit 97517 "Shopify Disputes Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;
    RequiredTestIsolation = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Fixture: Codeunit "Shopify Disputes Fixture ori";
        Stub: Codeunit "Shopify Disputes Stub ori";

    /// <summary>New disputes and refreshed open status remain isolated to the selected shop.</summary>
    [Test]
    procedure Scenario_AC02_ImportRefreshRepeat()
    var
        Response: JsonObject;
    begin
        // Story #33, AC02/AC06 | Time: none | Risk: None
        Fixture.Cleanup();
        Fixture.SeedShop('X33-OK', true);
        Fixture.SeedShop('X33-OTHER', true);
        Stub.InsertDispute(975170001, 'X33-OK', 1);
        Stub.InsertDispute(975170003, 'X33-OTHER', 1);
        Commit();
        Response := Execute('{"shopCode":"X33-OK"}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Import succeeds: ' + ReadText(Response, 'error'));
        Assert.AreEqual('1', ReadText(Response, 'disputesBefore'), 'Count excludes the other shop.');
        Assert.AreEqual('2', ReadText(Response, 'disputesAfter'), 'One new dispute.');
        Assert.AreEqual('2', DisputeValue(975170001, 8), 'Open dispute moved under review.');
        Assert.AreEqual('1', DisputeValue(975170003, 8), 'Other shop unchanged.');
        Response := Execute('{"shopCode":"X33-OK"}');
        Assert.AreEqual('2', ReadText(Response, 'disputesBefore'), 'Repeat starts with two.');
        Assert.AreEqual('2', ReadText(Response, 'disputesAfter'), 'Repeat adds no duplicates.');
        Fixture.Cleanup();
    end;

    /// <summary>A shop without a Payments account succeeds without changing its counts.</summary>
    [Test]
    procedure Scenario_AC04_NoPaymentsAccount()
    var
        Response: JsonObject;
    begin
        // Story #33, AC04/AC06 | Time: none | Risk: None
        Fixture.Cleanup();
        Fixture.SeedShop('X33-NONE', true);
        Response := Execute('{"shopCode":"X33-NONE"}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'No Payments account is not an error.');
        Assert.AreEqual('0', ReadText(Response, 'disputesBefore'), 'Empty before.');
        Assert.AreEqual('0', ReadText(Response, 'disputesAfter'), 'Empty after.');
        Fixture.Cleanup();
    end;

    /// <summary>A refresh, two commits, new row and log entry all roll back on connector failure.</summary>
    [Test]
    procedure Scenario_AC04_CommitThenFailRollsBack()
    var
        Response: JsonObject;
        BeforeRows: Text;
    begin
        // Story #33, AC04/AC06 | Time: fixed dates in mock only | Risk: None
        Fixture.Cleanup();
        Fixture.SeedShop('X33-FAIL', true);
        Stub.InsertDispute(975170001, 'X33-FAIL', 1);
        Commit();
        BeforeRows := Snapshot('X33-FAIL');
        Response := Execute('{"shopCode":"X33-FAIL"}');
        Assert.AreEqual('BusinessCentralError', ReadText(Response, 'code'), 'Connector error is typed.');
        Assert.IsTrue(ReadText(Response, 'error').Contains('X33 mock connector failure after commit.'), 'Original connector text retained.');
        Assert.AreEqual(BeforeRows, Snapshot('X33-FAIL'), 'Every business field of every dispute is exactly as before.');
        Assert.AreEqual(0, MockLogCount(), 'Failed-run Shopify log entries rolled back.');
        Fixture.Cleanup();
    end;

    /// <summary>Absent, malformed and unknown keys are typed refusals before any write.</summary>
    [Test]
    procedure Scenario_AC03_InvalidRequests()
    var
        Response: JsonObject;
        RequestText: Text;
        InvalidValues: List of [Text];
    begin
        // Story #33, AC03 | Time: none | Risk: None
        Fixture.Cleanup();
        Fixture.SeedShop('X33-OK', true);
        Response := Execute('{}');
        Assert.AreEqual('MissingParameter', ReadText(Response, 'code'), 'Missing key.');
        InvalidValues.Add('null');
        InvalidValues.Add('true');
        InvalidValues.Add('33');
        InvalidValues.Add('[]');
        InvalidValues.Add('{}');
        InvalidValues.Add('""');
        InvalidValues.Add('"   "');
        InvalidValues.Add('"123456789012345678901"');
        foreach RequestText in InvalidValues do begin
            Response := Execute('{"shopCode":' + RequestText + '}');
            Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), 'Malformed code: ' + RequestText);
        end;
        Response := Execute('{"shopCode":"X33-OK","bogus":true}');
        Assert.AreEqual('UnknownParameter', ReadText(Response, 'code'), 'Unknown parameter is rejected by the public contract validator.');
        Assert.AreEqual('', Snapshot('X33-OK'), 'Refusals change nothing.');
        Fixture.Cleanup();
    end;

    /// <summary>Unknown and disabled shops fail before the connector event.</summary>
    [Test]
    procedure Scenario_AC03_UnknownDisabledShop()
    var
        Response: JsonObject;
    begin
        // Story #33, AC03 | Time: none | Risk: None
        Fixture.Cleanup();
        Response := Execute('{"shopCode":"X33-MISSING"}');
        Assert.AreEqual('RecordNotFound', ReadText(Response, 'code'), 'Unknown shop.');
        Fixture.SeedShop('X33-DISABLED', false);
        Response := Execute('{"shopCode":"X33-DISABLED"}');
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), 'Disabled shop.');
        Assert.AreEqual('', Snapshot('X33-DISABLED'), 'Disabled shop has no writes.');
        Fixture.Cleanup();
    end;

    /// <summary>Read-only permission refuses this write before any changes.</summary>
    [Test]
    procedure Scenario_AC01_AC03_ReadPermission()
    var
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Response: JsonObject;
    begin
        // Story #33, AC01/AC03 | Time: none | Risk: None
        Fixture.Cleanup();
        Fixture.SeedShop('X33-OK', true);
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        Response := Execute('{"shopCode":"X33-OK"}');
        LowerPermissions.StopLoggingNAVPermissions();
        Assert.AreEqual('PermissionDenied', ReadText(Response, 'code'), 'Read-only caller refused with the permission code.');
        Assert.AreEqual('', Snapshot('X33-OK'), 'No dispute was written.');
        Fixture.Cleanup();
    end;

    /// <summary>Boundary-length and filter-looking shop codes identify exactly one shop.</summary>
    [Test]
    procedure Scenario_AC03_ShopCodeBoundaries()
    var
        Response: JsonObject;
    begin
        // Story #33, AC03 | Time: none | Risk: None
        Fixture.Cleanup();
        Fixture.SeedShop('X33-&|()<>', true);
        Response := Execute('{"shopCode":"X33-&|()<>"}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Filter characters are a literal shop code.');
        Fixture.Cleanup();
        Fixture.SeedShop('X33-1234567890123456', true);
        Response := Execute('{"shopCode":"X33-1234567890123456"}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Maximum length accepted.');
        Fixture.Cleanup();
    end;

    /// <summary>The public contract declares write effect, rollback and no-account semantics.</summary>
    [Test]
    procedure Scenario_AC01_AC05_Contract()
    var
        Impl: Codeunit "Payment Disputes Impl ori";
        Effect: JsonObject;
        Response: JsonObject;
        Notes: Text;
        Serialized: Text;
    begin
        // Story #33, AC01/AC05 | Time: none | Risk: None
        Impl.GetEffect(Effect);
        Assert.AreEqual('write', ReadText(Effect, 'effect'), 'Write classification.');
        Assert.AreEqual('SHOPIFY Full ori', ReadText(Effect, 'permissionSet'), 'Full permission only.');
        Impl.GetNotes(Notes);
        Assert.IsTrue(Notes.Contains('no Shopify Payments account'), 'No-account ambiguity documented.');
        Assert.IsTrue(Notes.Contains('Shopify log entries'), 'Log rollback documented.');
        Impl.GetResponse(Response);
        Response.WriteTo(Serialized);
        Assert.IsTrue(Serialized.Contains('disputesBefore') and Serialized.Contains('disputesAfter'), 'Count fields documented.');
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
        Dispatcher.Execute("Message Type ori"::"Shopify.Payment.SyncDisputes", MessageVersion, '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType);
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

    local procedure DisputeValue(DisputeId: BigInteger; FieldNumber: Integer): Text
    var
        Dispute: RecordRef;
        FieldValue: FieldRef;
        ResultText: Text;
    begin
        Dispute.Open(30155);
        FieldValue := Dispute.Field(1);
        FieldValue.SetRange(DisputeId);
        Assert.IsTrue(Dispute.FindFirst(), 'Expected dispute exists.');
        FieldValue := Dispute.Field(FieldNumber);
        ResultText := Format(FieldValue.Value, 0, 9);
        Dispute.Close();
        exit(ResultText);
    end;

    local procedure Snapshot(ShopCode: Code[20]): Text
    var
        Dispute: RecordRef;
        FieldValue: FieldRef;
        Rows: TextBuilder;
        FieldIndex: Integer;
    begin
        Dispute.Open(30155);
        FieldValue := Dispute.Field(101);
        FieldValue.SetRange(ShopCode);
        if Dispute.FindSet() then
            repeat
                for FieldIndex := 1 to 11 do begin
                    FieldValue := Dispute.Field(FieldIndex);
                    Rows.Append(Format(FieldValue.Value, 0, 9) + '|');
                end;
                Rows.AppendLine();
            until Dispute.Next() = 0;
        Dispute.Close();
        exit(Rows.ToText());
    end;

    local procedure MockLogCount(): Integer
    var
        LogEntry: RecordRef;
        FieldValue: FieldRef;
        EntryCount: Integer;
    begin
        LogEntry.Open(30115);
        FieldValue := LogEntry.Field(9);
        FieldValue.SetRange('X33 rollback log');
        EntryCount := LogEntry.Count();
        LogEntry.Close();
        exit(EntryCount);
    end;
}
