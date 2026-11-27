namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;

/// <summary>
/// Runs report Shpfy Sync Payments (30105) for one shop inside a rollback boundary that ignores connector commits.
/// The caller starts this codeunit with Run in an if statement. The report is not wrapped in another Boolean Codeunit.Run.
/// </summary>
codeunit 73732111 "Payment Sync Run ori"
{
    Access = Internal;
    TableNo = "Shpfy Shop";

    trigger OnRun()
    begin
        RunConnector(Rec);
    end;

    /// <summary>
    /// Calls the connector. Commits inside this procedure, including the connector's commit after each HTTP response, are ignored,
    /// so a later failure rolls the payout and payment transaction rows back with the Run.
    /// </summary>
    /// <param name="Shop">The shop the report runs for.</param>
    [CommitBehavior(CommitBehavior::Ignore)]
    local procedure RunConnector(Shop: Record "Shpfy Shop")
    var
        Handled: Boolean;
        Parameters: Text;
        ParametersTok: Label '<?xml version="1.0" standalone="yes"?><ReportParameters name="Shpfy Sync Payments" id="30105"><Options/><DataItems><DataItem name="Shop">%1</DataItem></DataItems></ReportParameters>', Locked = true;
    begin
        OnBeforeRunConnector(Shop, Handled);
        if Handled then
            exit;
        Shop.SetRecFilter();
        Parameters := StrSubstNo(ParametersTok, Shop.GetView(false).Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;'));
        Report.Execute(Report::"Shpfy Sync Payments", Parameters);
    end;

    /// <summary>Lets the test app replace the connector without contacting Shopify.</summary>
    /// <param name="Shop">The selected shop.</param>
    /// <param name="Handled">Set to true when the connector has been replaced.</param>
    [IntegrationEvent(false, false)]
    internal procedure OnBeforeRunConnector(Shop: Record "Shpfy Shop"; var Handled: Boolean)
    begin
    end;
}
