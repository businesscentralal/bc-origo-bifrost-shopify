namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Integration.Shopify;
using Origo.Bifrost.Shopify;

/// <summary>Mock-only connector for reserved BIFT34 requests; never accesses a provider or credential.</summary>
codeunit 97511 "Shpfy Suggest Stub ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Suggest Payments Run ori", OnBeforeRunConnector, '', false, false)]
    local procedure StandIn(var Transactions: Record "Shpfy Order Transaction"; Request: JsonObject; var Handled: Boolean)
    var
        Line: Record "Gen. Journal Line";
        Batch: Record "Gen. Journal Batch";
        JnlManagement: Codeunit GenJnlManagement;
        Token: JsonToken;
        TemplateName: Text;
        BatchName: Text;
        PostingDate: Date;
        LineNo: Integer;
        FailureLbl: Label 'Mock connector failure after inserting a line.', Locked = true;
    begin
        Request.Get('journalTemplateName', Token);
        TemplateName := Token.AsValue().AsText();
        if TemplateName <> 'BIFT34' then
            exit;
        // Refuse to intercept non-fixture transactions, even if a caller chooses the fixture template.
        if Transactions.FindSet() then
            repeat
                if (Transactions.Shop <> 'BIFT34') or (Transactions."Shopify Transaction Id" < 3400001) or (Transactions."Shopify Transaction Id" > 3400099) then
                    exit;
            until Transactions.Next() = 0;
        Handled := true;
        Request.Get('journalBatchName', Token);
        BatchName := Token.AsValue().AsText();
        Request.Get('postingDate', Token);
        Evaluate(PostingDate, Token.AsValue().AsText(), 9);
        Line.SetRange("Journal Template Name", TemplateName);
        Line.SetRange("Journal Batch Name", BatchName);
        if Line.FindLast() then
            LineNo := Line."Line No.";
        if Transactions.FindSet() then
            repeat
                LineNo += 10000;
                Line.Init();
                Line."Journal Template Name" := CopyStr(TemplateName, 1, 10);
                Line."Journal Batch Name" := CopyStr(BatchName, 1, 10);
                Line."Line No." := LineNo;
                Line."Posting Date" := PostingDate;
                Line."Shpfy Transaction Id" := Transactions."Shopify Transaction Id";
                Line.Amount := -Transactions.Amount;
                Line.Insert();
                if Transactions.Gateway = 'FAIL' then
                    Error(FailureLbl);
                if Transactions.Gateway = 'COMMIT' then
                    Commit();
            until Transactions.Next() = 0;
        // Exercise the same base-app navigation event as report 30118 OnPostReport.
        Batch.Get(TemplateName, BatchName);
        JnlManagement.TemplateSelectionFromBatch(Batch);
    end;
}
