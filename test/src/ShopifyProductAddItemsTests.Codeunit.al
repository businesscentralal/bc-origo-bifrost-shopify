namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Inventory.Item;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue #7: Shopify.Product.AddItems. The live Shopify API cannot be reached from a container: the happy path runs with the
/// stand-in 97491 in place of the report's Shopify calls; the connector report itself runs for skipped items and for the
/// Business Central refusal; the request refusals and the permission check run against the real type.
/// </summary>
codeunit 97490 "Shpfy Prod AddItems Test ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        ShopCodeTok: Label 'BIFT7', Locked = true;
        ItemATok: Label 'BIFT7-A', Locked = true;
        ItemBTok: Label 'BIFT7&B|(1)', Locked = true;
        ItemBlockedTok: Label 'BIFT7-BLK', Locked = true;

    /// <summary>Two new items and one already in the shop: the new ones are added, the existing one is left as it is.</summary>
    [Test]
    procedure AddsNewItemsAndKeepsExisting()
    var
        Product: Record "Shpfy Product";
        Stub: Codeunit "Shpfy AddItems Stub ori";
        Response: JsonObject;
        Entry: JsonObject;
        ExistingId: BigInteger;
    begin
        Initialize();
        SeedShop(true);
        SeedItem(ItemATok, false);
        SeedItem(ItemBTok, false);
        SeedItem(ItemBlockedTok, false);
        ExistingId := SeedProduct(ItemBlockedTok);
        BindSubscription(Stub);
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '","itemNos":["' + ItemATok + '","' + ItemBTok + '","' + ItemBlockedTok + '","' + LowerCase(ItemATok) + '"]}');
        UnbindSubscription(Stub);
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Success status.');
        Assert.AreEqual(ShopCodeTok, ReadText(Response, 'shopCode'), 'Shop code echoed.');
        Assert.AreEqual('2', ReadText(Response, 'itemsAdded'), 'Two items added; the duplicate is counted once.');
        Assert.AreEqual(3, ItemsOf(Response).Count(), 'One entry per distinct item.');
        Entry := ItemEntry(Response, ItemBTok);
        Assert.AreEqual('Added', ReadText(Entry, 'result'), 'Item with filter characters is added.');
        Assert.AreNotEqual('0', ReadText(Entry, 'productId'), 'Added item has a product.');
        Entry := ItemEntry(Response, ItemBlockedTok);
        Assert.AreEqual('AlreadyInShop', ReadText(Entry, 'result'), 'Existing product is reported.');
        Assert.AreEqual(Format(ExistingId), ReadText(Entry, 'productId'), 'Existing product ID.');
        Product.SetRange("Shop Code", ShopCodeTok);
        Assert.AreEqual(3, Product.Count(), 'Exactly two products were added to the one that existed.');
        Cleanup();
    end;

    /// <summary>A blocked item runs through the connector report, which skips and logs it: Success with result NotAdded.</summary>
    [Test]
    procedure BlockedItemIsSkippedByConnector()
    var
        Product: Record "Shpfy Product";
        Response: JsonObject;
    begin
        Initialize();
        SeedShop(true);
        SeedItem(ItemBlockedTok, true);
        Response := Execute(ShopCodeTok, ItemBlockedTok);
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Success status: ' + ReadText(Response, 'error'));
        Assert.AreEqual('0', ReadText(Response, 'itemsAdded'), 'Nothing added.');
        Assert.AreEqual('NotAdded', ReadText(ItemEntry(Response, ItemBlockedTok), 'result'), 'Blocked item is not added.');
        Product.SetRange("Shop Code", ShopCodeTok);
        Assert.IsTrue(Product.IsEmpty(), 'No product stored.');
        Cleanup();
    end;

    /// <summary>An item the connector must send to Shopify, which a container cannot reach: Business Central's refusal is returned and no product is kept.</summary>
    [Test]
    procedure ConnectorRefusalIsReturned()
    var
        Product: Record "Shpfy Product";
        Response: JsonObject;
    begin
        Initialize();
        SeedShop(true);
        SeedItem(ItemATok, false);
        Response := Execute(ShopCodeTok, ItemATok);
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Refusal status.');
        Assert.AreEqual('BusinessCentralError', ReadText(Response, 'code'), 'Refusal code.');
        Product.SetRange("Shop Code", ShopCodeTok);
        Assert.IsTrue(Product.IsEmpty(), 'No product kept after the refusal.');
        Cleanup();
    end;

    /// <summary>A request without itemNos is refused with MissingParameter and changes nothing.</summary>
    [Test]
    procedure MissingItemNosIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '"}');
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Missing key status.');
        Assert.AreEqual('MissingParameter', ReadText(Response, 'code'), 'Missing key code.');
        Assert.AreEqual('itemNos', ReadText(Response, 'parameter'), 'Missing key parameter.');
    end;

    /// <summary>A request without shopCode is refused with MissingParameter.</summary>
    [Test]
    procedure MissingShopCodeIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := ExecuteRaw('{"itemNos":["X"]}');
        Assert.AreEqual('MissingParameter', ReadText(Response, 'code'), 'Missing key code.');
        Assert.AreEqual('shopCode', ReadText(Response, 'parameter'), 'Missing key parameter.');
    end;

    /// <summary>itemNos that is not an array, or an empty array, is refused with InvalidParameterFormat.</summary>
    [Test]
    procedure InvalidItemNosIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '","itemNos":"' + ItemATok + '"}');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), 'Text instead of array.');
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '","itemNos":[]}');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), 'Empty array.');
    end;

    /// <summary>An unknown key is refused as UnknownParameter.</summary>
    [Test]
    procedure UnknownKeyIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        Response := ExecuteRaw('{"shopCode":"X","itemNos":["X"],"bogus":true}');
        Assert.AreEqual('UnknownParameter', ReadText(Response, 'code'), 'Unknown key code.');
    end;

    /// <summary>An unknown item is refused as RecordNotFound before anything changes.</summary>
    [Test]
    procedure UnknownItemIsRefused()
    var
        Product: Record "Shpfy Product";
        Response: JsonObject;
    begin
        Initialize();
        SeedShop(true);
        SeedItem(ItemATok, false);
        Response := ExecuteRaw('{"shopCode":"' + ShopCodeTok + '","itemNos":["' + ItemATok + '","BIFT7-NONE"]}');
        Assert.AreEqual('RecordNotFound', ReadText(Response, 'code'), 'Unknown item code.');
        Assert.AreEqual('itemNos', ReadText(Response, 'parameter'), 'Unknown item parameter.');
        Product.SetRange("Shop Code", ShopCodeTok);
        Assert.IsTrue(Product.IsEmpty(), 'Nothing added.');
        Cleanup();
    end;

    /// <summary>An unknown shop is refused as RecordNotFound; a disabled shop as PreconditionFailed.</summary>
    [Test]
    procedure UnknownOrDisabledShopIsRefused()
    var
        Response: JsonObject;
    begin
        Initialize();
        SeedItem(ItemATok, false);
        Response := Execute('BIFT7-NONE', ItemATok);
        Assert.AreEqual('RecordNotFound', ReadText(Response, 'code'), 'Unknown shop code.');
        SeedShop(false);
        Response := Execute(ShopCodeTok, ItemATok);
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), 'Disabled shop code.');
        Cleanup();
    end;

    /// <summary>A caller without the app permissions is refused and nothing runs.</summary>
    [Test]
    procedure CallerWithoutPermissionIsRefused()
    var
        Product: Record "Shpfy Product";
        Response: JsonObject;
    begin
        Initialize();
        SeedShop(true);
        SeedItem(ItemATok, false);
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        Response := Execute(ShopCodeTok, ItemATok);
        LowerPermissions.StopLoggingNAVPermissions();
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Caller without permission must be refused.');
        Product.SetRange("Shop Code", ShopCodeTok);
        Assert.IsTrue(Product.IsEmpty(), 'Nothing added.');
        Cleanup();
    end;

    local procedure Initialize()
    begin
        Cleanup();
    end;

    local procedure SeedShop(Enabled: Boolean)
    var
        Shop: Record "Shpfy Shop";
    begin
        if not Shop.Get(ShopCodeTok) then begin
            Shop.Init();
            Shop.Code := ShopCodeTok;
            Shop.Insert();
        end;
        Shop.Enabled := Enabled;
        Shop.Modify();
        Commit();
    end;

    local procedure SeedItem(ItemNo: Code[20]; IsBlocked: Boolean)
    var
        Item: Record Item;
    begin
        Item.Init();
        Item."No." := ItemNo;
        Item.Description := 'Bifrost test item ' + ItemNo;
        Item.Blocked := IsBlocked;
        Item.Insert();
        Commit();
    end;

    local procedure SeedProduct(ItemNo: Code[20]): BigInteger
    var
        Item: Record Item;
        Product: Record "Shpfy Product";
    begin
        Item.Get(ItemNo);
        Product.Init();
        Product.Id := 974909999;
        Product."Shop Code" := ShopCodeTok;
        Product."Item SystemId" := Item.SystemId;
        Product.Insert();
        Commit();
        exit(Product.Id);
    end;

    local procedure Cleanup()
    var
        Shop: Record "Shpfy Shop";
        Product: Record "Shpfy Product";
    begin
        Product.SetRange("Shop Code", ShopCodeTok);
        Product.DeleteAll();
        DeleteItem(ItemATok);
        DeleteItem(ItemBTok);
        DeleteItem(ItemBlockedTok);
        if Shop.Get(ShopCodeTok) then
            Shop.Delete(true);
        Commit();
    end;

    /// <summary>Deletes the test item and the Shopify Skipped Records the connector logged for it (internal table 30159, field 5 Record ID).</summary>
    local procedure DeleteItem(ItemNo: Code[20])
    var
        Item: Record Item;
        SkippedRecord: RecordRef;
        RecordIdField: FieldRef;
    begin
        if not Item.Get(ItemNo) then
            exit;
        SkippedRecord.Open(30159);
        RecordIdField := SkippedRecord.Field(5);
        RecordIdField.SetRange(Item.RecordId);
        SkippedRecord.DeleteAll();
        SkippedRecord.Close();
        Item.Delete();
    end;

    local procedure Execute(ShopCode: Text; ItemNo: Text): JsonObject
    begin
        exit(ExecuteRaw('{"shopCode":"' + ShopCode + '","itemNos":["' + ItemNo + '"]}'));
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
        Dispatcher.Execute("Message Type ori"::"Shopify.Product.AddItems", MessageVersion, '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        ResponseJson.ReadFrom(ResponseText);
    end;

    local procedure ItemsOf(Response: JsonObject): JsonArray
    var
        Token: JsonToken;
    begin
        Response.Get('items', Token);
        exit(Token.AsArray());
    end;

    local procedure ItemEntry(Response: JsonObject; ItemNo: Text): JsonObject
    var
        Token: JsonToken;
    begin
        foreach Token in ItemsOf(Response) do
            if ReadText(Token.AsObject(), 'itemNo') = ItemNo then
                exit(Token.AsObject());
        Assert.Fail('No entry for item ' + ItemNo);
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
