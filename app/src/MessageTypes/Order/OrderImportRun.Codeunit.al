namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;

/// <summary>
/// Runs the Shopify report Shpfy Sync Orders from Shopify (30104) for one shop. Run through Codeunit.Run so that a
/// failure of the report is caught by the caller and returned as a refusal.
/// </summary>
codeunit 70013411 "Order Import Run ori"
{
    Access = Internal;

    var
        ShopCode: Code[20];

    trigger OnRun()
    begin
        RunReport();
    end;

    /// <summary>Runs the Shopify report; a failure is reported as false with GetLastErrorText.</summary>
    /// <returns>True when the report ran to the end.</returns>
    [TryFunction]
    procedure TryRunReport()
    begin
        RunReport();
    end;

    local procedure RunReport()
    var
        Shop: Record "Shpfy Shop";
        RequestPageXml: Text;
    begin
        Shop.SetRange(Code, ShopCode);
        RequestPageXml := '<?xml version="1.0" standalone="yes"?><ReportParameters name="Sync Orders from Shopify" id="30104"><DataItems><DataItem name="Shop">' +
            EscapeXml(Shop.GetView(true)) + '</DataItem></DataItems></ReportParameters>';
        Report.Execute(Report::"Shpfy Sync Orders from Shopify", RequestPageXml);
    end;

    /// <summary>Sets the shop the report runs for.</summary>
    /// <param name="NewShopCode">The Shopify shop code.</param>
    procedure SetShopCode(NewShopCode: Code[20])
    begin
        ShopCode := NewShopCode;
    end;

    local procedure EscapeXml(Value: Text): Text
    begin
        exit(Value.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;'));
    end;
}
