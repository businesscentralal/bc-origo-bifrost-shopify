namespace Origo.Bifrost.Shopify;

using Microsoft.Sales.Customer;

/// <summary>
/// Records the Business Central customers written while the import pass of Shopify.Customer.Sync runs. The connector hides
/// the error of a customer it could not import or update, and its customer events are internal, so the written customers are
/// how the message type tells a successful update of a mapped customer from a failed one. Bound manually for the import pass
/// only; what it records stays in memory, also when the connector rolls back a failed customer.
/// </summary>
codeunit 73732002 "Customer Sync Monitor ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    var
        WrittenCustomers: List of [Guid];

    /// <summary>Tells whether the Business Central customer was inserted or modified while the monitor was bound.</summary>
    /// <param name="CustomerSystemId">The SystemId of the Business Central customer.</param>
    /// <returns>True when the customer was written.</returns>
    procedure WasWritten(CustomerSystemId: Guid): Boolean
    begin
        exit(WrittenCustomers.Contains(CustomerSystemId));
    end;

    [EventSubscriber(ObjectType::Table, Database::Customer, OnAfterInsertEvent, '', false, false)]
    local procedure RecordInsertedCustomer(var Rec: Record Customer; RunTrigger: Boolean)
    begin
        Remember(Rec);
    end;

    [EventSubscriber(ObjectType::Table, Database::Customer, OnAfterModifyEvent, '', false, false)]
    local procedure RecordModifiedCustomer(var Rec: Record Customer; var xRec: Record Customer; RunTrigger: Boolean)
    begin
        Remember(Rec);
    end;

    local procedure Remember(var Customer: Record Customer)
    begin
        if Customer.IsTemporary() then
            exit;
        if not WrittenCustomers.Contains(Customer.SystemId) then
            WrittenCustomers.Add(Customer.SystemId);
    end;
}
