namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.Customer;
using Origo.Bifrost.Shopify;

/// <summary>Manual company connector stand-in; never calls a provider.</summary>
codeunit 97514 "Shopify Company Stub ori"
{
    EventSubscriberInstance = Manual;

    var
        FailRun: Boolean;
        Calls: Integer;
        ImportCalls: Integer;
        ExportCalls: Integer;

    /// <summary>Chooses whether to write, commit and fail to exercise rollback.</summary>
    /// <param name="ShouldFail">True for simulated connector failure.</param>
    procedure Configure(ShouldFail: Boolean)
    begin
        FailRun := ShouldFail;
    end;

    /// <summary>Returns connector invocations.</summary>
    /// <returns>Invocation count.</returns>
    procedure CallCount(): Integer
    begin
        exit(Calls);
    end;

    /// <summary>Returns import passes.</summary>
    /// <returns>Import count.</returns>
    procedure Imports(): Integer
    begin
        exit(ImportCalls);
    end;

    /// <summary>Returns export passes.</summary>
    /// <returns>Export count.</returns>
    procedure Exports(): Integer
    begin
        exit(ExportCalls);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Company Sync Run ori", 'OnBeforeRunConnector', '', false, false)]
    local procedure RunConnectorMock(Shop: Record "Shpfy Shop"; var Handled: Boolean)
    var
        Company: Record "Shpfy Company";
        Customer: Record Customer;
        Location: Record "Shpfy Company Location";
    begin
        if Shop.Code <> 'XCOMP18' then
            exit;
        Handled := true;
        Calls += 1;
        if (Shop."Company Import From Shopify" = Shop."Company Import From Shopify"::AllCompanies) or
           ((Shop."Company Import From Shopify" = Shop."Company Import From Shopify"::WithOrderImport) and Shop."Shopify Can Update Companies")
        then begin
            ImportCalls += 1;
            if not Company.Get(975130018) then begin
                Company.Init();
                Company.Id := 975130018;
                Company."Shop Code" := Shop.Code;
                Company.Name := 'XImported company';
                Customer.Get('XCOMPCUST18');
                Company."Customer SystemId" := Customer.SystemId;
                Company.Insert();
                Location.Init();
                Location.Id := 975130018;
                Location."Company SystemId" := Company.SystemId;
                Location.Insert();
            end;
        end;
        if Shop."Can Update Shopify Companies" then begin
            ExportCalls += 1;
            Company.Get(975130017);
            Company.Name := 'XExported company';
            Company.Modify();
        end;
        if FailRun then begin
            Commit();
            Error('XCompany connector failure after commit');
        end;
    end;
}
