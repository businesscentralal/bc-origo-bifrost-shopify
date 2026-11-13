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

    /// <summary>A failed customer import after a successful one is detected: the connector hides it, the result check reports it.</summary>
    [Test]
    procedure FailedCustomerImportIsCounted()
    var
        Shop: Record "Shpfy Shop";
        Customer: Record Customer;
        Impl: Codeunit "Customer Sync Impl ori";
    begin
        Initialize();
        Seed(true, "Shpfy Customer Import Range"::AllCustomers, false);
        Shop.Get(ShopCodeTok);
        Shop."Auto Create Unknown Customers" := true;
        Shop."Shop Id" := 16016;
        Shop.Modify();
        // Mock: customer 1 was imported (mapped to a Business Central customer), customer 2 failed (no Business Central customer).
        Customer.Init();
        Customer."No." := 'BIFT16C';
        Customer.Insert();
        InsertShopifyCustomer(1600001, Customer.SystemId);
        InsertShopifyCustomer(1600002, EmptyGuid());
        Assert.AreEqual(1, Impl.CountUnmappedImports(Shop), 'The failed customer must be counted and the imported one not.');
        // A shop that does not create unknown customers does not expect a mapping, so nothing is a failure.
        Shop."Auto Create Unknown Customers" := false;
        Assert.AreEqual(0, Impl.CountUnmappedImports(Shop), 'No failure without Auto Create Unknown Customers.');
        // A shop that imports no customers has nothing that failed.
        Shop."Auto Create Unknown Customers" := true;
        Shop."Customer Import From Shopify" := "Shpfy Customer Import Range"::None;
        Assert.AreEqual(0, Impl.CountUnmappedImports(Shop), 'No failure when no customers are imported.');
        Cleanup();
    end;

    /// <summary>The detailed help chapters are translated: in Icelandic they differ from the English text.</summary>
    [Test]
    procedure HelpChaptersAreTranslated()
    var
        Impl: Codeunit "Customer Sync Impl ori";
        EnglishOverview: Text;
        EnglishNotes: Text;
        IcelandicOverview: Text;
        IcelandicNotes: Text;
        EnglishParameters: JsonArray;
        IcelandicParameters: JsonArray;
        EnglishErrors: JsonArray;
        IcelandicErrors: JsonArray;
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        Impl.GetOverview(EnglishOverview);
        Impl.GetNotes(EnglishNotes);
        Impl.GetParameters(EnglishParameters);
        Impl.GetErrors(EnglishErrors);
        GlobalLanguage(1039);
        Impl.GetOverview(IcelandicOverview);
        Impl.GetNotes(IcelandicNotes);
        Impl.GetParameters(IcelandicParameters);
        Impl.GetErrors(IcelandicErrors);
        GlobalLanguage(PreviousLanguage);
        Assert.AreNotEqual(EnglishOverview, IcelandicOverview, 'Overview must be translated.');
        Assert.AreNotEqual(EnglishNotes, IcelandicNotes, 'Notes must be translated.');
        Assert.AreNotEqual(Format(EnglishParameters), Format(IcelandicParameters), 'Parameters must be translated.');
        Assert.AreNotEqual(Format(EnglishErrors), Format(IcelandicErrors), 'Errors must be translated.');
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

    local procedure EmptyGuid() NoGuid: Guid
    begin
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
        if Customer.Get('BIFT16C') then
            Customer.Delete();
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
