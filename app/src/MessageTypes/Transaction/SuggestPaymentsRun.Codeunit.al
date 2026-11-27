namespace Origo.Bifrost.Shopify;

using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Integration.Shopify;
using System.Reflection;

/// <summary>Runs report 30118 inside an isolated transaction, with no explicit connector commits.</summary>
codeunit 73732064 "Suggest Payments Run ori"
{
    Access = Internal;

    var
        Options: JsonObject;
        TransactionView: Text;
        TemplateName: Code[10];
        BatchName: Code[10];
        ExpectedCount: Integer;
        LinesCreated: Integer;

    trigger OnRun()
    var
        Transactions: Record "Shpfy Order Transaction";
        Lines: Record "Gen. Journal Line";
        UIGuard: Codeunit "Suggest Payments UI Guard ori";
        BeforeCount: Integer;
        IdFilter: Text;
        Handled: Boolean;
        ChangedLbl: Label 'The eligible transaction count changed. Refresh the count and retry.', Comment = 'is-IS=Fjöldi gildra færslna breyttist. Endurnýjaðu fjöldann og reyndu aftur.';
    begin
        Lines.LockTable();
        Transactions.LockTable();
        // tableView validated by the caller: generated from typed SetRange/SetFilter only.
        Transactions.SetView(TransactionView);
        if CollectEligible(Transactions, IdFilter) <> ExpectedCount then
            Error(ChangedLbl);
        Lines.SetRange("Journal Template Name", TemplateName);
        Lines.SetRange("Journal Batch Name", BatchName);
        BeforeCount := Lines.Count();
        if ExpectedCount > 0 then begin
            Transactions.SetFilter("Shopify Transaction Id", IdFilter);
            BindSubscription(UIGuard);
            RunConnector(Transactions, Handled);
            UnbindSubscription(UIGuard);
        end;
        LinesCreated := Lines.Count() - BeforeCount;
    end;

    /// <summary>Sets the validated request and selection for the isolated run.</summary>
    /// <param name="NewOptions">Report options.</param>
    /// <param name="NewView">Eligible transaction filters.</param>
    /// <param name="NewTemplateName">Target template.</param>
    /// <param name="NewBatchName">Target batch.</param>
    /// <param name="NewExpectedCount">Count confirmed by the caller.</param>
    procedure SetOptions(NewOptions: JsonObject; NewView: Text; NewTemplateName: Code[10]; NewBatchName: Code[10]; NewExpectedCount: Integer)
    begin
        Options := NewOptions;
        TransactionView := NewView;
        TemplateName := NewTemplateName;
        BatchName := NewBatchName;
        ExpectedCount := NewExpectedCount;
    end;

    /// <summary>Returns the increase in lines in the selected batch.</summary>
    /// <returns>New lines created by the connector.</returns>
    procedure GetLinesCreated(): Integer
    begin
        exit(LinesCreated);
    end;

    /// <summary>Counts eligible transactions and builds their literal ID selection, excluding existing journal lines.</summary>
    /// <param name="Transactions">Transactions with the request and connector eligibility filters applied.</param>
    /// <param name="IdFilter">Literal transaction IDs for the connector report.</param>
    /// <returns>Eligible count.</returns>
    procedure CollectEligible(var Transactions: Record "Shpfy Order Transaction"; var IdFilter: Text) Count: Integer
    var
        Lines: Record "Gen. Journal Line";
    begin
        Clear(IdFilter);
        Transactions.SetLoadFields("Shopify Transaction Id", Shop);
        if Transactions.FindSet() then
            repeat
                Lines.SetRange("Shpfy Transaction Id", Transactions."Shopify Transaction Id");
                if Lines.IsEmpty() then begin
                    if IdFilter <> '' then
                        IdFilter += '|';
                    IdFilter += Format(Transactions."Shopify Transaction Id", 0, 9);
                    Count += 1;
                end;
            until Transactions.Next() = 0;
    end;

    [CommitBehavior(CommitBehavior::Error)]
    local procedure RunConnector(var Transactions: Record "Shpfy Order Transaction"; var Handled: Boolean)
    begin
        OnBeforeRunConnector(Transactions, Options, Handled);
        if not Handled then
            Report.Execute(30118, BuildRequestXml(Transactions));
    end;

    local procedure BuildRequestXml(Transactions: Record "Shpfy Order Transaction"): Text
    var
        TypeHelper: Codeunit "Type Helper";
        Xml: TextBuilder;
        OptionNames: List of [Text];
        FieldNames: List of [Text];
        Token: JsonToken;
        Value: Text;
        Index: Integer;
        ViewText: Text;
    begin
        OptionNames := 'journalTemplateName,journalBatchName,postingDate,startingDocumentNo,newDocNoPerLine,gateway,orderNoInDescription'.Split(',');
        FieldNames := 'JnlTemplateName,JnlBatchName,Posting Date,Starting Document No.,New Doc. No. Per Line,Transaction Gateway,Order No. In Description'.Split(',');
        Xml.Append('<?xml version="1.0" standalone="yes"?><ReportParameters name="Suggest Shopify Payments" id="30118"><Options>');
        for Index := 1 to OptionNames.Count() do
            if Options.Get(OptionNames.Get(Index), Token) then begin
                Value := Token.AsValue().AsText();
                Xml.Append('<Field name="' + FieldNames.Get(Index) + '">' + TypeHelper.HtmlEncode(Value) + '</Field>');
            end;
        ViewText := Transactions.GetView(false);
        Xml.Append('</Options><DataItems><DataItem name="OrderTransaction">' + TypeHelper.HtmlEncode(ViewText) + '</DataItem></DataItems></ReportParameters>');
        exit(Xml.ToText());
    end;

    /// <summary>Allows the test app to stand in for the connector without credentials or Shopify calls.</summary>
    /// <param name="Transactions">Exact eligible transaction selection.</param>
    /// <param name="Request">Validated report options.</param>
    /// <param name="Handled">True skips the connector.</param>
    [IntegrationEvent(false, false)]
    internal procedure OnBeforeRunConnector(var Transactions: Record "Shpfy Order Transaction"; Request: JsonObject; var Handled: Boolean)
    begin
    end;
}
