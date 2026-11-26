namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.Customer;
using Origo.Bifrost.Shopify;
using System.TestLibraries.Utilities;

/// <summary>Manual mock of report 30112. No Shopify token or provider call.</summary>
codeunit 97591 "Shopify Customer Add Stub ori"
{
    EventSubscriberInstance = Manual;

    var
        FailureNo: Code[20];
        SkippedNo: Code[20];
        Calls: Integer;

    /// <summary>Selects customers whose exports throw or silently log a skip.</summary>
    /// <param name="NewFailureNo">Customer to insert a link, commit and throw for.</param>
    /// <param name="NewSkippedNo">Customer to log and skip.</param>
    procedure Configure(NewFailureNo: Code[20]; NewSkippedNo: Code[20])
    begin
        FailureNo := NewFailureNo;
        SkippedNo := NewSkippedNo;
    end;

    /// <summary>Returns intercepted report invocations.</summary>
    /// <returns>Report call count.</returns>
    procedure CallCount(): Integer
    begin
        exit(Calls);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Customer Add Run ori", 'OnBeforeRunConnector', '', false, false)]
    local procedure RunConnector(Shop: Record "Shpfy Shop"; Customer: Record Customer; var Handled: Boolean)
    begin
        if Shop.Code <> 'XCA17' then
            exit;
        Handled := true;
        Calls += 1;
        ExportCustomer(Shop, Customer, FailureNo, SkippedNo);
    end;

    /// <summary>Creates a mock link or a mock connector failure for a fixture customer.</summary>
    /// <param name="Shop">Fixture shop.</param>
    /// <param name="Customer">Exactly filtered fixture customer.</param>
    /// <param name="FailNo">Customer whose link must roll back despite an explicit commit.</param>
    /// <param name="SkipNo">Customer whose connector skipped-record reason must be surfaced.</param>
    procedure ExportCustomer(Shop: Record "Shpfy Shop"; Customer: Record Customer; FailNo: Code[20]; SkipNo: Code[20])
    var
        Link: Record "Shpfy Customer";
        Assert: Codeunit "Library Assert";
        NextId: BigInteger;
    begin
        Assert.AreEqual(1, Customer.Count(), 'Report selection must contain exactly one customer.');
        Assert.AreEqual(Customer."No.", Customer.GetRangeMin("No."), 'Exact customer filter.');
        if Customer."No." = SkipNo then begin
            InsertSkipped(Customer.RecordId(), 'XConnector: customer has no usable e-mail.');
            exit;
        end;
        if FailNo = 'XNOOUTPUT' then
            exit;
        NextId := 975900001;
        while Link.Get(NextId) do
            NextId += 1;
        Link.Init();
        Link.Id := NextId;
        Link."Shop Id" := Shop."Shop Id";
        Link."Customer SystemId" := Customer.SystemId;
        Link.Insert();
        if Customer."No." = FailNo then begin
            Commit();
            Error('XConnector failure after link and commit');
        end;
    end;

    /// <summary>Inserts mock connector diagnostic data through the public record API.</summary>
    /// <param name="ForRecordId">Fixture customer identifier.</param>
    /// <param name="Reason">Fixture diagnostic text.</param>
    procedure InsertSkipped(ForRecordId: RecordId; Reason: Text)
    var
        Skipped: RecordRef;
    begin
        Skipped.Open(30159);
        Skipped.Init();
        Skipped.Field(5).Value := ForRecordId;
        Skipped.Field(3).Value := Database::Customer;
        Skipped.Field(7).Value := Reason;
        Skipped.Insert(true);
    end;
}
