namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.Customer;

/// <summary>
/// Observes the import pass of Shopify.Customer.Sync. The connector hides the error of a customer it could not import or
/// update, and its customer events are internal, so the monitor records what the connector did instead:
/// - every Business Central customer written is marked in table Customer Sync Marker ori, inside the connector's own
///   transaction, so the mark survives only when the connector's work on that customer is committed (a write followed by a
///   failing step, for example the contact update, is rolled back together with its mark);
/// - every Shopify customer row the connector deleted is remembered, because the connector deletes a new Shopify customer
///   again when its retrieval from Shopify fails.
/// Bound manually for the import pass only.
/// </summary>
codeunit 73732002 "Customer Sync Monitor ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;
    Permissions = tabledata "Customer Sync Marker ori" = RIMD;

    var
        RunId: Guid;
        DeletedShopifyCustomers: List of [BigInteger];

    /// <summary>Starts a new observation; call before binding the monitor.</summary>
    procedure Start()
    begin
        RunId := CreateGuid();
        Clear(DeletedShopifyCustomers);
    end;

    /// <summary>Tells whether the write of the Business Central customer during the pass was committed.</summary>
    /// <param name="CustomerSystemId">The SystemId of the Business Central customer.</param>
    /// <returns>True when a committed write of the customer was marked.</returns>
    procedure WasWritten(CustomerSystemId: Guid): Boolean
    var
        Marker: Record "Customer Sync Marker ori";
    begin
        exit(Marker.Get(RunId, CustomerSystemId));
    end;

    /// <summary>Returns the Shopify customer IDs whose rows the connector deleted during the pass.</summary>
    /// <returns>The deleted Shopify customer IDs.</returns>
    procedure GetDeletedShopifyCustomers(): List of [BigInteger]
    begin
        exit(DeletedShopifyCustomers);
    end;

    /// <summary>Removes the markers of this observation.</summary>
    procedure Finish()
    var
        Marker: Record "Customer Sync Marker ori";
    begin
        Marker.SetRange("Run Id", RunId);
        if not Marker.IsEmpty() then
            Marker.DeleteAll();
    end;

    [EventSubscriber(ObjectType::Table, Database::Customer, OnAfterInsertEvent, '', false, false)]
    local procedure MarkInsertedCustomer(var Rec: Record Customer; RunTrigger: Boolean)
    begin
        Mark(Rec);
    end;

    [EventSubscriber(ObjectType::Table, Database::Customer, OnAfterModifyEvent, '', false, false)]
    local procedure MarkModifiedCustomer(var Rec: Record Customer; var xRec: Record Customer; RunTrigger: Boolean)
    begin
        Mark(Rec);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Shpfy Customer", OnAfterDeleteEvent, '', false, false)]
    local procedure RememberDeletedShopifyCustomer(var Rec: Record "Shpfy Customer"; RunTrigger: Boolean)
    begin
        if Rec.IsTemporary() then
            exit;
        if not DeletedShopifyCustomers.Contains(Rec.Id) then
            DeletedShopifyCustomers.Add(Rec.Id);
    end;

    local procedure Mark(var Customer: Record Customer)
    var
        Marker: Record "Customer Sync Marker ori";
    begin
        if Customer.IsTemporary() then
            exit;
        if Marker.Get(RunId, Customer.SystemId) then
            exit;
        Marker."Run Id" := RunId;
        Marker."Customer SystemId" := Customer.SystemId;
        Marker.Insert();
    end;
}
