namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;

/// <summary>Runs the connector with explicit commits ignored, so the caller can roll back local writes on failure.</summary>
codeunit 73732045 "Company Sync Run ori"
{
    Access = Internal;

    var
        ShopCode: Code[20];

    trigger OnRun()
    begin
        RunConnector();
    end;

    /// <summary>Selects the shop; no shop setting is modified.</summary>
    /// <param name="NewShopCode">Enabled Shopify shop code.</param>
    procedure SetShopCode(NewShopCode: Code[20])
    begin
        ShopCode := NewShopCode;
    end;

    [CommitBehavior(CommitBehavior::Ignore)]
    local procedure RunConnector()
    var
        Shop: Record "Shpfy Shop";
        Handled: Boolean;
    begin
        Shop.Get(ShopCode);
        OnBeforeRunConnector(Shop, Handled);
        if not Handled then
            // No Boolean return here: errors propagate to the outer rollback runner without an inner implicit commit.
            Codeunit.Run(30285, Shop);
    end;

    /// <summary>Allows the test app to replace the connector without credentials or network calls.</summary>
    /// <param name="Shop">The actual shop settings passed to the connector.</param>
    /// <param name="Handled">True when the subscriber replaced the connector.</param>
    [IntegrationEvent(false, false)]
    internal procedure OnBeforeRunConnector(Shop: Record "Shpfy Shop"; var Handled: Boolean)
    begin
    end;
}
