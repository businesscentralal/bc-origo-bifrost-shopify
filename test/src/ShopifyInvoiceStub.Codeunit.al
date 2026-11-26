namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Sales.History;
using Origo.Bifrost.Shopify;

/// <summary>Mock-only replacement for report 30119. It never reads credentials or calls Shopify.</summary>
codeunit 97508 "Shpfy Invoice Stub ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Invoice Sync Run ori", OnBeforeRunConnector, '', false, false)]
    local procedure ExportStandIn(SelectedShopCode: Code[20]; Invoice: Record "Sales Invoice Header"; var Handled: Boolean)
    var
        Skipped: RecordRef;
        Field: FieldRef;
        RefusedErr: Label 'Mock connector refused invoice after a write.', Locked = true;
    begin
        if SelectedShopCode <> 'BIFT31' then
            Error('Unexpected shop: %1', SelectedShopCode);
        Handled := true;
        case Invoice."No." of
            'BIFT31-FAIL':
                begin
                    Invoice."Shpfy Order Id" := 999;
                    Invoice.Modify();
                    Error(RefusedErr);
                end;
            'BIFT31-BLOCK':
                begin
                    Invoice."Shpfy Order Id" := -2;
                    Skipped.Open(30159);
                    Skipped.Init();
                    Field := Skipped.Field(3);
                    Field.Value := Database::"Sales Invoice Header";
                    Field := Skipped.Field(5);
                    Field.Value := Invoice.RecordId();
                    Field := Skipped.Field(7);
                    Field.Value := 'Mock: quantity is not a positive whole number.';
                    Skipped.Insert();
                    Skipped.Close();
                end;
            'BIFT31-NEG':
                Invoice."Shpfy Order Id" := -1;
            'BIFT31-ZERO':
                exit;
            else
                Invoice."Shpfy Order Id" := 31001;
        end;
        Invoice.Modify();
    end;
}
