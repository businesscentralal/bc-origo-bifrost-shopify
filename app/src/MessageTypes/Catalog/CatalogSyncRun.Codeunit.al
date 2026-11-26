namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;

/// <summary>Runs report 30115 for exactly one shop; explicit commits are refused so failures roll back local writes.</summary>
codeunit 73732081 "Catalog Sync Run ori"
{
    Access = Internal;

    var
        ShopCode: Code[20];

    trigger OnRun()
    begin
        RunConnector();
    end;

    /// <summary>Selects the validated shop.</summary>
    /// <param name="NewShopCode">The shop to import catalogs for.</param>
    procedure SetShopCode(NewShopCode: Code[20])
    begin
        ShopCode := NewShopCode;
    end;

    [CommitBehavior(CommitBehavior::Error)]
    local procedure RunConnector()
    var
        Shop: Record "Shpfy Shop";
        Handled: Boolean;
        ParametersLbl: Label '<?xml version="1.0" standalone="yes"?><ReportParameters name="Shpfy Sync Catalogs" id="30115"><Options/><DataItems><DataItem name="Shop">%1</DataItem></DataItems></ReportParameters>', Locked = true;
        ShopView: Text;
    begin
        Shop.Get(ShopCode);
        Shop.SetRange(Code, ShopCode);
        OnBeforeRunConnector(Shop, Handled);
        if Handled then
            exit;
        ShopView := Shop.GetView(false).Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;');
        Report.Execute(30115, StrSubstNo(ParametersLbl, ShopView));
    end;

    /// <summary>Allows the test app to replace the connector without provider calls.</summary>
    /// <param name="Shop">The shop selection passed to the report.</param>
    /// <param name="Handled">Set true to replace the report.</param>
    [IntegrationEvent(false, false)]
    internal procedure OnBeforeRunConnector(Shop: Record "Shpfy Shop"; var Handled: Boolean)
    begin
    end;
}
