namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Issue 28: Dispatcher tests for confirmation, read-only Shopify guards and whole-run rollback.</summary>
codeunit 97524 "Shopify ForceSync Tests ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Fixture: Codeunit "Shopify ForceSync Fixture ori";
        Stub: Codeunit "Shopify ForceSync Stub ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    /// <summary>RefreshAndRepeat PreserveIdempotency.</summary>
    [Test]
    procedure Scenario_AC02_RefreshAndRepeat_PreserveIdempotency()
    var
        Header: Record "Shpfy Order Header";
        Response: JsonObject;
    begin
        // Story #28, AC02 | Time: neither Today nor WorkDate affects results | Risk: mock connector only.
        Fixture.Seed();
        Response := Dispatch(Request(8928000028L), 1033);
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Refresh: ' + ReadText(Response, 'error'));
        Assert.AreEqual('1', ReadText(Response, 'linesBefore'), 'Original line count.');
        Assert.AreEqual('2', ReadText(Response, 'linesAfter'), 'Refreshed line count.');
        Assert.AreEqual('false', ReadText(Response, 'processed'), 'Unprocessed order.');
        Assert.AreEqual('false', ReadText(Response, 'hasOrderStateError'), 'No conflict.');
        Header.Get(8928000028L);
        Assert.AreEqual('XREFRESHED', Header."Shopify Order No.", 'Header refreshed.');
        Response := Dispatch(Request(8928000028L), 1039);
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Repeat succeeds.');
        Assert.AreEqual('2', ReadText(Response, 'linesBefore'), 'Repeat starts with two lines.');
        Assert.AreEqual('2', ReadText(Response, 'linesAfter'), 'No duplicate line.');
        Fixture.Cleanup();
    end;

    /// <summary>ProcessedOrder FlagsConflictWithoutChangingDocument.</summary>
    [Test]
    procedure Scenario_AC04_ProcessedOrder_FlagsConflictWithoutChangingDocument()
    var
        Sales: Record "Sales Header";
        SalesLine: Record "Sales Line";
        RecRef: RecordRef;
        BeforeHeader: Text;
        BeforeLine: Text;
        Response: JsonObject;
    begin
        // Story #28, AC04 | Time: neither Today nor WorkDate affects results | Risk: mock connector only.
        Fixture.Seed();
        Sales.Get(Sales."Document Type"::Order, 'XFS28DOC');
        RecRef.GetTable(Sales);
        BeforeHeader := Snapshot(RecRef);
        SalesLine.Get(SalesLine."Document Type"::Order, 'XFS28DOC', 10000);
        RecRef.GetTable(SalesLine);
        BeforeLine := Snapshot(RecRef);
        Response := Dispatch(Request(8928000029L), 1033);
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Processed order refresh.');
        Assert.AreEqual('true', ReadText(Response, 'processed'), 'Processed.');
        Assert.AreEqual('true', ReadText(Response, 'hasOrderStateError'), 'Changed processed order flagged.');
        Sales.Get(Sales."Document Type"::Order, 'XFS28DOC');
        RecRef.GetTable(Sales);
        Assert.AreEqual(BeforeHeader, Snapshot(RecRef), 'Every normal sales header field unchanged.');
        SalesLine.Get(SalesLine."Document Type"::Order, 'XFS28DOC', 10000);
        RecRef.GetTable(SalesLine);
        Assert.AreEqual(BeforeLine, Snapshot(RecRef), 'Every normal sales line field unchanged.');
        Fixture.Cleanup();
    end;

    /// <summary>ExplicitCommitThenFailure RollsBackAllRowsAndLog.</summary>
    [Test]
    procedure Scenario_AC04_ExplicitCommitThenFailure_RollsBackAllRowsAndLog()
    begin
        // Story #28, AC04 | Time: neither Today nor WorkDate affects results | Risk: mock connector only.
        AssertRollback(8928000030L);
    end;

    /// <summary>FailureBeforeCommit RollsBackAllRowsAndLog.</summary>
    [Test]
    procedure Scenario_AC04_FailureBeforeCommit_RollsBackAllRowsAndLog()
    begin
        // Story #28, AC04 | Time: neither Today nor WorkDate affects results | Risk: mock connector only.
        AssertRollback(8928000038L);
    end;

    /// <summary>MissingOrder Refused.</summary>
    [Test]
    procedure Scenario_AC03_MissingOrder_Refused()
    begin
        // Story #28, AC03 | Time: neither Today nor WorkDate affects results | Risk: mock connector only.
        Refusal('{"expectedCount":1}', 'MissingParameter', '');
    end;

    /// <summary>MissingConfirmation Refused.</summary>
    [Test]
    procedure Scenario_AC03_MissingConfirmation_Refused()
    begin
        // Story #28, AC03 | Time: neither Today nor WorkDate affects results | Risk: mock connector only.
        Refusal('{"orderId":8928000028}', 'MissingParameter', '');
    end;

    /// <summary>UnknownOrder ImportSuggested.</summary>
    [Test]
    procedure Scenario_AC03_UnknownOrder_ImportSuggested()
    begin
        // Story #28, AC03 | Time: neither Today nor WorkDate affects results | Risk: mock connector only.
        Refusal('{"orderId":1,"expectedCount":1}', 'RecordNotFound', '');
    end;

    /// <summary>UnexpectedParameter Refused.</summary>
    [Test]
    procedure Scenario_AC03_UnexpectedParameter_Refused()
    begin
        // Story #28, AC03 | Time: neither Today nor WorkDate affects results | Risk: mock connector only.
        Refusal('{"orderId":8928000028,"expectedCount":1,"bogus":true}', 'UnknownParameter', '');
    end;

    /// <summary>UnknownShop Refused.</summary>
    [Test]
    procedure Scenario_AC03_UnknownShop_Refused()
    begin
        // Story #28, AC03 | Time: neither Today nor WorkDate affects results | Risk: mock connector only.
        Refusal(Request(8928000035L), 'RecordNotFound', 'Shopify Shop Card');
    end;

    /// <summary>DisabledShop Refused.</summary>
    [Test]
    procedure Scenario_AC03_DisabledShop_Refused()
    begin
        // Story #28, AC03 | Time: neither Today nor WorkDate affects results | Risk: mock connector only.
        Refusal(Request(8928000034L), 'PreconditionFailed', 'Shopify Shop Card');
    end;

    /// <summary>ArchiveLinkedOrder Refused.</summary>
    [Test]
    procedure Scenario_AC03_ArchiveLinkedOrder_Refused()
    begin
        // Story #28, AC03 | Time: neither Today nor WorkDate affects results | Risk: mock connector only.
        Refusal(Request(8928000031L), 'PreconditionFailed', 'Archive Processed Orders');
    end;

    /// <summary>ArchiveLinkedInvoice Refused.</summary>
    [Test]
    procedure Scenario_AC03_ArchiveLinkedInvoice_Refused()
    begin
        // Story #28, AC03 | Time: neither Today nor WorkDate affects results | Risk: mock connector only.
        Refusal(Request(8928000032L), 'PreconditionFailed', 'Archive Processed Orders');
    end;

    /// <summary>OutgoingUnregisteredService Refused.</summary>
    [Test]
    procedure Scenario_AC03_OutgoingUnregisteredService_Refused()
    begin
        // Story #28, AC03 | Time: neither Today nor WorkDate affects results | Risk: mock connector only.
        Refusal(Request(8928000033L), 'PreconditionFailed', 'Allow Outgoing Requests');
    end;

    /// <summary>MalformedAndBoundaryIntegers Refused.</summary>
    [Test]
    procedure Scenario_AC03_MalformedAndBoundaryIntegers_Refused()
    var
        Values: List of [Text];
        Value: Text;
    begin
        // Story #28, AC03 | Time: neither Today nor WorkDate affects results | Risk: mock connector only.
        Values.Add('null');
        Values.Add('true');
        Values.Add('[]');
        Values.Add('{}');
        Values.Add('"8928000028"');
        Values.Add('1.5');
        Values.Add('9223372036854775808');
        foreach Value in Values do begin
            Refusal('{"orderId":' + Value + ',"expectedCount":1}', 'InvalidParameterFormat', '');
            Refusal('{"orderId":8928000028,"expectedCount":' + Value + '}', 'InvalidParameterFormat', '');
        end;
        Refusal('{"orderId":0,"expectedCount":1}', 'InvalidParameterFormat', '');
        Refusal('{"orderId":-1,"expectedCount":1}', 'InvalidParameterFormat', '');
        Refusal('{"orderId":9223372036854775807,"expectedCount":1}', 'RecordNotFound', 'Shopify.Order.Import');
    end;

    /// <summary>ConfirmationOtherThanOne Refused.</summary>
    [Test]
    procedure Scenario_AC03_ConfirmationOtherThanOne_Refused()
    begin
        // Story #28, AC03 | Time: neither Today nor WorkDate affects results | Risk: mock connector only.
        Refusal('{"orderId":8928000028,"expectedCount":0}', 'PreconditionFailed', '');
        Refusal('{"orderId":8928000028,"expectedCount":2}', 'PreconditionFailed', '');
        Refusal('{"orderId":8928000028,"expectedCount":-1}', 'PreconditionFailed', '');
    end;

    /// <summary>ArchivingWithoutLinkedDocument Allowed.</summary>
    [Test]
    procedure Scenario_AC02_ArchivingWithoutLinkedDocument_Allowed()
    var
        Response: JsonObject;
    begin
        // Story #28, AC02 | Time: neither Today nor WorkDate affects results | Risk: mock connector only.
        Fixture.Seed();
        Response := Dispatch(Request(8928000036L), 1033);
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Safe configuration succeeds: ' + ReadText(Response, 'error'));
        Fixture.Cleanup();
    end;

    /// <summary>OutgoingWithRegisteredService Allowed.</summary>
    [Test]
    procedure Scenario_AC02_OutgoingWithRegisteredService_Allowed()
    var
        Response: JsonObject;
    begin
        // Story #28, AC02 | Time: neither Today nor WorkDate affects results | Risk: mock connector only.
        Fixture.Seed();
        Response := Dispatch(Request(8928000037L), 1033);
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Safe configuration succeeds: ' + ReadText(Response, 'error'));
        Fixture.Cleanup();
    end;

    /// <summary>DocumentLinkOnly ReportsProcessed.</summary>
    [Test]
    procedure Scenario_AC02_DocumentLinkOnly_ReportsProcessed()
    var
        Response: JsonObject;
    begin
        // Story #28, AC02 | Time: neither Today nor WorkDate affects results | Risk: mock connector only.
        Fixture.Seed();
        Response := Dispatch(Request(8928000039L), 1033);
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Safe configuration succeeds: ' + ReadText(Response, 'error'));
        Assert.AreEqual('true', ReadText(Response, 'processed'), 'Document link is processed.');
        Fixture.Cleanup();
    end;

    /// <summary>ReadRole Refused.</summary>
    [Test]
    procedure Scenario_AC01_ReadRole_Refused()
    var
        Response: JsonObject;
    begin
        // Story #28, AC01 | Time: neither Today nor WorkDate affects results | Risk: mock connector only.
        Fixture.Seed();
        Stub.ResetCalls();
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        Response := Dispatch(Request(8928000028L), 1033);
        LowerPermissions.StopLoggingNAVPermissions();
        Assert.AreEqual('PermissionDenied', ReadText(Response, 'code'), 'Read role cannot execute write.');
        Assert.AreEqual(0, Stub.GetCalls(), 'Refused before connector.');
        Fixture.Cleanup();
    end;

    /// <summary>BilingualRefusals Translated.</summary>
    [Test]
    procedure Scenario_AC05_BilingualRefusals_Translated()
    var
        English: JsonObject;
        Icelandic: JsonObject;
    begin
        // Story #28, AC05 | Time: neither Today nor WorkDate affects results | Risk: mock connector only.
        Fixture.Seed();
        English := Dispatch('{}', 1033);
        Icelandic := Dispatch('{}', 1039);
        Assert.AreEqual('MissingParameter', ReadText(English, 'code'), 'English code.');
        Assert.AreEqual('MissingParameter', ReadText(Icelandic, 'code'), 'Icelandic code.');
        Assert.AreNotEqual(ReadText(English, 'error'), ReadText(Icelandic, 'error'), 'Refusal translated.');
        Assert.AreNotEqual(ReadText(English, 'nextStep'), ReadText(Icelandic, 'nextStep'), 'Next step translated.');
        Fixture.Cleanup();
    end;

    local procedure AssertRollback(OrderId: BigInteger)
    var
        Header: Record "Shpfy Order Header";
        Line: Record "Shpfy Order Line";
        Attribute: Record "Shpfy Order Attribute";
        Log: RecordRef;
        RecRef: RecordRef;
        BeforeHeader: Text;
        BeforeLine: Text;
        BeforeAttribute: Text;
        Response: JsonObject;
    begin
        Fixture.Seed();
        Header.Get(OrderId);
        RecRef.GetTable(Header);
        BeforeHeader := Snapshot(RecRef);
        Line.Get(OrderId, 1);
        RecRef.GetTable(Line);
        BeforeLine := Snapshot(RecRef);
        Attribute.Get(OrderId, 'XFS28');
        RecRef.GetTable(Attribute);
        BeforeAttribute := Snapshot(RecRef);
        Response := Dispatch(Request(OrderId), 1033);
        Assert.AreEqual('BusinessCentralError', ReadText(Response, 'code'), 'Typed connector error: ' + ReadText(Response, 'error'));
        Assert.IsTrue(ReadText(Response, 'error').Contains('XFS28 mock connector failure'), 'Connector text retained.');
        Header.Get(OrderId);
        RecRef.GetTable(Header);
        Assert.AreEqual(BeforeHeader, Snapshot(RecRef), 'All normal header fields rolled back.');
        Line.Get(OrderId, 1);
        RecRef.GetTable(Line);
        Assert.AreEqual(BeforeLine, Snapshot(RecRef), 'All original line fields rolled back.');
        Line.SetRange("Shopify Order Id", OrderId);
        Assert.AreEqual(1, Line.Count(), 'Inserted line rolled back.');
        Attribute.Get(OrderId, 'XFS28');
        RecRef.GetTable(Attribute);
        Assert.AreEqual(BeforeAttribute, Snapshot(RecRef), 'Related attribute rolled back.');
        Log.Open(30115);
        Log.Field(1).SetRange(928000000 + (OrderId - 8928000028L));
        Assert.IsTrue(Log.IsEmpty(), 'Failed-run Shopify log rolled back.');
        Fixture.Cleanup();
    end;

    local procedure Refusal(RequestText: Text; Code: Text; NextStep: Text)
    var
        Header: Record "Shpfy Order Header";
        Line: Record "Shpfy Order Line";
        Response: JsonObject;
    begin
        Fixture.Seed();
        Stub.ResetCalls();
        Response := Dispatch(RequestText, 1033);
        Assert.AreEqual(Code, ReadText(Response, 'code'), 'Typed refusal: ' + ReadText(Response, 'error'));
        if NextStep <> '' then
            Assert.IsTrue(ReadText(Response, 'nextStep').Contains(NextStep), 'Actionable next step.');
        Assert.AreEqual(0, Stub.GetCalls(), 'Connector never called on refusal.');
        Header.Get(8928000028L);
        Assert.AreEqual('XORIGINAL', Header."Shopify Order No.", 'No header change.');
        Line.SetRange("Shopify Order Id", 8928000028L);
        Assert.AreEqual(1, Line.Count(), 'No line change.');
        Fixture.Cleanup();
    end;

    local procedure Snapshot(RecRef: RecordRef) Result: Text
    var
        Field: FieldRef;
        Fields: JsonObject;
        Index: Integer;
    begin
        for Index := 1 to RecRef.FieldCount do begin
            Field := RecRef.FieldIndex(Index);
            if (Field.Class = FieldClass::Normal) and (Field.Type <> FieldType::Blob) then
                Fields.Add(Format(Field.Number, 0, 9), Format(Field.Value, 0, 9));
        end;
        Fields.WriteTo(Result);
    end;

    local procedure Request(OrderId: BigInteger): Text
    begin
        exit('{"orderId":' + Format(OrderId, 0, 9) + ',"expectedCount":1}');
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
        Dispatcher.EnqueueAndProcess("Message Type ori"::"Shopify.Order.ForceSync", Version, '', '', 'application/json', RequestContent, EmptyTaskId, LanguageId, MessageId, ResponseContent, ContentType, ResponseTime);
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
