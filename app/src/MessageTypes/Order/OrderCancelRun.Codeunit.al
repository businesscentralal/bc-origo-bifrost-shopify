namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;

/// <summary>Runs the public Orders API inside a rollback boundary. Never updates the imported order.</summary>
codeunit 73732043 "Order Cancel Run ori"
{
    Access = Internal;

    var
        OrderId: BigInteger;
        ShopCode: Code[20];
        NotifyCustomer: Boolean;
        CancelReason: Enum "Shpfy Cancel Reason";
        Refund: Boolean;
        Restock: Boolean;

    trigger OnRun()
    var
        Orders: Codeunit "Shpfy Orders";
        IsHandled: Boolean;
        Succeeded: Boolean;
        RefusedErr: Label 'Shopify refused to cancel order %1. Review Shopify Log Entries (table 30115) for the connector request and user errors.', Comment = '%1 = order ID||is-IS=Shopify hafnaði afturköllun pöntunar %1. Skoðaðu Shopify Log Entries (töflu 30115) fyrir beiðni tengilsins og villur.';
    begin
        OnBeforeRunConnector(OrderId, ShopCode, NotifyCustomer, CancelReason, Refund, Restock, Succeeded, IsHandled);
        if not IsHandled then
            Succeeded := Orders.CancelOrder(OrderId, ShopCode, NotifyCustomer, CancelReason, Refund, Restock);
        // A false result must also raise inside this boundary so any local connector writes roll back.
        if not Succeeded then
            Error(RefusedErr, OrderId);
    end;

    /// <summary>Copies the validated request without defaults or normalization of the reason.</summary>
    /// <param name="NewOrderId">Imported Shopify order ID.</param>
    /// <param name="NewShopCode">Shop from the imported order.</param>
    /// <param name="NewNotifyCustomer">Whether Shopify should email the customer.</param>
    /// <param name="NewCancelReason">Explicit cancellation reason.</param>
    /// <param name="NewRefund">Whether Shopify should refund the payment.</param>
    /// <param name="NewRestock">Whether Shopify should restock the inventory.</param>
    procedure SetParameters(NewOrderId: BigInteger; NewShopCode: Code[20]; NewNotifyCustomer: Boolean; NewCancelReason: Enum "Shpfy Cancel Reason"; NewRefund: Boolean; NewRestock: Boolean)
    begin
        OrderId := NewOrderId;
        ShopCode := NewShopCode;
        NotifyCustomer := NewNotifyCustomer;
        CancelReason := NewCancelReason;
        Refund := NewRefund;
        Restock := NewRestock;
    end;

    /// <summary>Allows the test app to replace the external Shopify operation.</summary>
    /// <param name="ForOrderId">Validated order ID.</param>
    /// <param name="ForShopCode">Validated shop.</param>
    /// <param name="ForNotifyCustomer">Explicit notification choice.</param>
    /// <param name="ForCancelReason">Explicit reason.</param>
    /// <param name="ForRefund">Explicit refund choice.</param>
    /// <param name="ForRestock">Explicit restock choice.</param>
    /// <param name="Succeeded">Stand-in return value.</param>
    /// <param name="IsHandled">True when the stand-in replaces the API.</param>
    [IntegrationEvent(false, false)]
    internal procedure OnBeforeRunConnector(ForOrderId: BigInteger; ForShopCode: Code[20]; ForNotifyCustomer: Boolean; ForCancelReason: Enum "Shpfy Cancel Reason"; ForRefund: Boolean; ForRestock: Boolean; var Succeeded: Boolean; var IsHandled: Boolean)
    begin
    end;
}
