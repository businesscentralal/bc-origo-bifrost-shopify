namespace Origo.Bifrost.Shopify.Test;

using Origo.Bifrost.Shopify;

/// <summary>
/// Issue #12: stands in for the live Shopify API of report Shpfy Sync Images. Bound manually; records that the connector
/// run was reached with which shop and filter, or fails the run on request.
/// </summary>
codeunit 97541 "Shpfy SyncImg Stub ori"
{
    EventSubscriberInstance = Manual;

    var
        FailRun: Boolean;
        Calls: Integer;
        LastShopCode: Code[20];
        LastFilter: Text;

    /// <summary>Makes the next connector runs fail with an error.</summary>
    /// <param name="NewFailRun">True to fail.</param>
    procedure SetFailRun(NewFailRun: Boolean)
    begin
        FailRun := NewFailRun;
    end;

    /// <summary>The number of connector runs reached.</summary>
    /// <returns>The count.</returns>
    procedure GetCalls(): Integer
    begin
        exit(Calls);
    end;

    /// <summary>The shop code of the last run.</summary>
    /// <returns>The shop code.</returns>
    procedure GetLastShopCode(): Code[20]
    begin
        exit(LastShopCode);
    end;

    /// <summary>The product filter of the last run.</summary>
    /// <returns>The filter text.</returns>
    procedure GetLastFilter(): Text
    begin
        exit(LastFilter);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Product SyncImages Run ori", 'OnBeforeRunConnector', '', false, false)]
    local procedure HandleConnector(ForShopCode: Code[20]; ForProductIdFilter: Text; var IsHandled: Boolean)
    var
        StubFailureErr: Label 'Stub connector failure', Locked = true;
    begin
        Calls += 1;
        LastShopCode := ForShopCode;
        LastFilter := ForProductIdFilter;
        IsHandled := true;
        if FailRun then
            Error(StubFailureErr);
    end;
}
