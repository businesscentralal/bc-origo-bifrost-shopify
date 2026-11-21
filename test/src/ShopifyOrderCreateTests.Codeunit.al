namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Inventory.Item;
using Microsoft.Sales.Customer;
using Microsoft.Sales.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Issue #24 and #59: Shopify.Order.CreateSalesDocument creates a sales order, returns documentStatus, and refuses an Auto Create Credit Memo shop.</summary>
codeunit 97470 "Shopify Order Create Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        ShopCodeTok: Label 'BIFT24', Locked = true;
        OtherShopCodeTok: Label 'BIFT24X', Locked = true;
        RefundIdTok: Label '950000901', Locked = true;

    /// <summary>An order that is already processed is refused and creates no document.</summary>
    [Test]
    procedure ProcessedOrderIsRefused()
    var
        SalesHeader: Record "Sales Header";
        OrderHeader: Record "Shpfy Order Header";
        Response: JsonObject;
        Before: Integer;
    begin
        Initialize();
        SeedOrder(true);
        OrderHeader.Get(950000001);
        OrderHeader.Processed := true;
        OrderHeader.Modify();
        Before := SalesHeader.Count();
        Response := Execute(950000001);
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Processed order must be refused.');
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), 'Processed order code.');
        Assert.AreEqual(Before, SalesHeader.Count(), 'No second document.');
        Cleanup();
    end;

    /// <summary>A disabled shop is refused and creates no document.</summary>
    [Test]
    procedure DisabledShopIsRefused()
    var
        Shop: Record "Shpfy Shop";
        Response: JsonObject;
    begin
        Initialize();
        SeedOrder(true);
        Shop.Get(ShopCodeTok);
        Shop.Enabled := false;
        Shop.Modify();
        Response := Execute(950000001);
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Disabled shop status.');
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), 'Disabled shop code.');
        Cleanup();
    end;

    /// <summary>A request without orderId is refused with MissingParameter and changes nothing.</summary>
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
        Assert.AreEqual('orderId', ReadText(Response, 'parameter'), 'Missing key parameter.');
        Assert.AreEqual(Before, SalesHeader.Count(), 'Nothing created.');
    end;

    /// <summary>An unknown key is refused as UnknownParameter and changes nothing.</summary>
    [Test]
    procedure UnknownKeyIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := ExecuteRaw('{"orderId":1,"bogus":true}');
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Unknown key status.');
        Assert.AreEqual('UnknownParameter', ReadText(Response, 'code'), 'Unknown key code.');
    end;

    /// <summary>An unknown order is refused as RecordNotFound.</summary>
    [Test]
    procedure UnknownOrderIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := Execute(950000099);
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Unknown order status.');
        Assert.AreEqual('RecordNotFound', ReadText(Response, 'code'), 'Unknown order code.');
    end;

    /// <summary>The Shopify process refuses an order of a shop without access token in both languages; the refusal is returned and no document is left.</summary>
    [Test]
    procedure BusinessCentralRefusalIsReturned()
    var
        SalesHeader: Record "Sales Header";
        OrderHeader: Record "Shpfy Order Header";
        Response: JsonObject;
        PreviousLanguage: Integer;
        Before: Integer;
    begin
        Initialize();
        SeedOrder(true);
        Before := SalesHeader.Count();
        Response := Execute(950000001);
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Refusal status.');
        Assert.AreEqual('BusinessCentralError', ReadText(Response, 'code'), 'Refusal code.');
        Assert.AreEqual(Before, SalesHeader.Count(), 'No partial data.');
        OrderHeader.Get(950000001);
        Assert.IsFalse(OrderHeader.Processed, 'The order stays unprocessed.');
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1039);
        Response := Execute(950000001);
        GlobalLanguage(PreviousLanguage);
        Assert.AreEqual('BusinessCentralError', ReadText(Response, 'code'), 'Refusal code in Icelandic.');
        Cleanup();
    end;

    /// <summary>Happy path: a shop that does not create credit memos automatically gets a sales order, and documentStatus is the invariant name Open in English and Icelandic.</summary>
    [Test]
    procedure CreatesSalesOrderReturnsDocumentStatus()
    var
        OrderHeader: Record "Shpfy Order Header";
        SalesHeader: Record "Sales Header";
        Response: JsonObject;
        PreviousLanguage: Integer;
    begin
        Initialize();
        SeedCreatableOrder();
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        Response := Execute(950000001);
        GlobalLanguage(PreviousLanguage);
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Create must succeed: ' + ReadText(Response, 'error'));
        Assert.AreEqual('Order', ReadText(Response, 'documentType'), 'documentType in English.');
        Assert.AreEqual('Open', ReadText(Response, 'documentStatus'), 'documentStatus in English.');
        OrderHeader.Get(950000001);
        Assert.IsTrue(OrderHeader.Processed, 'The order is processed.');
        Assert.IsTrue(SalesHeader.Get(SalesHeader."Document Type"::Order, OrderHeader."Sales Order No."), 'The sales order exists.');
        Assert.AreEqual(SalesHeader."No.", ReadText(Response, 'documentNo'), 'Response names the sales order.');

        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1039);
        Response := Execute(950000001);
        GlobalLanguage(PreviousLanguage);
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), 'Second call is refused in Icelandic.');
        Cleanup();

        Initialize();
        SeedCreatableOrder();
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1039);
        Response := Execute(950000001);
        GlobalLanguage(PreviousLanguage);
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Create must succeed in Icelandic: ' + ReadText(Response, 'error'));
        Assert.AreEqual('Order', ReadText(Response, 'documentType'), 'documentType is the invariant name in Icelandic.');
        Assert.AreEqual('Open', ReadText(Response, 'documentStatus'), 'documentStatus is the invariant name in Icelandic.');
        Cleanup();
    end;

    /// <summary>A shop set to Auto Create Credit Memo is refused before anything is changed, in English and Icelandic, and no document is created.</summary>
    [Test]
    procedure AutoCreditMemoShopIsRefused()
    var
        SalesHeader: Record "Sales Header";
        OrderHeader: Record "Shpfy Order Header";
        Response: JsonObject;
        Before: Integer;
    begin
        Initialize();
        SeedOrder(true);
        SetRefundProcess("Shpfy ReturnRefund ProcessType"::"Auto Create Credit Memo");
        Before := SalesHeader.Count();
        Response := Execute(950000001);
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Auto credit memo shop status.');
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), 'Auto credit memo shop code.');
        Assert.AreEqual('Shop BIFT24 creates credit memos for refunds automatically.', ReadText(Response, 'error'), 'Auto credit memo shop message.');
        Assert.AreEqual(Before, SalesHeader.Count(), 'No sales document is created.');
        OrderHeader.Get(950000001);
        Assert.IsFalse(OrderHeader.Processed, 'The order stays unprocessed.');
        Assert.IsFalse(OrderHeader."Has Error", 'The order gets no error: the report did not run.');

        // Dispatcher.Execute uses the tenant default language. The orchestrator path takes the language id.
        Response := ExecuteInLanguage(950000001, 1039);
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), 'Auto credit memo shop code in Icelandic.');
        Assert.AreEqual('Verslunin BIFT24 býr sjálfkrafa til kreditreikninga fyrir endurgreiðslur.', ReadText(Response, 'error'), 'Auto credit memo shop message in Icelandic.');
        Assert.AreEqual(Before, SalesHeader.Count(), 'Still no document after the Icelandic call.');
        Cleanup();
    end;

    /// <summary>An Auto Create Credit Memo shop is refused even when another shop has an unprocessed refund, and that refund is not touched.</summary>
    [Test]
    procedure AutoCreditMemoShopWithUnrelatedRefundIsRefused()
    var
        SalesHeader: Record "Sales Header";
        RefundHeader: Record "Shpfy Refund Header";
        Response: JsonObject;
        Before: Integer;
    begin
        Initialize();
        SeedOrder(true);
        SetRefundProcess("Shpfy ReturnRefund ProcessType"::"Auto Create Credit Memo");
        SeedUnrelatedRefund();
        Before := SalesHeader.Count();
        Response := Execute(950000001);
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), 'Unrelated refund does not change the refusal.');
        Assert.AreEqual(Before, SalesHeader.Count(), 'No sales document and no credit memo is created.');
        RefundHeader.Get(RefundId());
        RefundHeader.CalcFields("Is Processed");
        Assert.IsFalse(RefundHeader."Is Processed", 'The unrelated refund is not touched.');
        Cleanup();
    end;

    /// <summary>The help chapters name documentStatus and the Auto Create Credit Memo refusal.</summary>
    [Test]
    procedure ContractDeclaresGuardAndDocumentStatus()
    var
        Contract: Interface "Msg Contract ori";
        Response: JsonObject;
        Errors: JsonArray;
        Effect: JsonObject;
        ChapterText: Text;
    begin
        Contract := "Message Type ori"::"Shopify.Order.CreateSalesDocument";
        Assert.IsTrue(Contract.GetResponse(Response), 'Response chapter is supplied.');
        Response.WriteTo(ChapterText);
        Assert.IsTrue(ChapterText.Contains('documentStatus'), 'Response chapter names documentStatus.');
        Assert.IsTrue(ChapterText.Contains('orderId'), 'Response chapter keeps orderId.');
        Assert.IsTrue(Contract.GetErrors(Errors), 'Errors chapter is supplied.');
        Errors.WriteTo(ChapterText);
        Assert.IsTrue(ChapterText.Contains('creates credit memos for refunds automatically'), 'Errors chapter names the refusal.');
        Assert.IsTrue(Contract.GetEffect(Effect), 'Effect chapter is supplied.');
        Effect.WriteTo(ChapterText);
        Assert.IsTrue(ChapterText.Contains('Auto Create Credit Memo'), 'Effect chapter names the precondition.');
    end;

    /// <summary>A caller without the app permissions is refused and nothing is created.</summary>
    [Test]
    procedure CallerWithoutPermissionIsRefused()
    var
        SalesHeader: Record "Sales Header";
        Response: JsonObject;
        Before: Integer;
    begin
        Initialize();
        SeedOrder(true);
        Before := SalesHeader.Count();
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        Response := Execute(950000001);
        LowerPermissions.StopLoggingNAVPermissions();
        Assert.AreNotEqual('Success', ReadText(Response, 'status'), 'Caller without permission must be refused.');
        Assert.AreEqual(Before, SalesHeader.Count(), 'Nothing created without permission.');
        Cleanup();
    end;

    local procedure Initialize()
    begin
        Cleanup();
    end;

    local procedure SeedOrder(WithCustomer: Boolean)
    var
        Shop: Record "Shpfy Shop";
        OrderHeader: Record "Shpfy Order Header";
        OrderLine: Record "Shpfy Order Line";
        Variant: Record "Shpfy Variant";
        Customer: Record Customer;
        Item: Record Item;
        LibrarySales: Codeunit "Library - Sales";
        LibraryInventory: Codeunit "Library - Inventory";
    begin
        if WithCustomer then
            LibrarySales.CreateCustomer(Customer);
        LibraryInventory.CreateItem(Item);
        Shop.Init();
        Shop.Code := CopyStr(ShopCodeTok, 1, MaxStrLen(Shop.Code));
        Shop.Enabled := true;
        Shop.Insert();
        SetShopUrl(Shop, 'https://bift24.myshopify.com');
        Shop."Customer Mapping Type" := Shop."Customer Mapping Type"::DefaultCustomer;
        if WithCustomer then
            Shop."Default Customer No." := Customer."No.";
        Shop.Modify();
        Variant.Init();
        Variant.Id := 960000001;
        Variant."Shop Code" := Shop.Code;
        Variant."Item No." := Item."No.";
        Variant.Insert();
        OrderHeader.Init();
        OrderHeader."Shopify Order Id" := 950000001;
        OrderHeader."Shop Code" := Shop.Code;
        OrderHeader."Shopify Order No." := 'BIFT24-1';
        OrderHeader."Document Date" := WorkDate();
        OrderHeader."Processed Currency Handling" := "Shpfy Currency Handling"::"Shop Currency";
        OrderHeader.Insert();
        OrderLine.Init();
        OrderLine."Shopify Order Id" := 950000001;
        OrderLine."Line Id" := 970000001;
        OrderLine."Shopify Variant Id" := Variant.Id;
        OrderLine.Description := Item.Description;
        OrderLine.Quantity := 2;
        OrderLine."Unit Price" := 10;
        OrderLine."Item No." := Item."No.";
        OrderLine.Insert();
        Commit();
    end;

    local procedure SeedCreatableOrder()
    begin
        SeedOrder(true);
        SetRefundProcess("Shpfy ReturnRefund ProcessType"::"Import Only");
    end;

    local procedure SetRefundProcess(RefundProcess: Enum "Shpfy ReturnRefund ProcessType")
    var
        Shop: Record "Shpfy Shop";
        OrderHeader: Record "Shpfy Order Header";
    begin
        Shop.Get(ShopCodeTok);
        // No write-back to Shopify, so the order process does not ask for an access token.
        Shop."Order Attributes To Shopify" := false;
        Shop."Auto Release Sales Orders" := false;
        Shop."Return and Refund Process" := RefundProcess;
        Shop.Modify();
        OrderHeader.Get(950000001);
        OrderHeader."Sell-to Customer No." := Shop."Default Customer No.";
        OrderHeader."Bill-to Customer No." := Shop."Default Customer No.";
        OrderHeader.Modify();
        Commit();
    end;

    local procedure SeedUnrelatedRefund()
    var
        RefundHeader: Record "Shpfy Refund Header";
    begin
        RefundHeader.Init();
        RefundHeader."Refund Id" := RefundId();
        RefundHeader."Order Id" := 959999998;
        RefundHeader."Shop Code" := CopyStr(OtherShopCodeTok, 1, MaxStrLen(RefundHeader."Shop Code"));
        RefundHeader.Insert();
        Commit();
    end;

    local procedure RefundId() Id: BigInteger
    begin
        Evaluate(Id, RefundIdTok, 9);
    end;

    local procedure SetShopUrl(var Shop: Record "Shpfy Shop"; Url: Text)
    var
        ShopRef: RecordRef;
        UrlField: FieldRef;
    begin
        // The Shopify URL field is internal to Microsoft's app; the field reference reaches it without writing around any validation.
        ShopRef.GetTable(Shop);
        UrlField := ShopRef.Field(2);
        UrlField.Value := Url;
        ShopRef.Modify();
        ShopRef.SetTable(Shop);
    end;

    local procedure Cleanup()
    var
        Shop: Record "Shpfy Shop";
        OrderHeader: Record "Shpfy Order Header";
        OrderLine: Record "Shpfy Order Line";
        Variant: Record "Shpfy Variant";
        SalesHeader: Record "Sales Header";
        Customer: Record Customer;
        Item: Record Item;
        RefundHeader: Record "Shpfy Refund Header";
    begin
        if RefundHeader.Get(RefundId()) then
            RefundHeader.Delete(true);
        if OrderHeader.Get(950000001) then begin
            if OrderHeader."Sales Order No." <> '' then
                if SalesHeader.Get(SalesHeader."Document Type"::Order, OrderHeader."Sales Order No.") then
                    SalesHeader.Delete(true);
            if OrderHeader."Sales Invoice No." <> '' then
                if SalesHeader.Get(SalesHeader."Document Type"::Invoice, OrderHeader."Sales Invoice No.") then
                    SalesHeader.Delete(true);
            OrderHeader.Delete(true);
        end;
        OrderLine.SetRange("Shopify Order Id", 950000001);
        OrderLine.DeleteAll(true);
        if Variant.Get(960000001) then begin
            if Item.Get(Variant."Item No.") then
                Item.Delete(true);
            Variant.Delete(true);
        end;
        if Shop.Get(ShopCodeTok) then begin
            if Shop."Default Customer No." <> '' then
                if Customer.Get(Shop."Default Customer No.") then
                    Customer.Delete(true);
            Shop.Delete(true);
        end;
        Commit();
    end;

    local procedure Execute(OrderId: BigInteger): JsonObject
    begin
        exit(ExecuteRaw('{"orderId":' + Format(OrderId, 0, 9) + '}'));
    end;

    local procedure ExecuteInLanguage(OrderId: BigInteger; LanguageId: Integer) ResponseJson: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseContentType: Text[100];
        EmptyTaskId: Guid;
        MessageId: Guid;
        ResponseTime: Duration;
        ResponseText: Text;
    begin
        RequestContent.AddText('{"orderId":' + Format(OrderId, 0, 9) + '}');
        Dispatcher.EnqueueAndProcess("Message Type ori"::"Shopify.Order.CreateSalesDocument", "Message Version ori"::"1.0", '', '', 'application/json', RequestContent, EmptyTaskId, LanguageId, MessageId, ResponseContent, ResponseContentType, ResponseTime);
        ResponseContent.GetSubText(ResponseText, 1);
        ResponseJson.ReadFrom(ResponseText);
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
        Dispatcher.Execute("Message Type ori"::"Shopify.Order.CreateSalesDocument", MessageVersion, '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType);
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
