namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Integration.Shopify;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Issue #34: public dispatcher coverage of mock-only payment suggestions and atomic refusals.</summary>
codeunit 97513 "Shpfy Suggest Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Fixture: Codeunit "Shpfy Suggest Fixture ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    /// <summary>AC03_MissingTemplate: typed refusal before any journal change.</summary>
    [Test]
    procedure AC03_MissingTemplate()
    begin
        AssertRefusal('{}', 'MissingParameter', 'journalTemplateName');
    end;

    /// <summary>AC03_MissingBatch: typed refusal before any journal change.</summary>
    [Test]
    procedure AC03_MissingBatch()
    begin
        AssertRefusal('{"journalTemplateName":"BIFT34"}', 'MissingParameter', 'journalBatchName');
    end;

    /// <summary>AC03_MissingPostingDate: typed refusal before any journal change.</summary>
    [Test]
    procedure AC03_MissingPostingDate()
    begin
        AssertRefusal('{"journalTemplateName":"BIFT34","journalBatchName":"DEFAULT"}', 'MissingParameter', 'postingDate');
    end;

    /// <summary>AC03_MalformedPostingDate: typed refusal before any journal change.</summary>
    [Test]
    procedure AC03_MalformedPostingDate()
    begin
        AssertRefusal('{"journalTemplateName":"BIFT34","journalBatchName":"DEFAULT","postingDate":"26/11/2026","shopCode":"BIFT34","gateway":"CARD","expectedCount":2}', 'InvalidParameterFormat', 'postingDate');
    end;

    /// <summary>AC03_UnknownParameter: typed refusal before any journal change.</summary>
    [Test]
    procedure AC03_UnknownParameter()
    begin
        AssertRefusal('{"journalTemplateName":"BIFT34","journalBatchName":"DEFAULT","postingDate":"2026-11-26","shopCode":"BIFT34","gateway":"CARD","expectedCount":2,"bogus":true}', 'UnknownParameter', 'bogus');
    end;

    /// <summary>AC03_NumericTemplate: typed refusal before any journal change.</summary>
    [Test]
    procedure AC03_NumericTemplate()
    begin
        AssertRefusal('{"journalTemplateName":42,"journalBatchName":"DEFAULT","postingDate":"2026-11-26","shopCode":"BIFT34","gateway":"CARD","expectedCount":2}', 'InvalidParameterFormat', 'journalTemplateName');
    end;

    /// <summary>AC03_LongTemplate: typed refusal before any journal change.</summary>
    [Test]
    procedure AC03_LongTemplate()
    begin
        AssertRefusal('{"journalTemplateName":"12345678901","journalBatchName":"DEFAULT","postingDate":"2026-11-26","shopCode":"BIFT34","gateway":"CARD","expectedCount":2}', 'InvalidParameterFormat', 'journalTemplateName');
    end;

    /// <summary>AC03_EmptyBatch: typed refusal before any journal change.</summary>
    [Test]
    procedure AC03_EmptyBatch()
    begin
        AssertRefusal('{"journalTemplateName":"BIFT34","journalBatchName":"","postingDate":"2026-11-26","shopCode":"BIFT34","gateway":"CARD","expectedCount":2}', 'InvalidParameterFormat', 'journalBatchName');
    end;

    /// <summary>AC03_UnknownTemplate: typed refusal before any journal change.</summary>
    [Test]
    procedure AC03_UnknownTemplate()
    begin
        AssertRefusal('{"journalTemplateName":"NO34","journalBatchName":"DEFAULT","postingDate":"2026-11-26","shopCode":"BIFT34","gateway":"CARD","expectedCount":2}', 'RecordNotFound', 'journalTemplateName');
    end;

    /// <summary>AC03_WrongTemplate: typed refusal before any journal change.</summary>
    [Test]
    procedure AC03_WrongTemplate()
    begin
        AssertRefusal('{"journalTemplateName":"BIFT34BAD","journalBatchName":"DEFAULT","postingDate":"2026-11-26","shopCode":"BIFT34","gateway":"CARD","expectedCount":2}', 'PreconditionFailed', 'journalTemplateName');
    end;

    /// <summary>AC03_UnknownBatch: typed refusal before any journal change.</summary>
    [Test]
    procedure AC03_UnknownBatch()
    begin
        AssertRefusal('{"journalTemplateName":"BIFT34","journalBatchName":"NO34","postingDate":"2026-11-26","shopCode":"BIFT34","gateway":"CARD","expectedCount":2}', 'RecordNotFound', 'journalBatchName');
    end;

    /// <summary>AC03_UnknownShop: typed refusal before any journal change.</summary>
    [Test]
    procedure AC03_UnknownShop()
    begin
        AssertRefusal('{"journalTemplateName":"BIFT34","journalBatchName":"DEFAULT","postingDate":"2026-11-26","shopCode":"NO34","gateway":"CARD","expectedCount":2}', 'RecordNotFound', 'shopCode');
    end;

    /// <summary>AC03_DisabledShop: typed refusal before any journal change.</summary>
    [Test]
    procedure AC03_DisabledShop()
    begin
        AssertRefusal('{"journalTemplateName":"BIFT34","journalBatchName":"DEFAULT","postingDate":"2026-11-26","shopCode":"BIFT34OFF","gateway":"CARD","expectedCount":2}', 'PreconditionFailed', 'shopCode');
    end;

    /// <summary>AC03_CountMismatch: typed refusal before any journal change.</summary>
    [Test]
    procedure AC03_CountMismatch()
    begin
        AssertRefusal('{"journalTemplateName":"BIFT34","journalBatchName":"DEFAULT","postingDate":"2026-11-26","shopCode":"BIFT34","gateway":"CARD","expectedCount":3}', 'PreconditionFailed', 'expectedCount');
    end;

    /// <summary>AC03_NegativeCount: typed refusal before any journal change.</summary>
    [Test]
    procedure AC03_NegativeCount()
    begin
        AssertRefusal('{"journalTemplateName":"BIFT34","journalBatchName":"DEFAULT","postingDate":"2026-11-26","shopCode":"BIFT34","gateway":"CARD","expectedCount":-1}', 'InvalidParameterFormat', 'expectedCount');
    end;

    /// <summary>AC03_StringCount: typed refusal before any journal change.</summary>
    [Test]
    procedure AC03_StringCount()
    begin
        AssertRefusal('{"journalTemplateName":"BIFT34","journalBatchName":"DEFAULT","postingDate":"2026-11-26","shopCode":"BIFT34","gateway":"CARD","expectedCount":"2"}', 'InvalidParameterFormat', 'expectedCount');
    end;

    /// <summary>AC03_DecimalCount: typed refusal before any journal change.</summary>
    [Test]
    procedure AC03_DecimalCount()
    begin
        AssertRefusal('{"journalTemplateName":"BIFT34","journalBatchName":"DEFAULT","postingDate":"2026-11-26","shopCode":"BIFT34","gateway":"CARD","expectedCount":1.5}', 'InvalidParameterFormat', 'expectedCount');
    end;

    /// <summary>AC03_StringBoolean: typed refusal before any journal change.</summary>
    [Test]
    procedure AC03_StringBoolean()
    begin
        AssertRefusal('{"journalTemplateName":"BIFT34","journalBatchName":"DEFAULT","postingDate":"2026-11-26","shopCode":"BIFT34","gateway":"CARD","expectedCount":2,"newDocNoPerLine":"true"}', 'InvalidParameterFormat', 'newDocNoPerLine');
    end;

    /// <summary>AC03_InvalidFrom: typed refusal before any journal change.</summary>
    [Test]
    procedure AC03_InvalidFrom()
    begin
        AssertRefusal('{"journalTemplateName":"BIFT34","journalBatchName":"DEFAULT","postingDate":"2026-11-26","shopCode":"BIFT34","gateway":"CARD","expectedCount":2,"createdAtFrom":"bad"}', 'InvalidParameterFormat', 'createdAtFrom');
    end;

    /// <summary>AC03_ReversedDates: typed refusal before any journal change.</summary>
    [Test]
    procedure AC03_ReversedDates()
    begin
        AssertRefusal('{"journalTemplateName":"BIFT34","journalBatchName":"DEFAULT","postingDate":"2026-11-26","shopCode":"BIFT34","gateway":"CARD","expectedCount":2,"createdAtFrom":"2026-11-27T00:00:00Z","createdAtTo":"2026-11-25T00:00:00Z"}', 'InvalidParameterFormat', 'createdAtTo');
    end;

    /// <summary>AC03_InvalidDocumentNo: typed refusal before any journal change.</summary>
    [Test]
    procedure AC03_InvalidDocumentNo()
    begin
        AssertRefusal('{"journalTemplateName":"BIFT34","journalBatchName":"DEFAULT","postingDate":"2026-11-26","shopCode":"BIFT34","gateway":"CARD","expectedCount":2,"startingDocumentNo":"ABC"}', 'InvalidParameterFormat', 'startingDocumentNo');
    end;

    /// <summary>AC04_FailureRollsBack: typed refusal before any journal change.</summary>
    [Test]
    procedure AC04_FailureRollsBack()
    begin
        AssertRefusal('{"journalTemplateName":"BIFT34","journalBatchName":"DEFAULT","postingDate":"2026-11-26","shopCode":"BIFT34","gateway":"FAIL","expectedCount":1}', 'BusinessCentralError', 'connector');
    end;

    /// <summary>AC04_CommitIsRefused: typed refusal before any journal change.</summary>
    [Test]
    procedure AC04_CommitIsRefused()
    begin
        AssertRefusal('{"journalTemplateName":"BIFT34","journalBatchName":"DEFAULT","postingDate":"2026-11-26","shopCode":"BIFT34","gateway":"COMMIT","expectedCount":1}', 'BusinessCentralError', 'connector');
    end;

    /// <summary>AC03: expectedCount is mandatory even for an empty selection.</summary>
    [Test]
    procedure AC03_MissingExpectedCount()
    begin
        AssertRefusal('{"journalTemplateName":"BIFT34","journalBatchName":"DEFAULT","postingDate":"2026-11-26"}', 'MissingParameter', 'expectedCount');
    end;

    /// <summary>AC03: JSON null is not a shop code.</summary>
    [Test]
    procedure AC03_NullShopCode()
    begin
        AssertRefusal('{"journalTemplateName":"BIFT34","journalBatchName":"DEFAULT","postingDate":"2026-11-26","expectedCount":2,"shopCode":null}', 'InvalidParameterFormat', 'shopCode');
    end;

    /// <summary>AC02/AC04: success creates two new lines, skips a used transaction and repeats without duplicates.</summary>
    [Test]
    procedure AC02_HappyPathAndRepeat()
    var
        Lines: Record "Gen. Journal Line";
        Response: JsonObject;
    begin
        Fixture.Seed();
        Response := ExecuteRaw(BaseRequest(2));
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Happy path response: ' + ReadText(Response, 'message'));
        Assert.AreEqual('2', ReadText(Response, 'journalLinesCreated'), 'Created line count.');
        Assert.AreEqual('2', ReadText(Response, 'transactionsConsidered'), 'Used transaction excluded.');
        Lines.SetRange("Shpfy Transaction Id", 3400004);
        Assert.IsTrue(Lines.IsEmpty(), 'Used transaction must not be suggested.');
        Assert.AreEqual(3, LineCount(), 'One existing and two new lines.');
        Response := ExecuteRaw(BaseRequest(0));
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Repeated call with refreshed count.');
        Assert.AreEqual('0', ReadText(Response, 'journalLinesCreated'), 'No duplicate lines.');
        Assert.AreEqual(3, LineCount(), 'Repeat preserves batch size.');
        AssertOriginalLine();
        Fixture.Remove();
    end;

    /// <summary>AC06: exact gateway selects only one transaction.</summary>
    [Test]
    procedure AC06_GatewayFilter()
    begin
        AssertSuccess('"gateway":"OTHER","expectedCount":1', 1);
    end;

    /// <summary>AC06: inclusive timestamp bounds select the boundary transaction.</summary>
    [Test]
    procedure AC06_DateFilter()
    begin
        AssertSuccess('"gateway":"CARD","expectedCount":1,"createdAtFrom":"2026-11-26T12:00:00Z","createdAtTo":"2026-11-26T12:00:00Z"', 1);
    end;

    /// <summary>AC03: zero eligible transactions succeeds without connector execution.</summary>
    [Test]
    procedure AC03_ZeroCountBoundary()
    begin
        AssertSuccess('"gateway":"NONE","expectedCount":0', 0);
    end;

    /// <summary>AC01/AC03: a read-only caller is refused and leaves the batch unchanged.</summary>
    [Test]
    procedure AC01_ReadOnlyPermissionRefusal()
    var
        Response: JsonObject;
    begin
        Fixture.Seed();
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        Response := ExecuteRaw(BaseRequest(2));
        LowerPermissions.StopLoggingNAVPermissions();
        Assert.AreEqual('PermissionDenied', ReadText(Response, 'code'), 'Read-only caller refused.');
        Assert.AreEqual(1, LineCount(), 'No journal write without permission.');
        Fixture.Remove();
    end;

    local procedure AssertSuccess(Extra: Text; Count: Integer)
    var
        Response: JsonObject;
    begin
        Fixture.Seed();
        Response := ExecuteRaw('{"journalTemplateName":"BIFT34","journalBatchName":"DEFAULT","postingDate":"2026-11-26","shopCode":"BIFT34",' + Extra + '}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Filtered success: ' + ReadText(Response, 'message'));
        Assert.AreEqual(Format(Count, 0, 9), ReadText(Response, 'journalLinesCreated'), 'Filtered line count.');
        Assert.AreEqual(Count + 1, LineCount(), 'Actual database rows.');
        AssertOriginalLine();
        Fixture.Remove();
    end;

    local procedure AssertRefusal(Request: Text; Code: Text; Parameter: Text)
    var
        Response: JsonObject;
    begin
        Fixture.Seed();
        Response := ExecuteRaw(Request);
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Refused status: ' + ReadText(Response, 'message'));
        Assert.AreEqual(Code, ReadText(Response, 'code'), 'Typed refusal: ' + ReadText(Response, 'message'));
        Assert.AreEqual(Parameter, ReadText(Response, 'parameter'), 'Refusal parameter.');
        Assert.AreEqual(1, LineCount(), 'Refusal leaves batch unchanged.');
        AssertOriginalLine();
        Fixture.Remove();
    end;

    local procedure AssertOriginalLine()
    var
        Line: Record "Gen. Journal Line";
    begin
        Line.Get('BIFT34', 'DEFAULT', 10000);
        Assert.AreEqual('Existing line remains unchanged', Line.Description, 'Existing description.');
        Assert.AreEqual(17, Line.Amount, 'Existing amount.');
    end;

    local procedure LineCount(): Integer
    var
        Lines: Record "Gen. Journal Line";
    begin
        Lines.SetRange("Journal Template Name", 'BIFT34');
        Lines.SetRange("Journal Batch Name", 'DEFAULT');
        exit(Lines.Count());
    end;

    local procedure BaseRequest(Count: Integer): Text
    begin
        exit('{"journalTemplateName":"BIFT34","journalBatchName":"DEFAULT","postingDate":"2026-11-26","shopCode":"BIFT34","gateway":"CARD","expectedCount":' + Format(Count, 0, 9) + '}');
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
        Dispatcher.Execute("Message Type ori"::"Shopify.Transaction.SuggestPayments", Version, '', '', 'application/json', RequestContent, ResponseContent, ContentType);
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
