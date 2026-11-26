namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.History;
using Origo.Bifrost;
using Origo.Bifrost.Shopify;
using System.TestLibraries.Utilities;

/// <summary>Issue #31: mock-only dispatcher tests for invoice exports, validation, rollback and idempotency.</summary>
codeunit 97507 "Shopify Issue 31 Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Issue #31: AC02HappyPathAndRepeat.</summary>
    [Test]
    procedure AC02HappyPathAndRepeat()
    var
        Response: JsonObject;
    begin
        Seed();
        Response := ExecuteRaw('{"shopCode":"BIFT31","invoiceNos":["BIFT31-A"],"expectedCount":1}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), ResponseText(Response));
        Assert.AreEqual('1', ReadText(Response, 'exported'), 'One exported.');
        AssertOutcome(Response, 0, 'exported', 31001);
        Response := ExecuteRaw('{"shopCode":"BIFT31","invoiceNos":["BIFT31-A"],"expectedCount":1}');
        Assert.AreEqual('0', ReadText(Response, 'exported'), 'Repeat does not export twice.');
        AssertOutcome(Response, 0, 'skipped', 31001);
        Cleanup();
    end;

    /// <summary>Issue #31: AC04NonExportableAndFailureContinue.</summary>
    [Test]
    procedure AC04NonExportableAndFailureContinue()
    var
        Response: JsonObject;
    begin
        Seed();
        Response := ExecuteRaw('{"shopCode":"BIFT31","invoiceNos":["BIFT31-FAIL","BIFT31-BLOCK","BIFT31-A","BIFT31-NEG","BIFT31-ZERO"],"expectedCount":5}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), ResponseText(Response));
        Assert.AreEqual('1', ReadText(Response, 'exported'), 'Good invoice after failures exports.');
        Assert.AreEqual('3', ReadText(Response, 'failed'), 'Raised error, negative ID and no-result failures.');
        Assert.AreEqual('1', ReadText(Response, 'notExportable'), 'Not exportable count.');
        AssertOutcome(Response, 0, 'failed', 0);
        AssertOutcome(Response, 1, 'notExportable', -2);
        AssertOutcome(Response, 2, 'exported', 31001);
        Assert.IsTrue(ResponseText(Response).Contains('Mock connector refused'), 'Connector refusal text is preserved.');
        Assert.IsTrue(ResponseText(Response).Contains('Mock: quantity'), 'Connector skipped reason is preserved.');
        Response := ExecuteRaw('{"shopCode":"BIFT31","invoiceNos":["BIFT31-BLOCK","BIFT31-NEG"],"expectedCount":2}');
        AssertOutcome(Response, 0, 'notExportable', -2);
        AssertOutcome(Response, 1, 'failed', -1);
        Cleanup();
    end;

    /// <summary>Issue #31: AC03MissingShop.</summary>
    [Test]
    procedure AC03MissingShop()
    var
        Response: JsonObject;
    begin
        Seed();
        Response := ExecuteRaw('{"invoiceNos":["BIFT31-A"],"expectedCount":1}');
        Assert.AreEqual('MissingParameter', ReadText(Response, 'code'), ResponseText(Response));
        AssertUnchanged();
        Cleanup();
    end;

    /// <summary>Issue #31: AC03MissingInvoices.</summary>
    [Test]
    procedure AC03MissingInvoices()
    var
        Response: JsonObject;
    begin
        Seed();
        Response := ExecuteRaw('{"shopCode":"BIFT31","expectedCount":1}');
        Assert.AreEqual('MissingParameter', ReadText(Response, 'code'), ResponseText(Response));
        AssertUnchanged();
        Cleanup();
    end;

    /// <summary>Issue #31: AC03MissingExpectedCount.</summary>
    [Test]
    procedure AC03MissingExpectedCount()
    var
        Response: JsonObject;
    begin
        Seed();
        Response := ExecuteRaw('{"shopCode":"BIFT31","invoiceNos":["BIFT31-A"]}');
        Assert.AreEqual('MissingParameter', ReadText(Response, 'code'), ResponseText(Response));
        AssertUnchanged();
        Cleanup();
    end;

    /// <summary>Issue #31: AC03EmptyList.</summary>
    [Test]
    procedure AC03EmptyList()
    var
        Response: JsonObject;
    begin
        Seed();
        Response := ExecuteRaw('{"shopCode":"BIFT31","invoiceNos":[],"expectedCount":0}');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), ResponseText(Response));
        AssertUnchanged();
        Cleanup();
    end;

    /// <summary>Issue #31: AC03ExpectedCountMismatch.</summary>
    [Test]
    procedure AC03ExpectedCountMismatch()
    var
        Response: JsonObject;
    begin
        Seed();
        Response := ExecuteRaw('{"shopCode":"BIFT31","invoiceNos":["BIFT31-A"],"expectedCount":2}');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), ResponseText(Response));
        AssertUnchanged();
        Cleanup();
    end;

    /// <summary>Issue #31: AC03FractionalCount.</summary>
    [Test]
    procedure AC03FractionalCount()
    var
        Response: JsonObject;
    begin
        Seed();
        Response := ExecuteRaw('{"shopCode":"BIFT31","invoiceNos":["BIFT31-A"],"expectedCount":1.5}');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), ResponseText(Response));
        AssertUnchanged();
        Cleanup();
    end;

    /// <summary>Issue #31: AC03StringCount.</summary>
    [Test]
    procedure AC03StringCount()
    var
        Response: JsonObject;
    begin
        Seed();
        Response := ExecuteRaw('{"shopCode":"BIFT31","invoiceNos":["BIFT31-A"],"expectedCount":"1"}');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), ResponseText(Response));
        AssertUnchanged();
        Cleanup();
    end;

    /// <summary>Issue #31: AC03NullCount.</summary>
    [Test]
    procedure AC03NullCount()
    var
        Response: JsonObject;
    begin
        Seed();
        Response := ExecuteRaw('{"shopCode":"BIFT31","invoiceNos":["BIFT31-A"],"expectedCount":null}');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), ResponseText(Response));
        AssertUnchanged();
        Cleanup();
    end;

    /// <summary>Issue #31: AC03WrongListType.</summary>
    [Test]
    procedure AC03WrongListType()
    var
        Response: JsonObject;
    begin
        Seed();
        Response := ExecuteRaw('{"shopCode":"BIFT31","invoiceNos":"BIFT31-A","expectedCount":1}');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), ResponseText(Response));
        AssertUnchanged();
        Cleanup();
    end;

    /// <summary>Issue #31: AC03NullInvoice.</summary>
    [Test]
    procedure AC03NullInvoice()
    var
        Response: JsonObject;
    begin
        Seed();
        Response := ExecuteRaw('{"shopCode":"BIFT31","invoiceNos":[null],"expectedCount":1}');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), ResponseText(Response));
        AssertUnchanged();
        Cleanup();
    end;

    /// <summary>Issue #31: AC03NumberInvoice.</summary>
    [Test]
    procedure AC03NumberInvoice()
    var
        Response: JsonObject;
    begin
        Seed();
        Response := ExecuteRaw('{"shopCode":"BIFT31","invoiceNos":[123],"expectedCount":1}');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), ResponseText(Response));
        AssertUnchanged();
        Cleanup();
    end;

    /// <summary>Issue #31: AC03EmptyInvoice.</summary>
    [Test]
    procedure AC03EmptyInvoice()
    var
        Response: JsonObject;
    begin
        Seed();
        Response := ExecuteRaw('{"shopCode":"BIFT31","invoiceNos":[" "],"expectedCount":1}');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), ResponseText(Response));
        AssertUnchanged();
        Cleanup();
    end;

    /// <summary>Issue #31: AC03LongInvoice.</summary>
    [Test]
    procedure AC03LongInvoice()
    var
        Response: JsonObject;
    begin
        Seed();
        Response := ExecuteRaw('{"shopCode":"BIFT31","invoiceNos":["123456789012345678901"],"expectedCount":1}');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), ResponseText(Response));
        AssertUnchanged();
        Cleanup();
    end;

    /// <summary>Issue #31: AC03DuplicateInvoice.</summary>
    [Test]
    procedure AC03DuplicateInvoice()
    var
        Response: JsonObject;
    begin
        Seed();
        Response := ExecuteRaw('{"shopCode":"BIFT31","invoiceNos":["BIFT31-A","bift31-a"],"expectedCount":2}');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), ResponseText(Response));
        AssertUnchanged();
        Cleanup();
    end;

    /// <summary>Issue #31: AC03UnknownShop.</summary>
    [Test]
    procedure AC03UnknownShop()
    var
        Response: JsonObject;
    begin
        Seed();
        Response := ExecuteRaw('{"shopCode":"BIFT31-UNKNOWN","invoiceNos":["BIFT31-A"],"expectedCount":1}');
        Assert.AreEqual('RecordNotFound', ReadText(Response, 'code'), ResponseText(Response));
        AssertUnchanged();
        Cleanup();
    end;

    /// <summary>Issue #31: AC03UnknownInvoiceAfterValid.</summary>
    [Test]
    procedure AC03UnknownInvoiceAfterValid()
    var
        Response: JsonObject;
    begin
        Seed();
        Response := ExecuteRaw('{"shopCode":"BIFT31","invoiceNos":["BIFT31-A","BIFT31-UNKNOWN"],"expectedCount":2}');
        Assert.AreEqual('RecordNotFound', ReadText(Response, 'code'), ResponseText(Response));
        AssertUnchanged();
        Cleanup();
    end;

    /// <summary>Issue #31: AC03MalformedShop.</summary>
    [Test]
    procedure AC03MalformedShop()
    var
        Response: JsonObject;
    begin
        Seed();
        Response := ExecuteRaw('{"shopCode":{},"invoiceNos":["BIFT31-A"],"expectedCount":1}');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), ResponseText(Response));
        AssertUnchanged();
        Cleanup();
    end;

    /// <summary>Issue #31: AC03LongShop.</summary>
    [Test]
    procedure AC03LongShop()
    var
        Response: JsonObject;
    begin
        Seed();
        Response := ExecuteRaw('{"shopCode":"123456789012345678901","invoiceNos":["BIFT31-A"],"expectedCount":1}');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), ResponseText(Response));
        AssertUnchanged();
        Cleanup();
    end;

    /// <summary>Issue #31: AC03EmptyShop.</summary>
    [Test]
    procedure AC03EmptyShop()
    var
        Response: JsonObject;
    begin
        Seed();
        Response := ExecuteRaw('{"shopCode":"","invoiceNos":["BIFT31-A"],"expectedCount":1}');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), ResponseText(Response));
        AssertUnchanged();
        Cleanup();
    end;

    /// <summary>Issue #31: AC03UnknownKey.</summary>
    [Test]
    procedure AC03UnknownKey()
    var
        Response: JsonObject;
    begin
        Seed();
        Response := ExecuteRaw('{"shopCode":"BIFT31","invoiceNos":["BIFT31-A"],"expectedCount":1,"bogus":true}');
        Assert.AreEqual('UnknownParameter', ReadText(Response, 'code'), ResponseText(Response));
        AssertUnchanged();
        Cleanup();
    end;

    /// <summary>Issue #31: AC03DisabledShop.</summary>
    [Test]
    procedure AC03DisabledShop()
    var
        Shop: Record "Shpfy Shop";
        Response: JsonObject;
    begin
        Seed();
        Shop.Get('BIFT31');
        Shop."Enabled" := false;
        Shop.Modify();
        Commit();
        Response := ExecuteRaw('{"shopCode":"BIFT31","invoiceNos":["BIFT31-A"],"expectedCount":1}');
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), ResponseText(Response));
        AssertUnchanged();
        Cleanup();
    end;

    /// <summary>Issue #31: AC03MissingPostedInvoiceSync.</summary>
    [Test]
    procedure AC03MissingPostedInvoiceSync()
    var
        Shop: Record "Shpfy Shop";
        Response: JsonObject;
    begin
        Seed();
        Shop.Get('BIFT31');
        Shop."Posted Invoice Sync" := false;
        Shop.Modify();
        Commit();
        Response := ExecuteRaw('{"shopCode":"BIFT31","invoiceNos":["BIFT31-A"],"expectedCount":1}');
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), ResponseText(Response));
        AssertUnchanged();
        Cleanup();
    end;

    /// <summary>Issue #31: AC03MissingPaymentTerms.</summary>
    [Test]
    procedure AC03MissingPaymentTerms()
    var
        Terms: RecordRef;
        Field: FieldRef;
        Response: JsonObject;
    begin
        Seed();
        Terms.Open(30158);
        Field := Terms.Field(1);
        Field.SetRange('BIFT31');
        Terms.DeleteAll();
        Terms.Close();
        Commit();
        Response := ExecuteRaw('{"shopCode":"BIFT31","invoiceNos":["BIFT31-A"],"expectedCount":1}');
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), ResponseText(Response));
        Assert.IsTrue(ResponseText(Response).Contains('Payment Terms Mapping'), 'Next step names the mapping.');
        AssertUnchanged();
        Cleanup();
    end;

    /// <summary>Issue #31: AC03MissingMappingOnSecondInvoice.</summary>
    [Test]
    procedure AC03MissingMappingOnSecondInvoice()
    var
        Invoice: Record "Sales Invoice Header";
        Terms: RecordRef;
        Field: FieldRef;
        Response: JsonObject;
    begin
        Seed();
        Terms.Open(30158);
        Field := Terms.Field(1);
        Field.SetRange('BIFT31');
        Terms.FindFirst();
        Field := Terms.Field(60);
        Field.Value := false;
        Field := Terms.Field(70);
        Field.Value := 'BIFT31';
        Terms.Modify();
        Terms.Close();
        Invoice.Get('BIFT31-BLOCK');
        Invoice."Payment Terms Code" := 'UNMAPPED';
        Invoice.Modify();
        Commit();
        Response := ExecuteRaw('{"shopCode":"BIFT31","invoiceNos":["BIFT31-A","BIFT31-BLOCK"],"expectedCount":2}');
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), ResponseText(Response));
        AssertUnchanged();
        Cleanup();
    end;

    /// <summary>Issue #31: AC03PermissionRefusal.</summary>
    [Test]
    procedure AC03PermissionRefusal()
    var
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Response: JsonObject;
    begin
        Seed();
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        Response := ExecuteRaw('{"shopCode":"BIFT31","invoiceNos":["BIFT31-A"],"expectedCount":1}');
        LowerPermissions.StopLoggingNAVPermissions();
        Assert.AreEqual('PermissionDenied', ReadText(Response, 'code'), ResponseText(Response));
        AssertUnchanged();
        Cleanup();
    end;

    /// <summary>Issue #31: AC03ListBoundary100And101.</summary>
    [Test]
    procedure AC03ListBoundary100And101()
    var
        Invoice: Record "Sales Invoice Header";
        Request: JsonObject;
        Response: JsonObject;
        Nos: JsonArray;
        Index: Integer;
        RequestText: Text;
    begin
        Seed();
        for Index := 1 to 100 do begin
            Invoice.Init();
            Invoice."No." := CopyStr('BIFT31-N' + Format(Index, 0, 9), 1, 20);
            Invoice.Insert();
            Nos.Add(Invoice."No.");
        end;
        Commit();
        Request.Add('shopCode', 'BIFT31');
        Request.Add('invoiceNos', Nos);
        Request.Add('expectedCount', 100);
        Request.WriteTo(RequestText);
        Response := ExecuteRaw(RequestText);
        Assert.AreEqual('100', ReadText(Response, 'exported'), ResponseText(Response));
        Nos.Add('BIFT31-A');
        Request.Replace('invoiceNos', Nos);
        Request.Replace('expectedCount', 101);
        Request.WriteTo(RequestText);
        Response := ExecuteRaw(RequestText);
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), ResponseText(Response));
        AssertUnchanged();
        Cleanup();
    end;

    /// <summary>Issue #31: AC05IcelandicRefusal.</summary>
    [Test]
    procedure AC05IcelandicRefusal()
    var
        Response: JsonObject;
        PreviousLanguage: Integer;
    begin
        Seed();
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1039);
        Response := ExecuteRaw('{"shopCode":"BIFT31","invoiceNos":["BIFT31-A"],"expectedCount":2}');
        GlobalLanguage(PreviousLanguage);
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), ResponseText(Response));
        Assert.IsTrue((ReadText(Response, 'error') + ReadText(Response, 'message')).Contains('Færibreytan'), 'Icelandic refusal is translated: ' + ResponseText(Response));
        Cleanup();
    end;

    /// <summary>Issue #31: AC01WriteDiscoveryAndReportParameters.</summary>
    [Test]
    procedure AC01WriteDiscoveryAndReportParameters()
    var
        Impl: Codeunit "Invoice Sync Impl ori";
        SyncRun: Codeunit "Invoice Sync Run ori";
        Effect: JsonObject;
        Xml: Text;
    begin
        Seed();
        Assert.IsTrue(Impl.GetEffect(Effect), 'Effect chapter.');
        Assert.AreEqual('write', ReadText(Effect, 'effect'), 'Write discovery.');
        Assert.AreEqual('SHOPIFY Full ori', ReadText(Effect, 'permissionSet'), 'Full permission set.');
        SyncRun.SetInvoice('BIFT31&SHOP', 'BIFT31&A');
        Xml := SyncRun.BuildRequestXml();
        Assert.IsTrue(Xml.Contains('id="30119"'), 'Correct connector report.');
        Assert.IsTrue(Xml.Contains('<Field name="Shop">BIFT31&amp;SHOP</Field>'), 'Shop request option is escaped.');
        Assert.IsTrue(Xml.Contains('BIFT31&amp;A'), 'Exact invoice filter is escaped.');
        Cleanup();
    end;

    /// <summary>Accepts a 20-character invoice number and validates a 20-character shop code as a code.</summary>
    [Test]
    procedure AC03CodeLengthBoundary20()
    var
        Invoice: Record "Sales Invoice Header";
        Response: JsonObject;
    begin
        Seed();
        Invoice.Init();
        Invoice."No." := 'BIFT31-1234567890123';
        Invoice.Insert();
        Commit();
        Response := ExecuteRaw('{"shopCode":"BIFT31","invoiceNos":["BIFT31-1234567890123"],"expectedCount":1}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), ResponseText(Response));
        AssertOutcome(Response, 0, 'exported', 31001);
        Response := ExecuteRaw('{"shopCode":"12345678901234567890","invoiceNos":["BIFT31-A"],"expectedCount":1}');
        Assert.AreEqual('RecordNotFound', ReadText(Response, 'code'), 'A 20-character code passes format validation.');
        Cleanup();
    end;

    /// <summary>A blank unmapped payment term without a primary mapping is refused, matching report preflight.</summary>
    [Test]
    procedure AC03BlankMappingRequiresPrimary()
    var
        Terms: RecordRef;
        Field: FieldRef;
        Response: JsonObject;
    begin
        Seed();
        Terms.Open(30158);
        Field := Terms.Field(1);
        Field.SetRange('BIFT31');
        Terms.FindFirst();
        Field := Terms.Field(60);
        Field.Value := false;
        Terms.Modify();
        Terms.Close();
        Commit();
        Response := ExecuteRaw('{"shopCode":"BIFT31","invoiceNos":["BIFT31-A"],"expectedCount":1}');
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), ResponseText(Response));
        AssertUnchanged();
        Cleanup();
    end;

    local procedure Seed()
    var
        Shop: Record "Shpfy Shop";
        Invoice: Record "Sales Invoice Header";
        Terms: RecordRef;
        Field: FieldRef;
        No: Text;
    begin
        Cleanup();
        Shop.Init();
        Shop.Code := 'BIFT31';
        Shop.Enabled := true;
        Shop."Posted Invoice Sync" := true;
        Shop.Insert();
        Terms.Open(30158);
        Terms.Init();
        Field := Terms.Field(1);
        Field.Value := 'BIFT31';
        Field := Terms.Field(2);
        Field.Value := 31001;
        Field := Terms.Field(60);
        Field.Value := true;
        Terms.Insert();
        Terms.Close();
        foreach No in 'BIFT31-A|BIFT31-FAIL|BIFT31-BLOCK|BIFT31-NEG|BIFT31-ZERO'.Split('|') do begin
            Invoice.Init();
            Invoice."No." := CopyStr(No, 1, 20);
            Invoice.Insert();
        end;
        Commit();
    end;

    local procedure Cleanup()
    var
        Shop: Record "Shpfy Shop";
        Invoice: Record "Sales Invoice Header";
        Ref: RecordRef;
        Field: FieldRef;
    begin
        Ref.Open(30158);
        Field := Ref.Field(1);
        Field.SetRange('BIFT31');
        Ref.DeleteAll();
        Ref.Close();
        Invoice.SetFilter("No.", 'BIFT31-*');
        if Invoice.FindSet() then
            repeat
                Ref.Open(30159);
                Field := Ref.Field(5);
                Field.SetRange(Invoice.RecordId());
                Ref.DeleteAll();
                Ref.Close();
            until Invoice.Next() = 0;
        Invoice.DeleteAll();
        Shop.SetRange(Code, 'BIFT31');
        Shop.DeleteAll();
        Commit();
    end;

    local procedure ExecuteRaw(RequestText: Text) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        Stub: Codeunit "Shpfy Invoice Stub ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseContentType: Text[100];
        Version: Enum "Message Version ori";
        ResponsePayload: Text;
        EmptyTaskId: Guid;
        MessageId: Guid;
        ResponseTime: Duration;
    begin
        BindSubscription(Stub);
        RequestContent.AddText(RequestText);
        // Execute uses the Foundation default language; the public orchestration overload honors this test's LCID.
        Dispatcher.EnqueueAndProcess("Message Type ori"::"Shopify.Invoice.Sync", Version, '', '', 'application/json', RequestContent, EmptyTaskId, GlobalLanguage(), MessageId, ResponseContent, ResponseContentType, ResponseTime);
        UnbindSubscription(Stub);
        ResponseContent.GetSubText(ResponsePayload, 1);
        Response.ReadFrom(ResponsePayload);
    end;

    local procedure ResponseText(Response: JsonObject) Value: Text
    begin
        Response.WriteTo(Value);
    end;

    local procedure ReadText(Obj: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not Obj.Get(PropertyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    local procedure AssertUnchanged()
    var
        Invoice: Record "Sales Invoice Header";
    begin
        Invoice.Get('BIFT31-A');
        Assert.IsTrue(Invoice."Shpfy Order Id" = 0, 'Preflight must not export earlier invoices.');
    end;

    local procedure AssertOutcome(Response: JsonObject; Index: Integer; Outcome: Text; OrderId: BigInteger)
    var
        Token: JsonToken;
        Item: JsonToken;
        Obj: JsonObject;
    begin
        Response.Get('results', Token);
        Token.AsArray().Get(Index, Item);
        Obj := Item.AsObject();
        Assert.AreEqual(Outcome, ReadText(Obj, 'outcome'), 'Invoice outcome.');
        Assert.AreEqual(Format(OrderId, 0, 9), ReadText(Obj, 'shopifyOrderId'), 'Invoice order ID.');
    end;
}
