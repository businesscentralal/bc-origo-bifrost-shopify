namespace Origo.Bifrost.Shopify;

/// <summary>Runs connector 30161 with a temporary import row and suppresses explicit commits inside the caller's rollback boundary.</summary>
codeunit 73731952 "Order ForceSync Run ori"
{
    Access = Internal;

    var
        ShopCode: Code[20];
        OrderId: BigInteger;

    trigger OnRun()
    begin
        RunConnector();
    end;

    /// <summary>Sets the already validated order and shop.</summary>
    /// <param name="NewShopCode">Shop of the existing order.</param>
    /// <param name="NewOrderId">Existing Shopify order ID.</param>
    internal procedure SetOrder(NewShopCode: Code[20]; NewOrderId: BigInteger)
    begin
        ShopCode := NewShopCode;
        OrderId := NewOrderId;
    end;

    [CommitBehavior(CommitBehavior::Ignore)]
    local procedure RunConnector()
    var
        OrderToImport: RecordRef;
        ImportField: FieldRef;
        ImportVariant: Variant;
        Handled: Boolean;
    begin
        // Shpfy Orders to Import is internal. Fields 3 and 4 are Shop Code and Id in connector 28/29.
        OrderToImport.Open(30121, true);
        ImportField := OrderToImport.Field(3);
        ImportField.Value := ShopCode;
        ImportField := OrderToImport.Field(4);
        ImportField.Value := OrderId;
        OnBeforeRunConnector(OrderToImport, Handled);
        if Handled then
            exit;
        OrderToImport.SetTable(ImportVariant);
        // Deliberately no Boolean return: a nested Boolean Run would introduce an implicit commit.
        Codeunit.Run(30161, ImportVariant);
    end;

    /// <summary>Allows the test app to replace the connector inside the explicit-commit boundary.</summary>
    /// <param name="OrderToImport">Temporary import row passed to codeunit 30161.</param>
    /// <param name="Handled">True skips the connector call.</param>
    [IntegrationEvent(false, false)]
    internal procedure OnBeforeRunConnector(OrderToImport: RecordRef; var Handled: Boolean)
    begin
    end;
}
