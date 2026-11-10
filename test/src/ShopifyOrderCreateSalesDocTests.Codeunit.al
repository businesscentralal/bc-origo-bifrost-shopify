namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.Customer;
using Microsoft.Sales.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Issue #24: Shopify.Order.CreateSalesDocument creates the sales document of an imported order, with refusals and permissions.</summary>
codeunit 97470 "Shpfy Order CreateDoc Test ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        ShopCodeTok: Label 'BIFT24', Locked = true;
        OrderIdTok: Label '950000001', Locked = true;

    /// <summary>Happy path in English: the order gets a sales order and is marked processed.</summary>
    [Test]
    procedure CreatesSalesOrderEnglish()
    begin
        AssertCreatesSalesOrder(1033);
    end;

    /// <summary>Happy path in Icelandic: the order gets a sales order and is marked processed.</summary>
    [Test]
    procedure CreatesSalesOrderIcelandic()
    begin
        AssertCreatesSalesOrder(1039);
    end;

    /// <summary>The contract declares the write effect, the request key and the permission set.</summary>
    [Test]
    procedure ContractDeclaresEffectAndKey()
    var
        Contract: Interface "Msg Contract ori";
        Effect: JsonObject;
        Parameters: JsonArray;
        Token: JsonToken;
        ParameterText: Text;
    begin
        Contract := "Message Type ori"::"Shopify.Order.CreateSalesDocument";
        Assert.IsTrue(Contract.GetEffect(Effect), 'Effect chapter is supplied.');
        Effect.Get('effect', Token);
        Assert.AreEqual('write', Token.AsValue().AsText(), 'Effect is write.');
        Effect.Get('idempotent', Token);
        Assert.IsFalse(Token.AsValue().AsBoolean(), 'Not idempotent.');
        Effect.Get('permissionSet', Token);
        Assert.AreEqual('SHOPIFY Full ori', Token.AsValue().AsText(), 'Permission set.');
        Effect.Get('changes', Token);
        Assert.IsTrue(Token.AsValue().AsText().Contains('Commit()'), 'Changes names the Commit().');
        Assert.IsTrue(Contract.GetParameters(Parameters), 'Parameters chapter is supplied.');
        Parameters.WriteTo(ParameterText);
        Assert.IsTrue(ParameterText.Contains('shopifyOrderId'), 'shopifyOrderId is declared.');
    end;

    /// <summary>A second call on the same order is refused and creates no second document.</summary>
    [Test]
    procedure SecondCallIsRefused()
    var
        SalesHeader: Record "Sales Header";
        Response: JsonObject;
        Before: Integer;
    begin
        Initialize();
        SeedOrder(false);
        Response := Execute();
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'First call must succeed: ' + ReadText(Response, 'error'));
        Before := SalesHeader.Count();
        Response := Execute();
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Second call must be refused.');
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), 'Second call code.');
        Assert.AreEqual(Before, SalesHeader.Count(), 'No second document.');
        Cleanup();
    end;

    /// <summary>A request without shopifyOrderId is refused with MissingParameter and changes nothing.</summary>
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
        Assert.AreEqual('shopifyOrderId', ReadText(Response, 'parameter'), 'Missing key parameter.');
        Assert.AreEqual(Before, SalesHeader.Count(), 'Nothing created.');
    end;

    /// <summary>An unknown key is refused as UnknownParameter and changes nothing.</summary>
    [Test]
    procedure UnknownKeyIsRefused()
    var
        SalesHeader: Record "Sales Header";
        Response: JsonObject;
        Before: Integer;
    begin
        Initialize();
        Before := SalesHeader.Count();
        Response := ExecuteRaw('{"shopifyOrderId":1,"bogus":true}');
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Unknown key status.');
        Assert.AreEqual('UnknownParameter', ReadText(Response, 'code'), 'Unknown key code.');
        Assert.AreEqual(Before, SalesHeader.Count(), 'Nothing created.');
    end;

    /// <summary>A non-numeric shopifyOrderId is refused with InvalidParameterFormat.</summary>
    [Test]
    procedure InvalidKeyIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := ExecuteRaw('{"shopifyOrderId":"abc"}');
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Invalid key status.');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), 'Invalid key code.');
    end;

    /// <summary>An order that is not imported is refused with RecordNotFound.</summary>
    [Test]
    procedure UnknownOrderIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := ExecuteRaw('{"shopifyOrderId":959999999}');
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Unknown order status.');
        Assert.AreEqual('RecordNotFound', ReadText(Response, 'code'), 'Unknown order code.');
    end;

    /// <summary>A blocked customer is refused by Business Central, the error is kept on the order and no document is left.</summary>
    [Test]
    procedure BusinessCentralRefusalIsReturned()
    var
        SalesHeader: Record "Sales Header";
        OrderHeader: Record "Shpfy Order Header";
        Response: JsonObject;
        Before: Integer;
    begin
        Initialize();
        SeedOrder(true);
        Before := SalesHeader.Count();
        Response := Execute();
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Refusal status.');
        Assert.AreEqual('BusinessCentralError', ReadText(Response, 'code'), 'Refusal code.');
        Assert.AreEqual(Before, SalesHeader.Count(), 'No partial data.');
        OrderHeader.Get(OrderId());
        Assert.IsFalse(OrderHeader.Processed, 'The order stays unprocessed.');
        Assert.IsTrue(OrderHeader."Has Error", 'The order keeps the error.');
        Cleanup();
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
        SeedOrder(false);
        Before := SalesHeader.Count();
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        Response := Execute();
        LowerPermissions.StopLoggingNAVPermissions();
        Assert.AreNotEqual('Success', ReadText(Response, 'status'), 'Caller without permission must be refused.');
        Assert.AreEqual(Before, SalesHeader.Count(), 'Nothing created without permission.');
        Cleanup();
    end;

    local procedure AssertCreatesSalesOrder(LanguageId: Integer)
    var
        OrderHeader: Record "Shpfy Order Header";
        SalesHeader: Record "Sales Header";
        Response: JsonObject;
        CustomerNo: Code[20];
        PreviousLanguage: Integer;
    begin
        Initialize();
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        CustomerNo := SeedOrder(false);
        Response := Execute();
        GlobalLanguage(PreviousLanguage);
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Create must succeed: ' + ReadText(Response, 'error'));
        OrderHeader.Get(OrderId());
        Assert.IsTrue(OrderHeader.Processed, 'The order is processed.');
        Assert.AreNotEqual('', OrderHeader."Sales Order No.", 'The order names its sales order.');
        Assert.IsTrue(SalesHeader.Get(SalesHeader."Document Type"::Order, OrderHeader."Sales Order No."), 'The sales order exists.');
        Assert.AreEqual(ReadText(Response, 'documentNo'), SalesHeader."No.", 'Response names the sales order.');
        Assert.AreEqual(Format(SalesHeader."Document Type"::Order), ReadText(Response, 'documentType'), 'Response names the document type.');
        Assert.AreEqual(CustomerNo, SalesHeader."Sell-to Customer No.", 'The sales order is for the order customer.');
        Cleanup();
    end;

    local procedure Initialize()
    begin
        Cleanup();
    end;

    local procedure OrderId() Id: BigInteger
    begin
        Evaluate(Id, OrderIdTok);
    end;

    local procedure SeedOrder(BlockCustomer: Boolean): Code[20]
    var
        Shop: Record "Shpfy Shop";
        OrderHeader: Record "Shpfy Order Header";
        Customer: Record Customer;
        LibrarySales: Codeunit "Library - Sales";
    begin
        LibrarySales.CreateCustomer(Customer);
        if BlockCustomer then begin
            Customer.Blocked := Customer.Blocked::All;
            Customer.Modify();
        end;
        Shop.Init();
        Shop.Code := CopyStr(ShopCodeTok, 1, MaxStrLen(Shop.Code));
        Shop."Auto Release Sales Orders" := false;
        // Assigned without validation: no Shopify connection is set up and no Shopify call is made.
        Shop.Enabled := true;
        // The shop does not write the BC document number back to Shopify as an order attribute.
        Shop."Order Attributes To Shopify" := false;
        Shop.Insert();
        SetShopUrl(Shop);
        OrderHeader.Init();
        OrderHeader."Shopify Order Id" := OrderId();
        OrderHeader."Shop Code" := Shop.Code;
        OrderHeader."Shopify Order No." := 'BIFT24-1';
        OrderHeader."Sell-to Customer No." := Customer."No.";
        OrderHeader."Bill-to Customer No." := Customer."No.";
        OrderHeader."Document Date" := WorkDate();
        OrderHeader."Processed Currency Handling" := "Shpfy Currency Handling"::"Shop Currency";
        OrderHeader.Insert();
        Commit();
        exit(Customer."No.");
    end;

    local procedure Cleanup()
    var
        Shop: Record "Shpfy Shop";
        OrderHeader: Record "Shpfy Order Header";
        SalesHeader: Record "Sales Header";
        Customer: Record Customer;
    begin
        if OrderHeader.Get(OrderId()) then begin
            if OrderHeader."Sales Order No." <> '' then
                if SalesHeader.Get(SalesHeader."Document Type"::Order, OrderHeader."Sales Order No.") then
                    SalesHeader.Delete(true);
            if OrderHeader."Sales Invoice No." <> '' then
                if SalesHeader.Get(SalesHeader."Document Type"::Invoice, OrderHeader."Sales Invoice No.") then
                    SalesHeader.Delete(true);
            OrderHeader.Delete(true);
            if Customer.Get(OrderHeader."Sell-to Customer No.") then
                Customer.Delete(true);
        end;
        if Shop.Get(ShopCodeTok) then
            Shop.Delete(true);
        Commit();
    end;

    local procedure Execute(): JsonObject
    begin
        exit(ExecuteRaw('{"shopifyOrderId":' + OrderIdTok + '}'));
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

    local procedure SetShopUrl(var Shop: Record "Shpfy Shop")
    var
        ShopRef: RecordRef;
        UrlRef: FieldRef;
        UrlTok: Label 'https://%1.myshopify.com', Locked = true;
    begin
        // Shopify URL (field 2, caption Shopify Admin URL) is Access = Internal; the order process requires a value. No Shopify call is made.
        ShopRef.GetTable(Shop);
        UrlRef := ShopRef.Field(2);
        UrlRef.Value := StrSubstNo(UrlTok, LowerCase(Shop.Code));
        ShopRef.Modify();
        ShopRef.SetTable(Shop);
    end;
}
