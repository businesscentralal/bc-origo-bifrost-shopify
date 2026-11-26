namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.Customer;
using Origo.Bifrost;
using Origo.Bifrost.Shopify;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue #19: Shopify.Company.Add. The live Shopify API is not called. The stand-in 97514 stores the company, the main
/// contact and the location. A customer with no e-mail is left to report 30113, which skips it without calling Shopify.
/// </summary>
codeunit 97513 "Shpfy Company Add Test ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        ShopCodeTok: Label 'BIFT19', Locked = true;
        OtherShopTok: Label 'BIFT19B', Locked = true;
        CustomerATok: Label 'BIFT19-A', Locked = true;
        CustomerBTok: Label 'BIFT19-B', Locked = true;
        CustomerCTok: Label 'BIFT19&C|(1)', Locked = true;
        NoEmailTok: Label 'BIFT19-NOEM', Locked = true;

    /// <summary>Two customers, one with filter characters in the number, each get a company, a main contact and a location.</summary>
    [Test]
    procedure AddsCompaniesForSelectedCustomers()
    var
        Stub: Codeunit "Shpfy Company Add Stub ori";
        Response: JsonObject;
        Entry: JsonObject;
    begin
        Initialize();
        SeedShop(ShopCodeTok, true);
        SeedCustomer(CustomerATok, 'a@example.com');
        SeedCustomer(CustomerCTok, 'c@example.com');
        BindSubscription(Stub);
        Response := Execute(ShopCodeTok, '["' + CustomerATok + '","' + CustomerCTok + '"]', 2);
        UnbindSubscription(Stub);
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Success status.');
        Assert.AreEqual(ShopCodeTok, ReadText(Response, 'shopCode'), 'Shop code.');
        Assert.AreEqual('2', ReadText(Response, 'requested'), 'Requested.');
        Assert.AreEqual('2', ReadText(Response, 'created'), 'Created.');
        Assert.AreEqual('0', ReadText(Response, 'alreadyLinked'), 'None already linked.');
        Assert.AreEqual('0', ReadText(Response, 'failed'), 'None failed.');
        Entry := ResultEntry(Response, CustomerCTok);
        Assert.AreEqual('created', ReadText(Entry, 'outcome'), 'Filter-character customer is created.');
        Assert.AreNotEqual('0', ReadText(Entry, 'shopifyCompanyId'), 'Created company id.');
        Assert.AreEqual('', ReadText(Entry, 'message'), 'Created message is empty.');
        AssertCompanyShape(ShopCodeTok, CustomerCTok);
        Assert.AreEqual(2, CompanyCount(ShopCodeTok), 'One company per customer.');
        Cleanup();
    end;

    /// <summary>A second call creates no company and reports the customers as already linked.</summary>
    [Test]
    procedure RepeatCallDoesNotCreateASecondCompany()
    var
        Stub: Codeunit "Shpfy Company Add Stub ori";
        Response: JsonObject;
        FirstId: Text;
    begin
        Initialize();
        SeedShop(ShopCodeTok, true);
        SeedCustomer(CustomerATok, 'a@example.com');
        BindSubscription(Stub);
        Response := Execute(ShopCodeTok, '["' + CustomerATok + '"]', 1);
        FirstId := ReadText(ResultEntry(Response, CustomerATok), 'shopifyCompanyId');
        Response := Execute(ShopCodeTok, '["' + CustomerATok + '"]', 1);
        UnbindSubscription(Stub);
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Repeat status.');
        Assert.AreEqual('0', ReadText(Response, 'created'), 'Repeat creates nothing.');
        Assert.AreEqual('1', ReadText(Response, 'alreadyLinked'), 'Already linked.');
        Assert.AreEqual('alreadyLinked', ReadText(ResultEntry(Response, CustomerATok), 'outcome'), 'Outcome.');
        Assert.AreEqual(FirstId, ReadText(ResultEntry(Response, CustomerATok), 'shopifyCompanyId'), 'Same company id.');
        Assert.AreEqual(1, CompanyCount(ShopCodeTok), 'Still one company.');
        Cleanup();
    end;

    /// <summary>A company in another shop does not count as linked, so the customer gets a company in this shop.</summary>
    [Test]
    procedure CompanyInAnotherShopDoesNotBlock()
    var
        Stub: Codeunit "Shpfy Company Add Stub ori";
        Response: JsonObject;
    begin
        Initialize();
        SeedShop(ShopCodeTok, true);
        SeedShop(OtherShopTok, true);
        SeedCustomer(CustomerATok, 'a@example.com');
        BindSubscription(Stub);
        Response := Execute(ShopCodeTok, '["' + CustomerATok + '"]', 1);
        Assert.AreEqual('created', ReadText(ResultEntry(Response, CustomerATok), 'outcome'), 'First shop creates.');
        Response := Execute(OtherShopTok, '["' + CustomerATok + '"]', 1);
        UnbindSubscription(Stub);
        Assert.AreEqual('created', ReadText(ResultEntry(Response, CustomerATok), 'outcome'), 'Other shop creates its own company.');
        Assert.AreEqual(1, CompanyCount(ShopCodeTok), 'First shop still has one company.');
        Assert.AreEqual(1, CompanyCount(OtherShopTok), 'Other shop has one company.');
        Cleanup();
    end;

    /// <summary>expectedCount that is not the length of customerNos is refused and nothing is created.</summary>
    [Test]
    procedure ExpectedCountMismatchIsRefused()
    var
        Stub: Codeunit "Shpfy Company Add Stub ori";
        Response: JsonObject;
    begin
        Initialize();
        SeedShop(ShopCodeTok, true);
        SeedCustomer(CustomerATok, 'a@example.com');
        BindSubscription(Stub);
        Response := Execute(ShopCodeTok, '["' + CustomerATok + '"]', 2);
        UnbindSubscription(Stub);
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Mismatch status.');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), 'Mismatch code.');
        Assert.AreEqual('expectedCount', ReadText(Response, 'parameter'), 'Mismatch parameter.');
        Assert.AreEqual(0, CompanyCount(ShopCodeTok), 'Nothing created.');
        Cleanup();
    end;

    /// <summary>An unknown customer is refused before any company is created.</summary>
    [Test]
    procedure UnknownCustomerIsRefused()
    var
        Stub: Codeunit "Shpfy Company Add Stub ori";
        Response: JsonObject;
    begin
        Initialize();
        SeedShop(ShopCodeTok, true);
        SeedCustomer(CustomerATok, 'a@example.com');
        BindSubscription(Stub);
        Response := Execute(ShopCodeTok, '["' + CustomerATok + '","BIFT19-NONE"]', 2);
        UnbindSubscription(Stub);
        Assert.AreEqual('RecordNotFound', ReadText(Response, 'code'), 'Unknown customer code.');
        Assert.AreEqual('customerNos', ReadText(Response, 'parameter'), 'Unknown customer parameter.');
        Assert.AreEqual(0, CompanyCount(ShopCodeTok), 'Nothing created.');
        Cleanup();
    end;

    /// <summary>One customer the stand-in refuses does not stop the others and leaves no company row.</summary>
    [Test]
    procedure OneFailingCustomerDoesNotStopTheOthers()
    var
        Stub: Codeunit "Shpfy Company Add Stub ori";
        Response: JsonObject;
    begin
        Initialize();
        SeedShop(ShopCodeTok, true);
        SeedCustomer(CustomerATok, 'a@example.com');
        SeedCustomer(CustomerBTok, 'b@example.com');
        SeedCustomer(CustomerCTok, 'c@example.com');
        Stub.SetFailCustomer(CustomerBTok);
        BindSubscription(Stub);
        Response := Execute(ShopCodeTok, '["' + CustomerATok + '","' + CustomerBTok + '","' + CustomerCTok + '"]', 3);
        UnbindSubscription(Stub);
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Call status: ' + ReadText(Response, 'message'));
        Assert.AreEqual('2', ReadText(Response, 'created'), 'Two created.');
        Assert.AreEqual('1', ReadText(Response, 'failed'), 'One failed.');
        Assert.AreEqual('created', ReadText(ResultEntry(Response, CustomerATok), 'outcome'), 'First created.');
        Assert.AreEqual('failed', ReadText(ResultEntry(Response, CustomerBTok), 'outcome'), 'Middle failed.');
        Assert.IsTrue(StrPos(ReadText(ResultEntry(Response, CustomerBTok), 'message'), 'cannot export customer') > 0, 'Connector text: ' + ReadText(ResultEntry(Response, CustomerBTok), 'message'));
        Assert.AreEqual('0', ReadText(ResultEntry(Response, CustomerBTok), 'shopifyCompanyId'), 'Failed id is 0.');
        Assert.AreEqual('created', ReadText(ResultEntry(Response, CustomerCTok), 'outcome'), 'Last created.');
        Assert.AreEqual(0, CompanyCountFor(CustomerBTok), 'No half-made company.');
        Assert.AreEqual(2, CompanyCount(ShopCodeTok), 'Only the successful companies remain.');
        Cleanup();
    end;

    /// <summary>A customer with no e-mail is failed with the connector's own skip text and does not stop the other customer.</summary>
    [Test]
    procedure CustomerWithoutEmailIsFailedByConnector()
    var
        Stub: Codeunit "Shpfy Company Add Stub ori";
        Response: JsonObject;
    begin
        Initialize();
        SeedShop(ShopCodeTok, true);
        SeedCustomer(CustomerATok, 'a@example.com');
        SeedCustomer(NoEmailTok, '');
        Stub.SetPassThrough(NoEmailTok);
        BindSubscription(Stub);
        Response := Execute(ShopCodeTok, '["' + CustomerATok + '","' + NoEmailTok + '"]', 2);
        UnbindSubscription(Stub);
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Call status: ' + ReadText(Response, 'message'));
        Assert.AreEqual('1', ReadText(Response, 'created'), 'The customer with an e-mail is created.');
        Assert.AreEqual('1', ReadText(Response, 'failed'), 'The customer without an e-mail failed.');
        Assert.AreEqual('failed', ReadText(ResultEntry(Response, NoEmailTok), 'outcome'), 'No-email outcome.');
        Assert.IsTrue(StrPos(ReadText(ResultEntry(Response, NoEmailTok), 'message'), 'no e-mail address') > 0, 'Connector skip text: ' + ReadText(ResultEntry(Response, NoEmailTok), 'message'));
        Assert.AreEqual(0, CompanyCountFor(NoEmailTok), 'No company for the skipped customer.');
        AssertCompanyShape(ShopCodeTok, CustomerATok);
        Cleanup();
    end;

    /// <summary>An unknown shop is RecordNotFound and a disabled shop is PreconditionFailed. Nothing is created.</summary>
    [Test]
    procedure UnknownOrDisabledShopIsRefused()
    var
        Stub: Codeunit "Shpfy Company Add Stub ori";
        Response: JsonObject;
    begin
        Initialize();
        SeedCustomer(CustomerATok, 'a@example.com');
        BindSubscription(Stub);
        Response := Execute('BIFT19-NONE', '["' + CustomerATok + '"]', 1);
        Assert.AreEqual('RecordNotFound', ReadText(Response, 'code'), 'Unknown shop code.');
        SeedShop(ShopCodeTok, false);
        Response := Execute(ShopCodeTok, '["' + CustomerATok + '"]', 1);
        UnbindSubscription(Stub);
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), 'Disabled shop code.');
        Assert.AreEqual(0, CompanyCount(ShopCodeTok), 'Nothing created.');
        Cleanup();
    end;

    /// <summary>A missing key, an empty list and an unknown key are refused before anything changes.</summary>
    [Test]
    procedure MissingOrInvalidRequestIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := ExecuteRaw('{"customerNos":["X"],"expectedCount":1}');
        Assert.AreEqual('MissingParameter', ReadText(Response, 'code'), 'Missing shop code.');
        Assert.AreEqual('shopCode', ReadText(Response, 'parameter'), 'Missing shop parameter.');
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '","expectedCount":1}');
        Assert.AreEqual('MissingParameter', ReadText(Response, 'code'), 'Missing customers code.');
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '","customerNos":["' + CustomerATok + '"]}');
        Assert.AreEqual('MissingParameter', ReadText(Response, 'code'), 'Missing expectedCount code.');
        Assert.AreEqual('expectedCount', ReadText(Response, 'parameter'), 'Missing expectedCount parameter.');
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '","customerNos":[],"expectedCount":0}');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), 'Empty list.');
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '","customerNos":["' + CustomerATok + '"],"expectedCount":1,"bogus":true}');
        Assert.AreEqual('UnknownParameter', ReadText(Response, 'code'), 'Unknown key.');
    end;

    /// <summary>A repeated customer number is kept once, and expectedCount still counts the array as sent.</summary>
    [Test]
    procedure RepeatedCustomerNumberIsKeptOnce()
    var
        Stub: Codeunit "Shpfy Company Add Stub ori";
        Response: JsonObject;
    begin
        Initialize();
        SeedShop(ShopCodeTok, true);
        SeedCustomer(CustomerATok, 'a@example.com');
        BindSubscription(Stub);
        Response := Execute(ShopCodeTok, '["' + CustomerATok + '","' + LowerCase(CustomerATok) + '"]', 2);
        UnbindSubscription(Stub);
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Duplicate status.');
        Assert.AreEqual('1', ReadText(Response, 'requested'), 'Distinct customer.');
        Assert.AreEqual('1', ReadText(Response, 'created'), 'Created once.');
        Assert.AreEqual(1, ResultsOf(Response).Count(), 'One result.');
        Assert.AreEqual(1, CompanyCount(ShopCodeTok), 'One company.');
        Cleanup();
    end;

    /// <summary>A caller without the app permissions is refused and nothing is created.</summary>
    [Test]
    procedure CallerWithoutPermissionIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        SeedShop(ShopCodeTok, true);
        SeedCustomer(CustomerATok, 'a@example.com');
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        Response := Execute(ShopCodeTok, '["' + CustomerATok + '"]', 1);
        LowerPermissions.StopLoggingNAVPermissions();
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Permission status.');
        Assert.AreEqual('PermissionDenied', ReadText(Response, 'code'), 'Permission code.');
        Assert.AreEqual(0, CompanyCount(ShopCodeTok), 'Nothing created.');
        Cleanup();
    end;

    local procedure Initialize()
    begin
        Cleanup();
    end;

    local procedure SeedShop(ShopCode: Code[20]; Enabled: Boolean)
    var
        Shop: Record "Shpfy Shop";
    begin
        if not Shop.Get(ShopCode) then begin
            Shop.Init();
            Shop.Code := ShopCode;
            Shop.Insert();
        end;
        Shop.Enabled := Enabled;
        Shop."Shop Id" := 19019;
        Shop.Modify();
        Commit();
    end;

    local procedure SeedCustomer(CustomerNo: Code[20]; Email: Text[80])
    var
        Customer: Record Customer;
    begin
        if Customer.Get(CustomerNo) then
            Customer.Delete();
        Customer.Init();
        Customer."No." := CustomerNo;
        Customer.Name := 'Bifrost company ' + CustomerNo;
        Customer."E-Mail" := Email;
        Customer.Insert();
        Commit();
    end;

    local procedure Cleanup()
    var
        Shop: Record "Shpfy Shop";
    begin
        DeleteCustomer(CustomerATok);
        DeleteCustomer(CustomerBTok);
        DeleteCustomer(CustomerCTok);
        DeleteCustomer(NoEmailTok);
        DeleteShop(ShopCodeTok);
        DeleteShop(OtherShopTok);
        if Shop.Get(ShopCodeTok) then
            Shop.Delete(true);
        Commit();
    end;

    local procedure DeleteShop(ShopCode: Code[20])
    var
        Shop: Record "Shpfy Shop";
        Company: Record "Shpfy Company";
        ShopifyCustomer: Record "Shpfy Customer";
    begin
        Company.SetRange("Shop Code", ShopCode);
        Company.DeleteAll(true);
        ShopifyCustomer.SetRange("Shop Id", 19019);
        ShopifyCustomer.DeleteAll();
        if Shop.Get(ShopCode) then
            Shop.Delete(true);
    end;

    local procedure DeleteCustomer(CustomerNo: Code[20])
    var
        Customer: Record Customer;
        Company: Record "Shpfy Company";
        Skipped: RecordRef;
        RecordIdField: FieldRef;
    begin
        if not Customer.Get(CustomerNo) then
            exit;
        Skipped.Open(30159);
        RecordIdField := Skipped.Field(5);
        RecordIdField.SetRange(Customer.RecordId);
        Skipped.DeleteAll();
        Skipped.Close();
        Company.SetRange("Customer SystemId", Customer.SystemId);
        Company.DeleteAll(true);
        Customer.Delete();
    end;

    local procedure Execute(ShopCode: Text; CustomerNosJson: Text; ExpectedCount: Integer): JsonObject
    begin
        exit(ExecuteRaw('{"shopCode":"' + ShopCode + '","customerNos":' + CustomerNosJson + ',"expectedCount":' + Format(ExpectedCount, 0, 9) + '}'));
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
        Dispatcher.Execute("Message Type ori"::"Shopify.Company.Add", MessageVersion, '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        ResponseJson.ReadFrom(ResponseText);
    end;

    local procedure ResultsOf(Response: JsonObject): JsonArray
    var
        Token: JsonToken;
    begin
        Response.Get('results', Token);
        exit(Token.AsArray());
    end;

    local procedure ResultEntry(Response: JsonObject; CustomerNo: Text): JsonObject
    var
        Token: JsonToken;
    begin
        foreach Token in ResultsOf(Response) do
            if ReadText(Token.AsObject(), 'customerNo') = CustomerNo then
                exit(Token.AsObject());
        Assert.Fail('No entry for customer ' + CustomerNo);
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

    local procedure CompanyCount(ShopCode: Code[20]): Integer
    var
        Company: Record "Shpfy Company";
    begin
        Company.SetRange("Shop Code", ShopCode);
        exit(Company.Count());
    end;

    local procedure CompanyCountFor(CustomerNo: Code[20]): Integer
    var
        Customer: Record Customer;
        Company: Record "Shpfy Company";
    begin
        if not Customer.Get(CustomerNo) then
            exit(0);
        Company.SetRange("Customer SystemId", Customer.SystemId);
        exit(Company.Count());
    end;

    local procedure AssertCompanyShape(ShopCode: Code[20]; CustomerNo: Code[20])
    var
        Customer: Record Customer;
        Company: Record "Shpfy Company";
        CompanyLocation: Record "Shpfy Company Location";
        ShopifyCustomer: Record "Shpfy Customer";
    begin
        Customer.Get(CustomerNo);
        Company.SetRange("Shop Code", ShopCode);
        Company.SetRange("Customer SystemId", Customer.SystemId);
        Assert.IsTrue(Company.FindFirst(), 'Company row for ' + CustomerNo);
        Assert.AreEqual(Customer."No.", Company."External Id", 'External id is the customer number.');
        Assert.AreNotEqual(0, Company."Main Contact Customer Id", 'Main contact id.');
        ShopifyCustomer.Get(Company."Main Contact Customer Id");
        Assert.AreEqual(Customer.SystemId, ShopifyCustomer."Customer SystemId", 'Main contact is the customer.');
        CompanyLocation.SetRange("Company SystemId", Company.SystemId);
        Assert.IsTrue(CompanyLocation.FindFirst(), 'Location row.');
        Assert.IsTrue(CompanyLocation.Default, 'Location is the default.');
    end;
}
