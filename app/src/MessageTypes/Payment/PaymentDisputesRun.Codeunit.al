namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;

/// <summary>Runs dispute import inside a rollback boundary that ignores connector commits.</summary>
codeunit 73732047 "Payment Disputes Run ori"
{
    Access = Internal;
    TableNo = "Shpfy Shop";

    trigger OnRun()
    begin
        RunConnector(Rec);
    end;

    [CommitBehavior(CommitBehavior::Ignore)]
    local procedure RunConnector(Shop: Record "Shpfy Shop")
    var
        Handled: Boolean;
        Parameters: Text;
        ParametersTok: Label '<?xml version="1.0" standalone="yes"?><ReportParameters name="Shpfy Sync Disputes" id="30120"><Options/><DataItems><DataItem name="Shop">%1</DataItem></DataItems></ReportParameters>', Locked = true;
    begin
        OnBeforeRunConnector(Shop, Handled);
        if Handled then
            exit;
        Shop.SetRecFilter();
        // No Boolean Codeunit.Run inside this scope: implicit commits are not controlled by CommitBehavior.
        Parameters := StrSubstNo(ParametersTok, Shop.GetView(false).Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;'));
        Report.Execute(Report::"Shpfy Sync Disputes", Parameters);
    end;

    /// <summary>Lets the test app replace the connector without contacting Shopify.</summary>
    /// <param name="Shop">The selected shop.</param>
    /// <param name="Handled">Set to true when the connector has been replaced.</param>
    [IntegrationEvent(false, false)]
    internal procedure OnBeforeRunConnector(Shop: Record "Shpfy Shop"; var Handled: Boolean)
    begin
    end;
}
