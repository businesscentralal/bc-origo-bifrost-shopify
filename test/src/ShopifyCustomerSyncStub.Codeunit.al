namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.Customer;
using Origo.Bifrost.Shopify;

/// <summary>
/// Stands in for the Shopify connector codeunit Shpfy Sync Customers (30123) in the Shopify.Customer.Sync tests. The connector
/// cannot reach Shopify from a test, because its access token is kept in its own isolated storage. In the import pass the stub
/// does what the connector leaves behind: customer 1 is retrieved and its mapped Business Central customer updated; customer 2
/// is retrieved and its update fails, so its Business Central customer is not written; customer 3 is new and its creation
/// fails, so it stays without a Business Central customer. The update pass does nothing.
/// </summary>
codeunit 97452 "Shpfy Cust Sync Stub ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    var
        Passes: Text;

    /// <summary>Returns the passes the message type started, as I (import, with Can Update Shopify Customer off) and U (update, with no import).</summary>
    /// <returns>The passes in order.</returns>
    procedure GetPasses(): Text
    begin
        exit(Passes);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Customer Sync Run ori", OnBeforeRunConnector, '', false, false)]
    local procedure StandInForConnector(Shop: Record "Shpfy Shop"; IsImportPass: Boolean; var Handled: Boolean)
    var
        Customer: Record Customer;
        ShopifyCustomer: Record "Shpfy Customer";
    begin
        Handled := true;
        if not IsImportPass then begin
            if Shop."Customer Import From Shopify" = Shop."Customer Import From Shopify"::None then
                Passes += 'U';
            exit;
        end;
        if not Shop."Can Update Shopify Customer" then
            Passes += 'I';
        // Keep the rows the connector writes apart from the seeded ones in time.
        Sleep(50);
        // Customer 1: retrieved and its mapped Business Central customer updated.
        ShopifyCustomer.Get(1600001);
        ShopifyCustomer."Updated At" := CurrentDateTime();
        ShopifyCustomer.Modify();
        Customer.GetBySystemId(ShopifyCustomer."Customer SystemId");
        Customer.Name := 'Bifrost Shopify updated';
        Customer.Modify();
        Commit();
        // Customer 2: retrieved, then the update fails (the connector swallows the error and rolls the customer back).
        ShopifyCustomer.Get(1600002);
        ShopifyCustomer."Updated At" := CurrentDateTime();
        ShopifyCustomer.Modify();
        Commit();
        // Customer 3: new in Shopify, retrieved, then the creation fails.
        ShopifyCustomer.Init();
        ShopifyCustomer.Id := 1600003;
        ShopifyCustomer."Shop Id" := Shop."Shop Id";
        ShopifyCustomer."Updated At" := CurrentDateTime();
        ShopifyCustomer.Insert();
        Commit();
    end;
}
