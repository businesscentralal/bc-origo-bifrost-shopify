namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Inventory.Item;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Issue 10: mock-only tests exercise the public dispatcher and connector event boundary.</summary>
codeunit 97500 "Shopify Issue 10 Tests ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Fixture: Codeunit "Shpfy AddVariants MCP ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    /// <summary>AC02/AC06: two items are added and the response matches the database increase.</summary>
    [Test]
    procedure AC02_TwoItemsAreAdded()
    var
        Response: JsonObject;
        Results: JsonArray;
        Token: JsonToken;
    begin
        Fixture.Seed();
        Response := Dispatch(ValidRequest());
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Happy path: ' + ReadText(Response, 'error'));
        Assert.AreEqual('2', ReadText(Response, 'variantsAdded'), 'Response count.');
        Assert.AreEqual('2', ReadText(Response, 'itemsRequested'), 'Requested count.');
        Assert.AreEqual('8910000010', ReadText(Response, 'productId'), 'Product.');
        Assert.AreEqual('BIFT10', ReadText(Response, 'shopCode'), 'Derived shop.');
        Assert.AreEqual(2, VariantCount(), 'Database increase.');
        Response.Get('results', Token);
        Results := Token.AsArray();
        Assert.AreEqual(2, Results.Count(), 'Both results present.');
        Assert.AreEqual('Added', ResultText(Results, 0, 'outcome'), 'First added.');
        Assert.AreEqual('BIFT10-B', ResultText(Results, 1, 'itemNo'), 'Second item.');
        Fixture.Cleanup();
    end;

    /// <summary>AC04/AC06: refusal on the second item preserves only the first item and names both.</summary>
    [Test]
    procedure AC04_SecondItemRollsBack()
    var
        Item: Record Item;
        Response: JsonObject;
        Token: JsonToken;
        Results: JsonArray;
    begin
        Fixture.Seed();
        Item.Get('BIFT10-B');
        Item.Blocked := true;
        Item.Modify();
        Commit();
        Response := Dispatch(ValidRequest());
        Assert.AreEqual('BusinessCentralError', ReadText(Response, 'code'), 'Typed connector refusal.');
        Assert.IsTrue(StrPos(ReadText(Response, 'error'), 'Mock connector: item is blocked.') > 0, 'Connector text retained.');
        Assert.AreEqual('1', ReadText(Response, 'variantsAdded'), 'Earlier successful count.');
        Assert.AreEqual(1, VariantCount(), 'Failing item rolled back.');
        Response.Get('results', Token);
        Results := Token.AsArray();
        Assert.AreEqual(2, Results.Count(), 'Processed items named.');
        Assert.AreEqual('Added', ResultText(Results, 0, 'outcome'), 'First stays added.');
        Assert.AreEqual('Refused', ResultText(Results, 1, 'outcome'), 'Second refused.');
        Assert.AreEqual('BIFT10-B', ResultText(Results, 1, 'itemNo'), 'Refused item named.');
        Fixture.Cleanup();
    end;

    /// <summary>AC04: repeating the same item never creates a duplicate.</summary>
    [Test]
    procedure AC04_RepeatIsRefused()
    var
        Response: JsonObject;
    begin
        Fixture.Seed();
        Response := Dispatch(ValidRequest());
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'First request.');
        Response := Dispatch(ValidRequest());
        Assert.AreEqual('BusinessCentralError', ReadText(Response, 'code'), 'Already mapped refusal.');
        Assert.AreEqual('0', ReadText(Response, 'variantsAdded'), 'No added variants on repeat.');
        Assert.AreEqual(2, VariantCount(), 'No duplicate mapping.');
        Fixture.Cleanup();
    end;

    /// <summary>AC04: a normal connector return without a mapping is refused.</summary>
    [Test]
    procedure AC04_NoOpIsRefused()
    var
        Item: Record Item;
        Response: JsonObject;
    begin
        Fixture.Seed();
        Item.Get('BIFT10-A');
        Item.Description := 'NOOP';
        Item.Modify();
        Commit();
        Response := Dispatch(ValidRequest());
        Assert.AreEqual('BusinessCentralError', ReadText(Response, 'code'), 'No-op refusal.');
        Assert.AreEqual(0, VariantCount(), 'No write.');
        Fixture.Cleanup();
    end;

    /// <summary>AC01/AC06: a read-only caller cannot execute the write message.</summary>
    [Test]
    procedure AC01_ReadCallerIsRefused()
    var
        Response: JsonObject;
    begin
        Fixture.Seed();
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        Response := Dispatch(ValidRequest());
        LowerPermissions.StopLoggingNAVPermissions();
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Permission refusal status.');
        Assert.AreEqual('PermissionDenied', ReadText(Response, 'code'), 'Permission refusal code.');
        Assert.AreEqual(0, VariantCount(), 'No write for read caller.');
        Fixture.Cleanup();
    end;

    /// <summary>AC03: MissingProduct is refused before the first write.</summary>
    [Test]
    procedure AC03_MissingProduct()
    begin
        AssertPreflightRefusal('{"itemNos":["BIFT10-A"],"expectedCount":1}', 'MissingParameter');
    end;

    /// <summary>AC03: MissingItems is refused before the first write.</summary>
    [Test]
    procedure AC03_MissingItems()
    begin
        AssertPreflightRefusal('{"productId":8910000010,"expectedCount":1}', 'MissingParameter');
    end;

    /// <summary>AC03: MissingCount is refused before the first write.</summary>
    [Test]
    procedure AC03_MissingCount()
    begin
        AssertPreflightRefusal('{"productId":8910000010,"itemNos":["BIFT10-A"]}', 'MissingParameter');
    end;

    /// <summary>AC03: UnknownKey is refused before the first write.</summary>
    [Test]
    procedure AC03_UnknownKey()
    begin
        AssertPreflightRefusal('{"productId":8910000010,"itemNos":["BIFT10-A"],"expectedCount":1,"bogus":true}', 'UnknownParameter');
    end;

    /// <summary>AC03: MalformedProduct is refused before the first write.</summary>
    [Test]
    procedure AC03_MalformedProduct()
    begin
        AssertPreflightRefusal('{"productId":{},"itemNos":["BIFT10-A"],"expectedCount":1}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: FractionalProduct is refused before the first write.</summary>
    [Test]
    procedure AC03_FractionalProduct()
    begin
        AssertPreflightRefusal('{"productId":1.5,"itemNos":["BIFT10-A"],"expectedCount":1}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: QuotedProduct is refused before the first write.</summary>
    [Test]
    procedure AC03_QuotedProduct()
    begin
        AssertPreflightRefusal('{"productId":"8910000010","itemNos":["BIFT10-A"],"expectedCount":1}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: ZeroProduct is refused before the first write.</summary>
    [Test]
    procedure AC03_ZeroProduct()
    begin
        AssertPreflightRefusal('{"productId":0,"itemNos":["BIFT10-A"],"expectedCount":1}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: MalformedCount is refused before the first write.</summary>
    [Test]
    procedure AC03_MalformedCount()
    begin
        AssertPreflightRefusal('{"productId":8910000010,"itemNos":["BIFT10-A"],"expectedCount":true}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: WrongCount is refused before the first write.</summary>
    [Test]
    procedure AC03_WrongCount()
    begin
        AssertPreflightRefusal('{"productId":8910000010,"itemNos":["BIFT10-A","BIFT10-B"],"expectedCount":1}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: EmptyItems is refused before the first write.</summary>
    [Test]
    procedure AC03_EmptyItems()
    begin
        AssertPreflightRefusal('{"productId":8910000010,"itemNos":[],"expectedCount":1}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: ItemsNotArray is refused before the first write.</summary>
    [Test]
    procedure AC03_ItemsNotArray()
    begin
        AssertPreflightRefusal('{"productId":8910000010,"itemNos":"BIFT10-A","expectedCount":1}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: NullItem is refused before the first write.</summary>
    [Test]
    procedure AC03_NullItem()
    begin
        AssertPreflightRefusal('{"productId":8910000010,"itemNos":[null],"expectedCount":1}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: NumberItem is refused before the first write.</summary>
    [Test]
    procedure AC03_NumberItem()
    begin
        AssertPreflightRefusal('{"productId":8910000010,"itemNos":[1000],"expectedCount":1}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: EmptyItem is refused before the first write.</summary>
    [Test]
    procedure AC03_EmptyItem()
    begin
        AssertPreflightRefusal('{"productId":8910000010,"itemNos":[""],"expectedCount":1}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: LongItem is refused before the first write.</summary>
    [Test]
    procedure AC03_LongItem()
    begin
        AssertPreflightRefusal('{"productId":8910000010,"itemNos":["BIFT10-1234567890123456"],"expectedCount":1}', 'InvalidParameterFormat');
    end;

    /// <summary>AC03: UnknownProduct is refused before the first write.</summary>
    [Test]
    procedure AC03_UnknownProduct()
    begin
        AssertPreflightRefusal('{"productId":8910000011,"itemNos":["BIFT10-A"],"expectedCount":1}', 'RecordNotFound');
    end;

    /// <summary>AC03: UnknownSecondItem is refused before the first write.</summary>
    [Test]
    procedure AC03_UnknownSecondItem()
    begin
        AssertPreflightRefusal('{"productId":8910000010,"itemNos":["BIFT10-A","BIFT10-NOT-FOUND"],"expectedCount":2}', 'RecordNotFound');
    end;

    /// <summary>AC03: an unknown shop is distinct from a disabled shop.</summary>
    [Test]
    procedure AC03_UnknownShop()
    var
        Shop: Record "Shpfy Shop";
        Response: JsonObject;
    begin
        Fixture.Seed();
        Shop.Get('BIFT10');
        Shop.Delete(false);
        Commit();
        Response := Dispatch(ValidRequest());
        Assert.AreEqual('RecordNotFound', ReadText(Response, 'code'), 'Missing shop.');
        Assert.AreEqual(0, VariantCount(), 'No variants.');
        Fixture.Cleanup();
    end;

    /// <summary>AC03/AC05: disabled shop refusals use English and Icelandic translations.</summary>
    [Test]
    procedure AC03_DisabledShopBothLanguages()
    var
        Shop: Record "Shpfy Shop";
        English: JsonObject;
        Icelandic: JsonObject;
    begin
        Fixture.Seed();
        Shop.Get('BIFT10');
        Shop.Enabled := false;
        Shop.Modify();
        Commit();
        English := DispatchLcid(ValidRequest(), 1033);
        Icelandic := DispatchLcid(ValidRequest(), 1039);
        Assert.AreEqual('PreconditionFailed', ReadText(English, 'code'), 'English refusal.');
        Assert.AreEqual('PreconditionFailed', ReadText(Icelandic, 'code'), 'Icelandic refusal.');
        Assert.AreNotEqual(ReadText(English, 'error'), ReadText(Icelandic, 'error'), 'Translated message.');
        Assert.AreNotEqual(ReadText(English, 'nextStep'), ReadText(Icelandic, 'nextStep'), 'Translated next step.');
        Assert.AreEqual(0, VariantCount(), 'No variants.');
        Fixture.Cleanup();
    end;

    /// <summary>AC03: the exact upper boundary of 100 items succeeds; 101 is refused before any write.</summary>
    [Test]
    procedure AC03_CountBoundaries()
    var
        Request: JsonObject;
        Response: JsonObject;
        Items: JsonArray;
        Index: Integer;
        ItemNo: Code[20];
        RequestText: Text;
    begin
        Fixture.Seed();
        for Index := 1 to 100 do begin
            ItemNo := CopyStr('BIFT10-' + Format(Index, 0, 9), 1, MaxStrLen(ItemNo));
            Fixture.AddItem(ItemNo);
            Items.Add(ItemNo);
        end;
        Commit();
        Request.Add('productId', 8910000010L);
        Request.Add('itemNos', Items);
        Request.Add('expectedCount', 100);
        Request.WriteTo(RequestText);
        Response := Dispatch(RequestText);
        Assert.AreEqual('Success', ReadText(Response, 'status'), '100 items accepted.');
        Assert.AreEqual(100, VariantCount(), '100 variants.');
        Fixture.Cleanup();
        Fixture.Seed();
        Items.Add('BIFT10-A');
        Request.Replace('itemNos', Items);
        Request.Replace('expectedCount', 101);
        Request.WriteTo(RequestText);
        Response := Dispatch(RequestText);
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), '101 items refused.');
        Assert.AreEqual(0, VariantCount(), 'Oversize request changes nothing.');
        Fixture.Cleanup();
    end;

    /// <summary>AC02: XML and filter characters in an item number select only that literal item.</summary>
    [Test]
    procedure AC02_LiteralItemFilter()
    var
        Response: JsonObject;
    begin
        Fixture.Seed();
        Fixture.AddItem('BIFT10&<|*');
        Commit();
        Response := Dispatch('{"productId":8910000010,"itemNos":["BIFT10&<|*"],"expectedCount":1}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Literal special-character item.');
        Assert.AreEqual(1, VariantCount(), 'Exactly one variant.');
        Fixture.Cleanup();
    end;

    local procedure AssertPreflightRefusal(RequestText: Text; ExpectedCode: Text)
    var
        Response: JsonObject;
    begin
        Fixture.Seed();
        Response := Dispatch(RequestText);
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Refusal status.');
        Assert.AreEqual(ExpectedCode, ReadText(Response, 'code'), 'Refusal code: ' + ReadText(Response, 'error'));
        Assert.AreEqual(0, VariantCount(), 'All inputs checked before writes.');
        Fixture.Cleanup();
    end;

    local procedure VariantCount(): Integer
    var
        Variant: Record "Shpfy Variant";
    begin
        Variant.SetRange("Product Id", 8910000010L);
        exit(Variant.Count());
    end;

    local procedure ValidRequest(): Text
    begin
        exit('{"productId":8910000010,"itemNos":["BIFT10-A","BIFT10-B"],"expectedCount":2}');
    end;

    local procedure Dispatch(RequestText: Text) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ContentType: Text[100];
        Version: Enum "Message Version ori";
        ResponseText: Text;
    begin
        RequestContent.AddText(RequestText);
        Dispatcher.Execute("Message Type ori"::"Shopify.Product.AddItemsAsVariants", Version, '', '', 'application/json', RequestContent, ResponseContent, ContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        Response.ReadFrom(ResponseText);
    end;

    local procedure DispatchLcid(RequestText: Text; LanguageId: Integer) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ContentType: Text[100];
        Version: Enum "Message Version ori";
        EmptyTaskId: Guid;
        MessageId: Guid;
        ResponseTime: Duration;
        ResponseText: Text;
    begin
        // Execute uses Foundation's default language. This public entry point takes an explicit LCID.
        RequestContent.AddText(RequestText);
        Dispatcher.EnqueueAndProcess("Message Type ori"::"Shopify.Product.AddItemsAsVariants", Version, '', '', 'application/json', RequestContent, EmptyTaskId, LanguageId, MessageId, ResponseContent, ContentType, ResponseTime);
        ResponseContent.GetSubText(ResponseText, 1);
        Response.ReadFrom(ResponseText);
    end;

    local procedure ReadText(Response: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        if Response.Get(Name, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure ResultText(Results: JsonArray; Index: Integer; Name: Text): Text
    var
        Token: JsonToken;
    begin
        Results.Get(Index, Token);
        exit(ReadText(Token.AsObject(), Name));
    end;
}
