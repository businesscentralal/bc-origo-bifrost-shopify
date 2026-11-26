namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Origo.Bifrost;
using Origo.Bifrost.Shopify;
using System.TestLibraries.Utilities;

/// <summary>Issue 26 acceptance through the public dispatcher; all connector execution is mocked.</summary>
codeunit 97530 "Shpfy MarkPaid Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Fixture: Codeunit "Shpfy MarkPaid Fixture ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    /// <summary>AC02/06: the response comes from the order shop, and the local order stays stale.</summary>
    [Test]
    procedure AC02_HappyPath()
    var
        OrderHeader: Record "Shpfy Order Header";
        PaidMarker: Record "Order Paid Marker ori";
        Response: JsonObject;
    begin
        // Fixture assumption: the reserved unpaid order has no credentials and is handled by the stand-in.
        Fixture.A1SeedFixture();
        Response := Execute('{"orderId":975300001,"expectedCount":1}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Success response.');
        Assert.AreEqual('975300001', ReadText(Response, 'orderId'), 'Order id.');
        Assert.AreEqual('X26ON', ReadText(Response, 'shopCode'), 'Shop derived from order.');
        Assert.AreEqual('true', ReadText(Response, 'fullyPaid'), 'Remote paid result.');
        OrderHeader.Get(975300001);
        Assert.IsFalse(OrderHeader."Fully Paid", 'The imported order is not refreshed.');
        Assert.IsTrue(PaidMarker.Get('X26ON', 975300001), 'Successful request remembered.');
        Fixture.A2RemoveFixture();
    end;

    /// <summary>AC03/06: repeated calls are refused even with a stale local unpaid row.</summary>
    [Test]
    procedure AC03_RepeatRefused()
    var
        Response: JsonObject;
    begin
        Fixture.A1SeedFixture();
        Response := Execute('{"orderId":975300001,"expectedCount":1}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Initial write succeeds.');
        Response := Execute('{"orderId":975300001,"expectedCount":1}');
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), 'Repeat is refused.');
        Fixture.A2RemoveFixture();
    end;

    /// <summary>AC03/06: MissingOrder returns MissingParameter without storing a successful write.</summary>
    [Test]
    procedure AC03_MissingOrder()
    begin
        AssertRefusal('{"expectedCount":1}', 'MissingParameter');
    end;

    /// <summary>AC03/06: MissingCount returns MissingParameter without storing a successful write.</summary>
    [Test]
    procedure AC03_MissingCount()
    begin
        AssertRefusal('{"orderId":975300001}', 'MissingParameter');
    end;

    /// <summary>AC03/06: UnknownKey returns UnknownParameter without storing a successful write.</summary>
    [Test]
    procedure AC03_UnknownKey()
    begin
        AssertRefusal('{"orderId":975300001,"expectedCount":1,"extra":true}', 'UnknownParameter');
    end;

    /// <summary>AC03/06: ZeroOrder returns InvalidParameterFormat without storing a successful write.</summary>
    [Test]
    procedure AC03_ZeroOrder()
    begin
        AssertRefusal('{"orderId":0,"expectedCount":1}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03/06: NegativeOrder returns InvalidParameterFormat without storing a successful write.</summary>
    [Test]
    procedure AC03_NegativeOrder()
    begin
        AssertRefusal('{"orderId":-1,"expectedCount":1}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03/06: StringOrder returns InvalidParameterFormat without storing a successful write.</summary>
    [Test]
    procedure AC03_StringOrder()
    begin
        AssertRefusal('{"orderId":"975300001","expectedCount":1}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03/06: DecimalOrder returns InvalidParameterFormat without storing a successful write.</summary>
    [Test]
    procedure AC03_DecimalOrder()
    begin
        AssertRefusal('{"orderId":1.5,"expectedCount":1}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03/06: NullOrder returns InvalidParameterFormat without storing a successful write.</summary>
    [Test]
    procedure AC03_NullOrder()
    begin
        AssertRefusal('{"orderId":null,"expectedCount":1}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03/06: ArrayOrder returns InvalidParameterFormat without storing a successful write.</summary>
    [Test]
    procedure AC03_ArrayOrder()
    begin
        AssertRefusal('{"orderId":[],"expectedCount":1}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03/06: ObjectOrder returns InvalidParameterFormat without storing a successful write.</summary>
    [Test]
    procedure AC03_ObjectOrder()
    begin
        AssertRefusal('{"orderId":{},"expectedCount":1}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03/06: BooleanOrder returns InvalidParameterFormat without storing a successful write.</summary>
    [Test]
    procedure AC03_BooleanOrder()
    begin
        AssertRefusal('{"orderId":true,"expectedCount":1}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03/06: OrderOverflow returns InvalidParameterFormat without storing a successful write.</summary>
    [Test]
    procedure AC03_OrderOverflow()
    begin
        AssertRefusal('{"orderId":9223372036854775808,"expectedCount":1}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03/06: UnknownOrder returns RecordNotFound without storing a successful write.</summary>
    [Test]
    procedure AC03_UnknownOrder()
    begin
        AssertRefusal('{"orderId":975309999,"expectedCount":1}', 'RecordNotFound');
    end;

    /// <summary>AC03/06: MaximumOrder returns RecordNotFound without storing a successful write.</summary>
    [Test]
    procedure AC03_MaximumOrder()
    begin
        AssertRefusal('{"orderId":9223372036854775807,"expectedCount":1}', 'RecordNotFound');
    end;

    /// <summary>AC03/06: AlreadyPaid returns PreconditionFailed without storing a successful write.</summary>
    [Test]
    procedure AC03_AlreadyPaid()
    begin
        AssertRefusal('{"orderId":975300004,"expectedCount":1}', 'PreconditionFailed');
    end;

    /// <summary>AC03/06: DisabledShop returns PreconditionFailed without storing a successful write.</summary>
    [Test]
    procedure AC03_DisabledShop()
    begin
        AssertRefusal('{"orderId":975300005,"expectedCount":1}', 'PreconditionFailed');
    end;

    /// <summary>AC03/06: UnknownShop returns RecordNotFound without storing a successful write.</summary>
    [Test]
    procedure AC03_UnknownShop()
    begin
        AssertRefusal('{"orderId":975300006,"expectedCount":1}', 'RecordNotFound');
    end;

    /// <summary>AC03/06: CountZero returns PreconditionFailed without storing a successful write.</summary>
    [Test]
    procedure AC03_CountZero()
    begin
        AssertRefusal('{"orderId":975300001,"expectedCount":0}', 'PreconditionFailed');
    end;

    /// <summary>AC03/06: CountTwo returns PreconditionFailed without storing a successful write.</summary>
    [Test]
    procedure AC03_CountTwo()
    begin
        AssertRefusal('{"orderId":975300001,"expectedCount":2}', 'PreconditionFailed');
    end;

    /// <summary>AC03/06: CountNegative returns PreconditionFailed without storing a successful write.</summary>
    [Test]
    procedure AC03_CountNegative()
    begin
        AssertRefusal('{"orderId":975300001,"expectedCount":-1}', 'PreconditionFailed');
    end;

    /// <summary>AC03/06: CountString returns InvalidParameterFormat without storing a successful write.</summary>
    [Test]
    procedure AC03_CountString()
    begin
        AssertRefusal('{"orderId":975300001,"expectedCount":"1"}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03/06: CountDecimal returns InvalidParameterFormat without storing a successful write.</summary>
    [Test]
    procedure AC03_CountDecimal()
    begin
        AssertRefusal('{"orderId":975300001,"expectedCount":1.5}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03/06: CountNull returns InvalidParameterFormat without storing a successful write.</summary>
    [Test]
    procedure AC03_CountNull()
    begin
        AssertRefusal('{"orderId":975300001,"expectedCount":null}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03/06: CountArray returns InvalidParameterFormat without storing a successful write.</summary>
    [Test]
    procedure AC03_CountArray()
    begin
        AssertRefusal('{"orderId":975300001,"expectedCount":[]}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03/06: CountOverflow returns InvalidParameterFormat without storing a successful write.</summary>
    [Test]
    procedure AC03_CountOverflow()
    begin
        AssertRefusal('{"orderId":975300001,"expectedCount":9223372036854775808}', 'InvalidParameterFormat');
    end;

    /// <summary>AC04/06: a false return rolls back writes across the connector's explicit commit.</summary>
    [Test]
    procedure AC04_FalseRollsBack()
    begin
        AssertConnectorRollback(975300002);
    end;

    /// <summary>AC04/06: an exception also rolls back all local changes.</summary>
    [Test]
    procedure AC04_ExceptionRollsBack()
    begin
        AssertConnectorRollback(975300003);
    end;

    /// <summary>AC01/06: a read-only caller cannot invoke the payment write.</summary>
    [Test]
    procedure AC01_PermissionDenied()
    var
        Response: JsonObject;
    begin
        Fixture.A1SeedFixture();
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        Response := Execute('{"orderId":975300001,"expectedCount":1}');
        LowerPermissions.StopLoggingNAVPermissions();
        Assert.AreEqual('PermissionDenied', ReadText(Response, 'code'), 'Typed permission refusal.');
        AssertNoMarkers();
        Fixture.A2RemoveFixture();
    end;

    /// <summary>AC05: the same refusal is translated in both supported session languages.</summary>
    [Test]
    procedure AC05_TranslatedRefusal()
    var
        Response: JsonObject;
        English: Text;
        Icelandic: Text;
    begin
        Fixture.A1SeedFixture();
        Response := ExecuteInLanguage('{"orderId":975300001,"expectedCount":0}', 1033);
        English := ReadText(Response, 'error');
        Response := ExecuteInLanguage('{"orderId":975300001,"expectedCount":0}', 1039);
        Icelandic := ReadText(Response, 'error');
        Assert.AreNotEqual('', English, 'English refusal text.');
        Assert.AreNotEqual('', Icelandic, 'Icelandic refusal text.');
        Assert.AreNotEqual(English, Icelandic, 'Translated refusal.');
        Fixture.A2RemoveFixture();
    end;

    local procedure AssertRefusal(Request: Text; ExpectedCode: Text)
    var
        Response: JsonObject;
    begin
        Fixture.A1SeedFixture();
        Response := Execute(Request);
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Refusal status.');
        Assert.AreEqual(ExpectedCode, ReadText(Response, 'code'), 'Typed refusal: ' + Request);
        AssertNoMarkers();
        Fixture.A2RemoveFixture();
    end;

    local procedure AssertConnectorRollback(OrderId: BigInteger)
    var
        OrderHeader: Record "Shpfy Order Header";
        Response: JsonObject;
    begin
        Fixture.A1SeedFixture();
        Response := Execute('{"orderId":' + Format(OrderId, 0, 9) + ',"expectedCount":1}');
        Assert.AreEqual('BusinessCentralError', ReadText(Response, 'code'), 'Connector refusal.');
        Assert.IsTrue(ReadText(Response, 'error').Contains('30115'), 'Names the log table.');
        OrderHeader.Get(OrderId);
        Assert.IsFalse(OrderHeader."Fully Paid", 'Mock write and explicit commit rolled back.');
        AssertNoMarkers();
        Fixture.A2RemoveFixture();
    end;

    local procedure AssertNoMarkers()
    var
        PaidMarker: Record "Order Paid Marker ori";
    begin
        PaidMarker.SetFilter("Shop Code", 'X26ON|X26OFF|X26MISSING');
        Assert.IsTrue(PaidMarker.IsEmpty(), 'No successful write recorded.');
    end;

    local procedure Execute(RequestText: Text): JsonObject
    begin
        exit(ExecuteInLanguage(RequestText, 1033));
    end;

    local procedure ExecuteInLanguage(RequestText: Text; LanguageId: Integer) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ContentType: Text[100];
        MessageVersion: Enum "Message Version ori";
        ResponseText: Text;
        EmptyTaskId: Guid;
        MessageId: Guid;
        ResponseTime: Duration;
    begin
        RequestContent.AddText(RequestText);
        Dispatcher.EnqueueAndProcess("Message Type ori"::"Shopify.Order.MarkAsPaid", MessageVersion, '', '', 'application/json', RequestContent, EmptyTaskId, LanguageId, MessageId, ResponseContent, ContentType, ResponseTime);
        ResponseContent.GetSubText(ResponseText, 1);
        Response.ReadFrom(ResponseText);
    end;

    local procedure ReadText(Response: JsonObject; ParameterName: Text): Text
    var
        Token: JsonToken;
    begin
        if not Response.Get(ParameterName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        exit(Token.AsValue().AsText());
    end;
}
