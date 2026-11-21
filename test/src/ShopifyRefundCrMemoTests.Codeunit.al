namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.Customer;
using Microsoft.Sales.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Issue #30: Shopify.Refund.CreateCreditMemo creates the credit memo of an imported refund, with refusals and permissions.</summary>
codeunit 97401 "Shopify Refund Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        ShopCodeTok: Label 'BIFT30', Locked = true;

    /// <summary>Happy path in English: the refund gets a released credit memo linked to it.</summary>
    [Test]
    procedure CreatesCreditMemoEnglish()
    begin
        AssertCreatesCreditMemo(1033);
    end;

    /// <summary>Happy path in Icelandic: the refund gets a released credit memo linked to it.</summary>
    [Test]
    procedure CreatesCreditMemoIcelandic()
    begin
        AssertCreatesCreditMemo(1039);
    end;

    /// <summary>A second call on the same refund is refused and creates no second credit memo.</summary>
    [Test]
    procedure SecondCallIsRefused()
    var
        SalesHeader: Record "Sales Header";
        Response: JsonObject;
        RefundId: BigInteger;
        Before: Integer;
    begin
        Initialize();
        RefundId := SeedRefund(true, true);
        Response := Execute(RefundId);
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'First call must succeed.');
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::"Credit Memo");
        Before := SalesHeader.Count();
        Response := Execute(RefundId);
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Second call must be refused.');
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), 'Second call code.');
        Assert.AreEqual(Before, SalesHeader.Count(), 'No second credit memo.');
        Cleanup();
    end;

    /// <summary>A request without refundId is refused with MissingParameter and changes nothing.</summary>
    [Test]
    procedure MissingKeyIsRefused()
    var
        SalesHeader: Record "Sales Header";
        Response: JsonObject;
        Before: Integer;
    begin
        Initialize();
        Before := SalesHeader.Count();
        Response := ExecuteRaw('{}');
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Missing key status.');
        Assert.AreEqual('MissingParameter', ReadText(Response, 'code'), 'Missing key code.');
        Assert.AreEqual('refundId', ReadText(Response, 'parameter'), 'Missing key parameter.');
        Assert.AreEqual(Before, SalesHeader.Count(), 'Nothing created.');
    end;

    /// <summary>An unknown key is refused as UnknownParameter and changes nothing.</summary>
    [Test]
    procedure UnknownKeyIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := ExecuteRaw('{"refundId":1,"bogus":true}');
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Unknown key status.');
        Assert.AreEqual('UnknownParameter', ReadText(Response, 'code'), 'Unknown key code.');
    end;

    /// <summary>A refund whose Shopify order is not processed is refused by the Shopify process and leaves no document.</summary>
    [Test]
    procedure BusinessCentralRefusalIsReturned()
    var
        SalesHeader: Record "Sales Header";
        Response: JsonObject;
        RefundId: BigInteger;
        Before: Integer;
    begin
        Initialize();
        RefundId := SeedRefund(false, true);
        Before := SalesHeader.Count();
        Response := Execute(RefundId);
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Refusal status.');
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), 'Refusal code.');
        Assert.AreEqual(Before, SalesHeader.Count(), 'No partial data.');
        Cleanup();
    end;

    /// <summary>A shop that is not set to Auto Create Credit Memo is refused.</summary>
    [Test]
    procedure ShopWithoutAutoProcessIsRefused()
    var
        Response: JsonObject;
        RefundId: BigInteger;
    begin
        Initialize();
        RefundId := SeedRefund(true, false);
        Response := Execute(RefundId);
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Shop refusal status.');
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), 'Shop refusal code.');
        Cleanup();
    end;

    /// <summary>A caller without the app permissions is refused and nothing is created.</summary>
    [Test]
    procedure CallerWithoutPermissionIsRefused()
    var
        SalesHeader: Record "Sales Header";
        Response: JsonObject;
        RefundId: BigInteger;
        Before: Integer;
    begin
        Initialize();
        RefundId := SeedRefund(true, true);
        Before := SalesHeader.Count();
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        Response := Execute(RefundId);
        LowerPermissions.StopLoggingNAVPermissions();
        Assert.AreNotEqual('Success', ReadText(Response, 'status'), 'Caller without permission must be refused.');
        Assert.AreEqual(Before, SalesHeader.Count(), 'Nothing created without permission.');
        Cleanup();
    end;

    local procedure AssertCreatesCreditMemo(LanguageId: Integer)
    var
        DocLink: Record "Shpfy Doc. Link To Doc.";
        SalesHeader: Record "Sales Header";
        Response: JsonObject;
        RefundId: BigInteger;
        PreviousLanguage: Integer;
    begin
        Initialize();
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        RefundId := SeedRefund(true, true);
        Response := Execute(RefundId);
        GlobalLanguage(PreviousLanguage);
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Create must succeed: ' + ReadText(Response, 'error'));
        DocLink.SetRange("Shopify Document Type", "Shpfy Shop Document Type"::"Shopify Shop Refund");
        DocLink.SetRange("Shopify Document Id", RefundId);
        Assert.IsTrue(DocLink.FindFirst(), 'The refund must be linked to a document.');
        Assert.IsTrue(SalesHeader.Get(SalesHeader."Document Type"::"Credit Memo", DocLink."Document No."), 'The credit memo must exist.');
        Assert.AreEqual(ReadText(Response, 'documentNo'), SalesHeader."No.", 'Response names the credit memo.');
        Assert.AreEqual(Format(SalesHeader.Status::Released), Format(SalesHeader.Status), 'The credit memo is released.');
        Cleanup();
    end;

    local procedure Initialize()
    begin
        Cleanup();
    end;

    local procedure SeedRefund(OrderProcessed: Boolean; AutoCreate: Boolean) RefundId: BigInteger
    var
        Shop: Record "Shpfy Shop";
        OrderHeader: Record "Shpfy Order Header";
        RefundHeader: Record "Shpfy Refund Header";
        Customer: Record Customer;
        LibrarySales: Codeunit "Library - Sales";
        LibraryERM: Codeunit "Library - ERM";
        OrderId: BigInteger;
    begin
        LibrarySales.CreateCustomer(Customer);
        Shop.Init();
        Shop.Code := CopyStr(ShopCodeTok, 1, MaxStrLen(Shop.Code));
        Shop.Insert();
        if AutoCreate then
            Shop."Return and Refund Process" := Shop."Return and Refund Process"::"Auto Create Credit Memo"
        else
            Shop."Return and Refund Process" := Shop."Return and Refund Process"::"Import Only";
        Shop."Refund Account" := LibraryERM.CreateGLAccountWithSalesSetup();
        Shop.Modify();
        OrderId := 930000001;
        RefundId := 940000001;
        OrderHeader.Init();
        OrderHeader."Shopify Order Id" := OrderId;
        OrderHeader."Shop Code" := Shop.Code;
        OrderHeader."Shopify Order No." := 'BIFT30-1';
        OrderHeader."Sell-to Customer No." := Customer."No.";
        OrderHeader."Bill-to Customer No." := Customer."No.";
        OrderHeader.Processed := OrderProcessed;
        OrderHeader."Processed Currency Handling" := "Shpfy Currency Handling"::"Shop Currency";
        OrderHeader.Insert();
        RefundHeader.Init();
        RefundHeader."Refund Id" := RefundId;
        RefundHeader."Order Id" := OrderId;
        RefundHeader."Shop Code" := Shop.Code;
        RefundHeader."Created At" := CurrentDateTime();
        RefundHeader."Total Refunded Amount" := 100;
        RefundHeader.Insert();
    end;

    local procedure Cleanup()
    var
        Shop: Record "Shpfy Shop";
        OrderHeader: Record "Shpfy Order Header";
        RefundHeader: Record "Shpfy Refund Header";
        DocLink: Record "Shpfy Doc. Link To Doc.";
        SalesHeader: Record "Sales Header";
    begin
        DocLink.SetRange("Shopify Document Type", "Shpfy Shop Document Type"::"Shopify Shop Refund");
        DocLink.SetRange("Shopify Document Id", 940000001);
        if DocLink.FindSet() then
            repeat
                if SalesHeader.Get(SalesHeader."Document Type"::"Credit Memo", DocLink."Document No.") then
                    SalesHeader.Delete(true);
            until DocLink.Next() = 0;
        DocLink.DeleteAll();
        if RefundHeader.Get(940000001) then
            RefundHeader.Delete(true);
        if OrderHeader.Get(930000001) then
            OrderHeader.Delete(true);
        if Shop.Get(ShopCodeTok) then
            Shop.Delete(true);
        Commit();
    end;

    local procedure Execute(RefundId: BigInteger): JsonObject
    begin
        exit(ExecuteRaw('{"refundId":' + Format(RefundId, 0, 9) + '}'));
    end;

    local procedure ExecuteRaw(RequestText: Text) ResponseJson: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseContentType: Text[100];
        MessageVersion: Enum "Message Version ori";
        ResponseText: Text;
    begin
        RequestContent.AddText(RequestText);
        Dispatcher.Execute("Message Type ori"::"Shopify.Refund.CreateCreditMemo", MessageVersion, '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        ResponseJson.ReadFrom(ResponseText);
    end;

    local procedure ReadText(JsonObj: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not JsonObj.Get(PropertyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        exit(Token.AsValue().AsText());
    end;
}
