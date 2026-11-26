namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;

/// <summary>
/// Runs the Shopify connector report Shpfy Add Item to Shopify (30106), the code behind the action Add Items on Shopify Products,
/// for one shop and a selection of items, without its request page. Images and inventory are not synced (both options off).
/// The caller starts this codeunit with Run in an if statement, so a failure rolls back what was written after the
/// connector's own commit.
/// </summary>
codeunit 73732041 "Product AddItems Run ori"
{
    Access = Internal;

    var
        ShopCode: Code[20];
        ItemView: Text;

    trigger OnRun()
    var
        IsHandled: Boolean;
        ParametersTxt: Label '<?xml version="1.0" standalone="yes"?><ReportParameters name="Shpfy Add Item to Shopify" id="30106"><Options><Field name="ShopCode">%1</Field><Field name="SyncImages">false</Field><Field name="SyncInventory">false</Field></Options><DataItems><DataItem name="Item">%2</DataItem></DataItems></ReportParameters>', Locked = true;
    begin
        OnBeforeRunAddItemReport(ShopCode, ItemView, IsHandled);
        if IsHandled then
            exit;
        Report.Execute(Report::"Shpfy Add Item to Shopify", StrSubstNo(ParametersTxt, XmlEscape(ShopCode), XmlEscape(ItemView)));
    end;

    /// <summary>Sets the shop and the item view the report runs for.</summary>
    /// <param name="NewShopCode">The Shopify shop code.</param>
    /// <param name="NewItemView">The view of table Item that selects the items.</param>
    procedure SetParameters(NewShopCode: Code[20]; NewItemView: Text)
    begin
        ShopCode := NewShopCode;
        ItemView := NewItemView;
    end;

    /// <summary>Escapes a value for an XML text node.</summary>
    local procedure XmlEscape(Value: Text): Text
    begin
        exit(Value.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;'));
    end;

    /// <summary>Raised before the connector report runs. The test app handles it to stand in for the live Shopify API.</summary>
    /// <param name="ForShopCode">The Shopify shop code.</param>
    /// <param name="ForItemView">The view of table Item that selects the items.</param>
    /// <param name="IsHandled">Set to true to skip the report.</param>
    [IntegrationEvent(false, false)]
    internal procedure OnBeforeRunAddItemReport(ForShopCode: Code[20]; ForItemView: Text; var IsHandled: Boolean)
    begin
    end;
}
