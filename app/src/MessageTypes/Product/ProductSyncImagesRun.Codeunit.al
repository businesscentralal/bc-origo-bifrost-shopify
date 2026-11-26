namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;

/// <summary>
/// Runs the Shopify connector report Shpfy Sync Images (30107), the code behind the action Sync Images on Shopify Products,
/// for one shop and an optional product Id filter, without its request page. The report runs the connector's codeunit
/// Shpfy Sync Product Image, which exports item pictures (Sync Item Images = To Shopify) or imports product images
/// (From Shopify). The caller starts this codeunit with Run in an if statement, so a failure rolls back what was written
/// after the connector's own commits.
/// </summary>
codeunit 73732101 "Product SyncImages Run ori"
{
    Access = Internal;

    var
        ShopCode: Code[20];
        ProductIdFilter: Text;

    trigger OnRun()
    var
        Shop: Record "Shpfy Shop";
        IsHandled: Boolean;
        ParametersTxt: Label '<?xml version="1.0" standalone="yes"?><ReportParameters name="Shpfy Sync Images" id="30107"><Options><Field name="ProductFilterTxt">%1</Field></Options><DataItems><DataItem name="Shop">%2</DataItem></DataItems></ReportParameters>', Locked = true;
    begin
        OnBeforeRunConnector(ShopCode, ProductIdFilter, IsHandled);
        if IsHandled then
            exit;
        Shop.SetRange(Code, ShopCode);
        Report.Execute(Report::"Shpfy Sync Images", StrSubstNo(ParametersTxt, XmlEscape(ProductIdFilter), XmlEscape(Shop.GetView())));
    end;

    /// <summary>Sets the shop and the product Id filter the report runs for.</summary>
    /// <param name="NewShopCode">The Shopify shop code.</param>
    /// <param name="NewProductIdFilter">A filter on the Shopify product Id, or empty for all products.</param>
    procedure SetParameters(NewShopCode: Code[20]; NewProductIdFilter: Text)
    begin
        ShopCode := NewShopCode;
        ProductIdFilter := NewProductIdFilter;
    end;

    local procedure XmlEscape(Value: Text): Text
    begin
        exit(Value.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;'));
    end;

    /// <summary>Raised before the connector report runs. The test app handles it to stand in for the live Shopify API.</summary>
    /// <param name="ForShopCode">The Shopify shop code.</param>
    /// <param name="ForProductIdFilter">The product Id filter, empty for all products.</param>
    /// <param name="IsHandled">Set to true to skip the report.</param>
    [IntegrationEvent(false, false)]
    internal procedure OnBeforeRunConnector(ForShopCode: Code[20]; ForProductIdFilter: Text; var IsHandled: Boolean)
    begin
    end;
}
