namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Origo.Bifrost.Shopify;

/// <summary>Replaces payout sync only for issue 32 fixtures. No request can reach Shopify while this test app is installed.</summary>
codeunit 97551 "Shpfy Pay Sync Stub ori"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Payment Sync Run ori", OnBeforeRunConnector, '', false, false)]
    local procedure ReplaceConnector(Shop: Record "Shpfy Shop"; var Handled: Boolean)
    var
        Payout: Record "Shpfy Payout";
        LogEntry: RecordRef;
        FieldValue: FieldRef;
        MockFailureErr: Label 'X32 mock connector failure after commit.', Locked = true;
        UnexpectedShopErr: Label 'Issue 32 tests refuse connector access outside their fixtures.', Locked = true;
    begin
        if not (Shop.Code in ['X32-OK', 'X32-NONE', 'X32-FAIL', 'X32-&|()<>', 'X32-1234567890123456']) then
            Error(UnexpectedShopErr);
        Handled := true;
        if Shop.Code = 'X32-NONE' then
            exit;

        Payout.SetLoadFields(Status);
        Payout.SetRange("Shop Code", Shop.Code);
        Payout.SetRange(Status, Payout.Status::Scheduled);
        if Payout.FindSet(true) then
            repeat
                Payout.Status := Payout.Status::Paid;
                Payout.Modify();
            until Payout.Next() = 0;

        // Match a connector stage that commits, then a later import.
        Commit();
        if Shop.Code = 'X32-FAIL' then begin
            InsertPayout(975320005, Shop.Code, 3);
            InsertTransaction(975320015, Shop.Code, 975320005);
            LogEntry.Open(30115);
            LogEntry.Init();
            FieldValue := LogEntry.Field(9);
            FieldValue.Value := 'X32 rollback log';
            LogEntry.Insert();
            LogEntry.Close();
            Commit();
            Error(MockFailureErr);
        end;

        if Shop.Code = 'X32-OK' then begin
            InsertPayout(975320002, Shop.Code, 3);
            InsertTransaction(975320012, Shop.Code, 975320002);
        end;
    end;

    /// <summary>Seeds a mock payout without calling Shopify.</summary>
    /// <param name="PayoutId">The fixture id.</param>
    /// <param name="ShopCode">The fixture shop.</param>
    /// <param name="StatusOrdinal">The payout status ordinal. 1 is Scheduled and 3 is Paid.</param>
    procedure InsertPayout(PayoutId: BigInteger; ShopCode: Code[20]; StatusOrdinal: Integer)
    var
        Payout: Record "Shpfy Payout";
    begin
        if Payout.Get(PayoutId) then
            exit;
        Payout.Init();
        Payout.Id := PayoutId;
        Payout.Status := Enum::"Shpfy Payout Status".FromInteger(StatusOrdinal);
        Payout.Currency := 'USD';
        Payout.Amount := 25;
        Payout."Shop Code" := ShopCode;
        Payout.Insert();
    end;

    /// <summary>Seeds a mock payment transaction without calling Shopify.</summary>
    /// <param name="TransactionId">The fixture id.</param>
    /// <param name="ShopCode">The fixture shop.</param>
    /// <param name="PayoutId">The payout the transaction belongs to.</param>
    procedure InsertTransaction(TransactionId: BigInteger; ShopCode: Code[20]; PayoutId: BigInteger)
    var
        PaymentTransaction: Record "Shpfy Payment Transaction";
    begin
        if PaymentTransaction.Get(TransactionId) then
            exit;
        PaymentTransaction.Init();
        PaymentTransaction.Id := TransactionId;
        PaymentTransaction.Type := PaymentTransaction.Type::Charge;
        PaymentTransaction."Payout Id" := PayoutId;
        PaymentTransaction.Currency := 'USD';
        PaymentTransaction.Amount := 25;
        PaymentTransaction."Shop Code" := ShopCode;
        PaymentTransaction.Insert();
    end;
}
