namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Origo.Bifrost.Shopify;
using System.TestLibraries.Utilities;

/// <summary>Manually bound mock of the cancellation API. Asserts exact arguments and can write then refuse to prove rollback.</summary>
codeunit 97504 "Shopify Cancel Stub ori"
{
    EventSubscriberInstance = Manual;

    var
        Assert: Codeunit "Library Assert";
        ExpectedOrderId: BigInteger;
        ExpectedShopCode: Code[20];
        ExpectedReason: Enum "Shpfy Cancel Reason";
        ExpectedNotify: Boolean;
        ExpectedRefund: Boolean;
        ExpectedRestock: Boolean;
        Refuse: Boolean;
        ThrowError: Boolean;
        Calls: Integer;

    /// <summary>Sets the exact call the mock will accept.</summary>
    /// <param name="OrderId">Expected order.</param>
    /// <param name="ShopCode">Expected shop.</param>
    /// <param name="Reason">Expected reason.</param>
    /// <param name="NotifyCustomer">Expected notification.</param>
    /// <param name="Refund">Expected refund.</param>
    /// <param name="Restock">Expected restock.</param>
    /// <param name="ShouldRefuse">Return false after a local write.</param>
    /// <param name="ShouldThrow">Throw after a local write.</param>
    procedure Configure(OrderId: BigInteger; ShopCode: Code[20]; Reason: Enum "Shpfy Cancel Reason"; NotifyCustomer: Boolean; Refund: Boolean; Restock: Boolean; ShouldRefuse: Boolean; ShouldThrow: Boolean)
    begin
        ExpectedOrderId := OrderId;
        ExpectedShopCode := ShopCode;
        ExpectedReason := Reason;
        ExpectedNotify := NotifyCustomer;
        ExpectedRefund := Refund;
        ExpectedRestock := Restock;
        Refuse := ShouldRefuse;
        ThrowError := ShouldThrow;
        Calls := 0;
    end;

    /// <summary>Counts connector calls, including attempts made during invalid requests.</summary>
    /// <returns>Number of calls seen.</returns>
    procedure CallCount(): Integer
    begin
        exit(Calls);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Order Cancel Run ori", 'OnBeforeRunConnector', '', false, false)]
    local procedure Cancel(ForOrderId: BigInteger; ForShopCode: Code[20]; ForNotifyCustomer: Boolean; ForCancelReason: Enum "Shpfy Cancel Reason"; ForRefund: Boolean; ForRestock: Boolean; var Succeeded: Boolean; var IsHandled: Boolean)
    var
        OrderHeader: Record "Shpfy Order Header";
    begin
        Calls += 1;
        IsHandled := true;
        Assert.AreEqual(ExpectedOrderId, ForOrderId, 'Exact order ID reaches API.');
        Assert.AreEqual(ExpectedShopCode, ForShopCode, 'Exact shop reaches API.');
        Assert.AreEqual(ExpectedReason, ForCancelReason, 'Exact reason reaches API.');
        Assert.AreEqual(ExpectedNotify, ForNotifyCustomer, 'Exact notify choice reaches API.');
        Assert.AreEqual(ExpectedRefund, ForRefund, 'Exact refund choice reaches API.');
        Assert.AreEqual(ExpectedRestock, ForRestock, 'Exact restock choice reaches API.');
        if Refuse or ThrowError then begin
            OrderHeader.Get(ForOrderId);
            OrderHeader."Cancelled At" := CurrentDateTime();
            OrderHeader.Modify();
        end;
        if ThrowError then
            Error('Mock connector exception after local write.');
        Succeeded := not Refuse;
    end;
}
