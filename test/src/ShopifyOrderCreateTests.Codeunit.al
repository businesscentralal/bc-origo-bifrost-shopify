namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Inventory.Item;
using Microsoft.Sales.Customer;
using Microsoft.Sales.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Issue #24: Shopify.Order.CreateSalesDocument refusals, Shopify-process refusal and permissions. The happy path needs a Shopify access token (live store) and is not covered here.</summary>
codeunit 97470 "Shopify Order Create Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        ShopCodeTok: Label 'BIFT24', Locked = true;

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
    begin
        if OrderHeader.Get(950000001) then begin
            if OrderHeader."Sales Order No." <> '' then
                if SalesHeader.Get(SalesHeader."Document Type"::Order, OrderHeader."Sales Order No.") then
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
