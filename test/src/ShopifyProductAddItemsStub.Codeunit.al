namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Inventory.Item;
using Origo.Bifrost.Shopify;

/// <summary>
/// Issue #7: stands in for the live Shopify API of report Shpfy Add Item to Shopify. Bound manually; stores a Shopify product
/// for every selected item that has none in the shop, as the connector does after Shopify created the product.
/// </summary>
codeunit 97491 "Shpfy AddItems Stub ori"
{
    EventSubscriberInstance = Manual;

    var
        NextProductId: BigInteger;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Product AddItems Run ori", 'OnBeforeRunAddItemReport', '', false, false)]
    local procedure HandleAddItemReport(ForShopCode: Code[20]; ForItemView: Text; var IsHandled: Boolean)
    var
        Item: Record Item;
        Product: Record "Shpfy Product";
    begin
        Item.SetView(ForItemView);
        if Item.FindSet() then
            repeat
                Product.Reset();
                Product.SetRange("Shop Code", ForShopCode);
                Product.SetRange("Item SystemId", Item.SystemId);
                if Product.IsEmpty() and not Item.Blocked then begin
                    if NextProductId = 0 then
                        NextProductId := 974900001;
                    Product.Init();
                    Product.Id := NextProductId;
                    Product."Shop Code" := ForShopCode;
                    Product."Item SystemId" := Item.SystemId;
                    Product.Title := Item.Description;
                    Product.Insert();
                    NextProductId += 1;
                end;
            until Item.Next() = 0;
        IsHandled := true;
    end;
}
