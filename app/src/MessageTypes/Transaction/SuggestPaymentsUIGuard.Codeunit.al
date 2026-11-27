namespace Origo.Bifrost.Shopify;

using Microsoft.Finance.GeneralLedger.Journal;

/// <summary>Suppresses the report's final journal navigation only while manually bound by the payment runner.</summary>
codeunit 73732062 "Suggest Payments UI Guard ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::GenJnlManagement, OnBeforeOpenJournalPageFromBatch, '', false, false)]
    local procedure SuppressJournalNavigation(var GenJnlBatch: Record "Gen. Journal Batch"; GenJnlTemplate: Record "Gen. Journal Template"; var IsHandled: Boolean)
    begin
        IsHandled := true;
    end;
}
