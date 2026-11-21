namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.Customer;
using Origo.Bifrost.Shopify;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Issue #16: Shopify.Customer.Sync request validation, synchronization, Business Central refusals and permissions.</summary>
codeunit 97450 "Shpfy Cust Sync Test ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        ShopCodeTok: Label 'BIFT16', Locked = true;

    /// <summary>A request without shopCode is refused with MissingParameter and changes nothing.</summary>
    [Test]
    procedure MissingKeyIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := ExecuteRaw('{}');
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Missing key status.');
        Assert.AreEqual('MissingParameter', ReadText(Response, 'code'), 'Missing key code.');
        Assert.AreEqual('shopCode', ReadText(Response, 'parameter'), 'Missing key parameter.');
    end;

    /// <summary>An unknown key is refused as UnknownParameter and changes nothing.</summary>
    [Test]
    procedure UnknownKeyIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := ExecuteRaw('{"shopCode":"X","bogus":true}');
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Unknown key status.');
        Assert.AreEqual('UnknownParameter', ReadText(Response, 'code'), 'Unknown key code.');
    end;

    /// <summary>A shopCode that is empty or longer than a shop code is refused as InvalidParameterFormat.</summary>
    [Test]
    procedure InvalidShopCodeIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := ExecuteRaw('{"shopCode":""}');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), 'Empty code.');
        Response := ExecuteRaw('{"shopCode":"ABCDEFGHIJKLMNOPQRSTU"}');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), 'Too long code.');
    end;

    /// <summary>A shop that does not exist is refused with RecordNotFound.</summary>
    [Test]
    procedure UnknownShopIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := ExecuteRaw('{"shopCode":"NOSUCHSHOP"}');
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Unknown shop status.');
        Assert.AreEqual('RecordNotFound', ReadText(Response, 'code'), 'Unknown shop code.');
    end;

    /// <summary>A shop that is not enabled is refused before anything is synchronized.</summary>
    [Test]
    procedure DisabledShopIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Seed(false, "Shpfy Customer Import Range"::None, false);
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '"}');
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), 'Disabled shop code.');
        Cleanup();
    end;

    /// <summary>The happy path runs the connector sync for a shop that neither imports nor updates customers and reports its setup.</summary>
    [Test]
    procedure SyncRunsForEnabledShop()
    var
        Response: JsonObject;
    begin
        Initialize();
        Seed(true, "Shpfy Customer Import Range"::None, false);
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '"}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Sync status: ' + ReadText(Response, 'message'));
        Assert.AreEqual(ShopCodeTok, ReadText(Response, 'shopCode'), 'Shop code.');
        Assert.AreEqual('None', ReadText(Response, 'customerImportFromShopify'), 'Import setting.');
        Assert.AreEqual('false', ReadText(Response, 'canUpdateShopifyCustomer'), 'Update setting.');
        // Idempotent: a second call is accepted as well.
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '"}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Second call status.');
        Cleanup();
    end;

    /// <summary>A shop that imports customers but has no connection to Shopify is refused by the connector as a business refusal.</summary>
    [Test]
    procedure BusinessCentralRefusalIsReturned()
    var
        Response: JsonObject;
    begin
        Initialize();
        Seed(true, "Shpfy Customer Import Range"::AllCustomers, false);
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '"}');
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Refusal status.');
        Assert.AreEqual('BusinessCentralError', ReadText(Response, 'code'), 'Refusal code.');
        Cleanup();
    end;

    /// <summary>The refusal is also returned when the language is Icelandic.</summary>
    [Test]
    procedure BusinessCentralRefusalIsReturnedIcelandic()
    var
        Response: JsonObject;
        PreviousLanguage: Integer;
    begin
        Initialize();
        Seed(true, "Shpfy Customer Import Range"::AllCustomers, false);
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1039);
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '"}');
        GlobalLanguage(PreviousLanguage);
        Assert.AreEqual('BusinessCentralError', ReadText(Response, 'code'), 'Refusal code in Icelandic.');
        Cleanup();
    end;

    /// <summary>A caller without the app permissions is refused.</summary>
    [Test]
    procedure CallerWithoutPermissionIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Seed(true, "Shpfy Customer Import Range"::None, false);
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '"}');
        LowerPermissions.StopLoggingNAVPermissions();
        Assert.AreNotEqual('Success', ReadText(Response, 'status'), 'Caller without permission must be refused.');
        Cleanup();
    end;

    /// <summary>
    /// AC04: after a successful customer, a failed update of a mapped customer and a failed creation of a new one are not hidden
    /// by the connector: the dispatcher answers BusinessCentralError naming those two Shopify customers and not the good one.
    /// </summary>
    [Test]
    procedure FailedMappedUpdateAfterSuccessIsReported()
    var
        Stub: Codeunit "Shpfy Cust Sync Stub ori";
        Response: JsonObject;
        Message: Text;
    begin
        Initialize();
        SeedImportShop("Shpfy Customer Import Range"::AllCustomers, true, true);
        InsertShopifyCustomer(1600001, InsertCustomer('BIFT16A'));
        InsertShopifyCustomer(1600002, InsertCustomer('BIFT16B'));
        // An unmapped customer the import does not handle in this call is not judged.
        InsertShopifyCustomer(1600004, EmptyGuid());
        Commit();
        Sleep(50);
        BindSubscription(Stub);
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '"}');
        UnbindSubscription(Stub);
        Message := ReadText(Response, 'error');
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'A failed customer must not answer Success: ' + Message);
        Assert.AreEqual('BusinessCentralError', ReadText(Response, 'code'), 'Failure code.');
        Assert.IsTrue(Message.Contains('1600002'), 'The failed update must be named: ' + Message);
        Assert.IsTrue(Message.Contains('1600003'), 'The failed creation must be named: ' + Message);
        Assert.IsFalse(Message.Contains('1600001'), 'The updated customer is not a failure: ' + Message);
        Assert.IsFalse(Message.Contains('1600004'), 'A customer the import did not handle is not a failure: ' + Message);
        Assert.AreEqual('IU', Stub.GetPasses(), 'The import pass runs first without the update, then the update pass without the import.');
        Cleanup();
    end;

    /// <summary>
    /// The stand-in connector updates customer 1, modifies the mapped Business Central customer of customer 2 and then fails
    /// in a later step, so that write is rolled back, and updates customer 5 afterwards (which clears the last error, as the
    /// connector does). The rolled-back write is not counted as an update: the answer names customer 2 only.
    /// </summary>
    [Test]
    procedure RolledBackWriteAfterSuccessIsReported()
    var
        Customer: Record Customer;
        Message: Text;
    begin
        Initialize();
        SeedImportShop("Shpfy Customer Import Range"::AllCustomers, true, true);
        InsertShopifyCustomer(1600001, InsertCustomer('BIFT16A'));
        InsertShopifyCustomer(1600002, InsertCustomer('BIFT16B'));
        InsertShopifyCustomer(1600005, InsertCustomer('BIFT16C'));
        Commit();
        Sleep(50);
        Message := ExecuteScenarioExpectingError('ROLLBACK');
        Assert.IsTrue(Message.Contains('1600002'), 'The rolled-back update must be named: ' + Message);
        Assert.IsFalse(Message.Contains('1600001'), 'The updated customer 1 is not a failure: ' + Message);
        Assert.IsFalse(Message.Contains('1600005'), 'The updated customer 5 is not a failure: ' + Message);
        Customer.Get('BIFT16B');
        Assert.AreNotEqual('Bifrost Shopify updated', Customer.Name, 'The failed write must have been rolled back.');
        Customer.Get('BIFT16C');
        Assert.AreEqual('Bifrost Shopify updated', Customer.Name, 'Customer 5 was updated.');
        Assert.IsTrue(MarkersRemoved(), 'The call removes its markers.');
        Cleanup();
    end;

    /// <summary>
    /// The stand-in connector updates customer 1, inserts the row of the new Shopify customer 3 and deletes it again because
    /// its retrieval failed (as the connector does), then updates customer 5. The answer names customer 3.
    /// </summary>
    [Test]
    procedure FailedRetrievalOfNewCustomerIsReported()
    var
        Message: Text;
    begin
        Initialize();
        SeedImportShop("Shpfy Customer Import Range"::AllCustomers, true, true);
        InsertShopifyCustomer(1600001, InsertCustomer('BIFT16A'));
        InsertShopifyCustomer(1600005, InsertCustomer('BIFT16C'));
        Commit();
        Sleep(50);
        Message := ExecuteScenarioExpectingError('RETRIEVE');
        Assert.IsTrue(Message.Contains('1600003'), 'The new customer whose retrieval failed must be named: ' + Message);
        Assert.IsFalse(Message.Contains('1600001'), 'The updated customer 1 is not a failure: ' + Message);
        Assert.IsFalse(Message.Contains('1600005'), 'The updated customer 5 is not a failure: ' + Message);
        Assert.IsTrue(MarkersRemoved(), 'The call removes its markers.');
        Cleanup();
    end;

    /// <summary>
    /// The stand-in connector updates customer 1, then the retrieval of the existing customer 2 fails before anything is
    /// written, and it is the last customer, so only the connector's last error is left. The answer is BusinessCentralError
    /// with that error, not Success.
    /// </summary>
    [Test]
    procedure FailedRetrievalLeftAsLastErrorIsReported()
    var
        Message: Text;
    begin
        Initialize();
        SeedImportShop("Shpfy Customer Import Range"::AllCustomers, true, true);
        InsertShopifyCustomer(1600001, InsertCustomer('BIFT16A'));
        InsertShopifyCustomer(1600002, InsertCustomer('BIFT16B'));
        Commit();
        Sleep(50);
        Message := ExecuteScenarioExpectingError('LASTERROR');
        Assert.IsTrue(Message.Contains('could not import or update a Shopify customer'), 'The connector error must be reported: ' + Message);
        Assert.IsTrue(Message.Contains('retrieval of the Shopify customer failed'), 'The connector error text must be included: ' + Message);
        Assert.IsTrue(MarkersRemoved(), 'The call removes its markers.');
        Cleanup();
    end;

    local procedure ExecuteScenarioExpectingError(Scenario: Text) Message: Text
    var
        Stub: Codeunit "Shpfy Cust Sync Stub ori";
        Response: JsonObject;
    begin
        Stub.SetScenario(Scenario);
        BindSubscription(Stub);
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '"}');
        UnbindSubscription(Stub);
        Message := ReadText(Response, 'error');
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'A failed customer must not answer Success: ' + Message);
        Assert.AreEqual('BusinessCentralError', ReadText(Response, 'code'), 'Failure code.');
        Assert.AreEqual('IU', Stub.GetPasses(), 'Import pass first, then the update pass.');
    end;

    local procedure MarkersRemoved(): Boolean
    var
        Marker: Record "Customer Sync Marker ori";
    begin
        exit(Marker.IsEmpty());
    end;

    /// <summary>
    /// With Customer Import From Shopify = WithOrderImport and Shopify Can Update Customer off the connector does not import
    /// customers, so an existing unmapped Shopify customer is not a failure of this call (real connector, no Shopify call).
    /// </summary>
    [Test]
    procedure SkippedImportIsNotAFailure()
    var
        Response: JsonObject;
    begin
        Initialize();
        SeedImportShop("Shpfy Customer Import Range"::WithOrderImport, false, false);
        InsertShopifyCustomer(1600004, EmptyGuid());
        Commit();
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '"}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'No import ran, so nothing failed: ' + ReadText(Response, 'message'));
        Assert.AreEqual('WithOrderImport', ReadText(Response, 'customerImportFromShopify'), 'Import setting.');
        Cleanup();
    end;

    local procedure SeedImportShop(ImportRange: Enum "Shpfy Customer Import Range"; ShopifyCanUpdate: Boolean; CanUpdateShopify: Boolean)
    var
        Shop: Record "Shpfy Shop";
    begin
        Seed(true, ImportRange, CanUpdateShopify);
        Shop.Get(ShopCodeTok);
        Shop."Auto Create Unknown Customers" := true;
        Shop."Shopify Can Update Customer" := ShopifyCanUpdate;
        Shop."Shop Id" := 16016;
        Shop.Modify();
    end;

    local procedure InsertCustomer(CustomerNo: Code[20]): Guid
    var
        Customer: Record Customer;
    begin
        Customer.Init();
        Customer."No." := CustomerNo;
        Customer.Insert();
        exit(Customer.SystemId);
    end;

    local procedure InsertShopifyCustomer(Id: BigInteger; CustomerSystemId: Guid)
    var
        ShopifyCustomer: Record "Shpfy Customer";
    begin
        ShopifyCustomer.Init();
        ShopifyCustomer.Id := Id;
        ShopifyCustomer."Shop Id" := 16016;
        ShopifyCustomer."Customer SystemId" := CustomerSystemId;
        ShopifyCustomer.Insert();
    end;

    local procedure EmptyGuid(): Guid
    var
        NoGuid: Guid;
    begin
        exit(NoGuid);
    end;

    local procedure Initialize()
    begin
        Cleanup();
    end;

    local procedure Seed(Enabled: Boolean; ImportRange: Enum "Shpfy Customer Import Range"; CanUpdate: Boolean)
    var
        Shop: Record "Shpfy Shop";
    begin
        Shop.Init();
        Shop.Code := CopyStr(ShopCodeTok, 1, MaxStrLen(Shop.Code));
        Shop.Insert();
        Shop.Enabled := Enabled;
        Shop."Customer Import From Shopify" := ImportRange;
        Shop."Can Update Shopify Customer" := CanUpdate;
        Shop.Modify();
        Commit();
    end;

    local procedure Cleanup()
    var
        Customer: Record Customer;
        ShopifyCustomer: Record "Shpfy Customer";
        Shop: Record "Shpfy Shop";
    begin
        ShopifyCustomer.SetRange("Shop Id", 16016);
        ShopifyCustomer.DeleteAll();
        Customer.SetFilter("No.", 'BIFT16A|BIFT16B|BIFT16C');
        Customer.DeleteAll();
        if Shop.Get(ShopCodeTok) then begin
            Shop.Enabled := false;
            Shop.Modify();
            Shop.Delete(true);
        end;
        Commit();
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
        Dispatcher.Execute("Message Type ori"::"Shopify.Customer.Sync", MessageVersion, '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType);
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
