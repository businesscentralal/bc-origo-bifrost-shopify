namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;

/// <summary>Runs Get Locations in an isolated transaction, ignoring explicit connector commits.</summary>
codeunit 73732121 "Location Sync Run ori"
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
    begin
        OnBeforeRunConnector(Shop, Handled);
        if not Handled then
            Codeunit.Run(30198, Shop);
    end;

    /// <summary>Allows tests to replace the connector with a credential-free stand-in.</summary>
    /// <param name="Shop">The selected shop.</param>
    /// <param name="Handled">Set true when the connector is replaced.</param>
    [IntegrationEvent(false, false)]
    internal procedure OnBeforeRunConnector(Shop: Record "Shpfy Shop"; var Handled: Boolean)
    begin
    end;
}
