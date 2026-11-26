namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;

/// <summary>Runs report 30116 with validated, locale-independent filters and a mock connector seam.</summary>
codeunit 73732083 "Catalog SyncPrices Run ori"
{
    Access = Internal;

    var
        ShopCode: Code[20];
        ShopView: Text;
        CatalogView: Text;
        CatalogType: Enum "Shpfy Catalog Type";

    trigger OnRun()
    var
        Handled: Boolean;
        Parameters: Text;
        ParametersLbl: Label '<?xml version="1.0" standalone="yes"?><ReportParameters name="Shpfy Sync Catalog Prices" id="30116"><Options><Field name="ShopifyCompanyId"></Field><Field name="ShopifyCatalogType">%1</Field></Options><DataItems><DataItem name="Shop">%2</DataItem><DataItem name="Catalog">%3</DataItem></DataItems></ReportParameters>', Locked = true;
    begin
        // Company SystemId is already in CatalogView; leaving the hidden option empty preserves that exact filter.
        Parameters := StrSubstNo(ParametersLbl, Format(CatalogType.AsInteger(), 0, 9), XmlEscape(ShopView), XmlEscape(CatalogView));
        OnBeforeRunConnector(ShopCode, CatalogView, Parameters, Handled);
        if not Handled then
            Report.Execute(30116, Parameters);
    end;

    /// <summary>Sets validated views and the catalog type used by the connector API.</summary>
    /// <param name="NewShopCode">Selected shop.</param>
    /// <param name="NewShopView">Exact shop view.</param>
    /// <param name="NewCatalogView">Intersected catalog filters.</param>
    /// <param name="NewCatalogType">Connector catalog type.</param>
    procedure SetParameters(NewShopCode: Code[20]; NewShopView: Text; NewCatalogView: Text; NewCatalogType: Enum "Shpfy Catalog Type")
    begin
        ShopCode := NewShopCode;
        ShopView := NewShopView;
        CatalogView := NewCatalogView;
        CatalogType := NewCatalogType;
    end;

    local procedure XmlEscape(Value: Text): Text
    begin
        exit(Value.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;'));
    end;

    /// <summary>Lets tests stand in for the connector without credentials or network calls.</summary>
    /// <param name="ForShopCode">Selected shop code.</param>
    /// <param name="ForCatalogView">Selected catalog view.</param>
    /// <param name="ReportParameters">Actual report XML to inspect.</param>
    /// <param name="Handled">True when a stand-in handled the run.</param>
    [IntegrationEvent(false, false)]
    internal procedure OnBeforeRunConnector(ForShopCode: Code[20]; ForCatalogView: Text; ReportParameters: Text; var Handled: Boolean)
    begin
    end;
}
