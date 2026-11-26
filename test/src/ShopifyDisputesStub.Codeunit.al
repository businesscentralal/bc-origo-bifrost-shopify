namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Origo.Bifrost.Shopify;

/// <summary>Replaces dispute sync only for issue 33 fixtures. No request can reach Shopify while this test app is installed.</summary>
codeunit 97518 "Shopify Disputes Stub ori"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Payment Disputes Run ori", 'OnBeforeRunConnector', '', false, false)]
    local procedure ReplaceConnector(Shop: Record "Shpfy Shop"; var Handled: Boolean)
    var
        Dispute: RecordRef;
        LogEntry: RecordRef;
        FieldValue: FieldRef;
        DisputeStatus: Enum "Shpfy Dispute Status";
        MockFailureErr: Label 'X33 mock connector failure after commit.', Locked = true;
        UnexpectedShopErr: Label 'Issue 33 tests refuse connector access outside their fixtures.', Locked = true;
    begin
        if not (Shop.Code in ['X33-OK', 'X33-NONE', 'X33-FAIL', 'X33-&|()<>', 'X33-1234567890123456']) then
            Error(UnexpectedShopErr);
        Handled := true;
        if Shop.Code = 'X33-NONE' then
            exit;
        Dispute.Open(30155);
        FieldValue := Dispute.Field(101);
        FieldValue.SetRange(Shop.Code);
        if Dispute.FindSet() then
            repeat
                FieldValue := Dispute.Field(8);
                DisputeStatus := FieldValue.Value;
                if DisputeStatus = DisputeStatus::"Needs Response" then begin
                    FieldValue.Value := 2;
                    Dispute.Modify();
                end;
            until Dispute.Next() = 0;
        Dispute.Close();
        // Match a connector refresh followed by an explicit HTTP-response commit and a new import.
        Commit();
        if Shop.Code = 'X33-FAIL' then
            InsertDispute(975170005, Shop.Code, 1)
        else
            InsertDispute(975170002, Shop.Code, 2);
        if Shop.Code = 'X33-FAIL' then begin
            LogEntry.Open(30115);
            LogEntry.Init();
            FieldValue := LogEntry.Field(9);
            FieldValue.Value := 'X33 rollback log';
            LogEntry.Insert();
            LogEntry.Close();
            Commit();
            Error(MockFailureErr);
        end;
    end;

    /// <summary>Seeds a mock dispute without calling Shopify.</summary>
    /// <param name="DisputeId">The fixture ID.</param>
    /// <param name="ShopCode">The fixture shop.</param>
    /// <param name="StatusOrdinal">The connector status ordinal.</param>
    procedure InsertDispute(DisputeId: BigInteger; ShopCode: Code[20]; StatusOrdinal: Integer)
    var
        Dispute: RecordRef;
        FieldValue: FieldRef;
    begin
        Dispute.Open(30155);
        FieldValue := Dispute.Field(1);
        FieldValue.SetRange(DisputeId);
        if not Dispute.IsEmpty() then begin
            Dispute.Close();
            exit;
        end;
        Dispute.Init();
        FieldValue.Value := DisputeId;
        FieldValue := Dispute.Field(101);
        FieldValue.Value := ShopCode;
        FieldValue := Dispute.Field(8);
        FieldValue.Value := StatusOrdinal;
        FieldValue := Dispute.Field(5);
        FieldValue.Value := 25;
        FieldValue := Dispute.Field(4);
        FieldValue.Value := 'USD';
        Dispute.Insert();
        Dispute.Close();
    end;
}
