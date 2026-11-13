namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.Document;

/// <summary>
/// Issue #24: when bound, inserts one unprocessed refund of another order in another shop as soon as a sales header is
/// inserted, so a refund is imported after the guard of Shopify.Order.CreateSalesDocument and before the refund phase.
/// </summary>
codeunit 97472 "Shpfy Refund Injector ori"
{
    EventSubscriberInstance = Manual;

    var
        RefundId: BigInteger;
        OtherOrderId: BigInteger;
        OtherShopCode: Code[20];
        Injected: Boolean;

    /// <summary>Sets the refund that is inserted while the request runs.</summary>
    /// <param name="NewRefundId">The Refund Id to insert.</param>
    /// <param name="NewOrderId">The Order Id of the refund (another order).</param>
    /// <param name="NewShopCode">The Shop Code of the refund (another shop).</param>
    procedure SetRefund(NewRefundId: BigInteger; NewOrderId: BigInteger; NewShopCode: Code[20])
    begin
        RefundId := NewRefundId;
        OtherOrderId := NewOrderId;
        OtherShopCode := NewShopCode;
        Injected := false;
    end;

    /// <summary>Reports whether the refund was inserted during the run.</summary>
    /// <returns>True when the refund was inserted.</returns>
    procedure WasInjected(): Boolean
    begin
        exit(Injected);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Header", OnAfterInsertEvent, '', false, false)]
    local procedure InjectRefundOnSalesHeaderInsert(var Rec: Record "Sales Header"; RunTrigger: Boolean)
    var
        RefundHeader: Record "Shpfy Refund Header";
    begin
        if Injected or Rec.IsTemporary() then
            exit;
        if RefundHeader.Get(RefundId) then
            exit;
        RefundHeader.Init();
        RefundHeader."Refund Id" := RefundId;
        RefundHeader."Order Id" := OtherOrderId;
        RefundHeader."Shop Code" := OtherShopCode;
        RefundHeader.Insert();
        Injected := true;
    end;
}
