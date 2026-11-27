namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Origo.Bifrost.Shopify;
using System.TestLibraries.Utilities;

/// <summary>Replaces only reserved issue 28 orders, inside the real transaction boundary.</summary>
codeunit 97525 "Shopify ForceSync Stub ori"
{
    Access = Internal;
    SingleInstance = true;

    var
        Calls: Integer;

    /// <summary>Clears the event-call counter before a refusal test.</summary>
    procedure ResetCalls()
    begin
        Calls := 0;
    end;

    /// <summary>Reports how often the connector seam was reached in this session.</summary>
    /// <returns>Number of intercepted runs.</returns>
    procedure GetCalls(): Integer
    begin
        exit(Calls);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Order ForceSync Run ori", OnBeforeRunConnector, '', false, false)]
    local procedure StandIn(OrderToImport: RecordRef; var Handled: Boolean)
    var
        Header: Record "Shpfy Order Header";
        Line: Record "Shpfy Order Line";
        Attribute: Record "Shpfy Order Attribute";
        Assert: Codeunit "Library Assert";
        Log: RecordRef;
        OrderId: BigInteger;
        ShopCode: Code[20];
    begin
        OrderId := OrderToImport.Field(4).Value;
        ShopCode := OrderToImport.Field(3).Value;
        if (OrderId < 8928000028L) or (OrderId > 8928000039L) or (CopyStr(ShopCode, 1, 6) <> 'XFS28-') then
            exit;
        Handled := true;
        Calls += 1;
        Assert.AreEqual(30121, OrderToImport.Number, 'Exact connector input table.');
        Assert.IsTrue(OrderToImport.IsTemporary(), 'Never insert into the real import queue.');
        Header.Get(OrderId);
        Assert.AreEqual(Header."Shop Code", ShopCode, 'Shop derived from the order.');
        Header."Shopify Order No." := 'XREFRESHED';
        Header."Has Order State Error" := Header.Processed or (OrderId = 8928000039L);
        Header.Modify(false);
        Line.Get(OrderId, 1);
        Line.Description := 'XREFRESHED';
        Line.Quantity := 2;
        Line.Modify(false);
        if not Line.Get(OrderId, 2) then begin
            Line.Init();
            Line."Shopify Order Id" := OrderId;
            Line."Line Id" := 2;
            Line.Description := 'XADDED';
            Line.Quantity := 1;
            Line.Insert(false);
        end;
        Attribute.Get(OrderId, 'XFS28');
        Attribute."Attribute Value" := 'XREFRESHED';
        Attribute.Modify(false);
        Log.Open(30115);
        Log.Field(1).SetRange(928000000 + (OrderId - 8928000028L));
        if Log.IsEmpty() then begin
            Log.Init();
            Log.Field(1).Value := 928000000 + (OrderId - 8928000028L);
            Log.Field(9).Value := 'XFS28 mock log';
            Log.Insert(false);
        end;
        if OrderId = 8928000038L then
            Error('XFS28 mock connector failure before commit.');
        Commit();
        if OrderId = 8928000030L then
            Error('XFS28 mock connector failure after commit.');
    end;
}
