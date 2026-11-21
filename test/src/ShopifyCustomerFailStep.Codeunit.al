namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Sales.Customer;

/// <summary>
/// A customer step of the stand-in connector that fails, run with Codeunit.Run as codeunit 30123 runs the import of one
/// customer: 1 fails before writing anything (a failed retrieval from Shopify); 2 modifies the Business Central customer and
/// then fails (a failing contact update), so the write is rolled back; 0 modifies the customer and succeeds.
/// </summary>
codeunit 97453 "Shpfy Cust Fail Step ori"
{
    Access = Internal;
    TableNo = Customer;

    var
        Failure: Integer;
        RetrievalFailedErr: Label 'Stand-in: the retrieval of the Shopify customer failed.', Locked = true;
        ContactUpdateFailedErr: Label 'Stand-in: the contact update of the customer failed.', Locked = true;

    trigger OnRun()
    begin
        if Failure = 1 then
            Error(RetrievalFailedErr);
        Rec.Name := 'Bifrost Shopify updated';
        Rec.Modify();
        if Failure = 2 then
            Error(ContactUpdateFailedErr);
    end;

    /// <summary>Sets where the step fails.</summary>
    /// <param name="NewFailure">0 none, 1 before any write, 2 after the customer write.</param>
    procedure SetFailure(NewFailure: Integer)
    begin
        Failure := NewFailure;
    end;
}
