namespace Origo.Bifrost.Shopify;

using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Integration.Shopify;
using Origo.Bifrost;

/// <summary>Suggests cash receipt journal lines through the Microsoft Shopify report without posting.</summary>
codeunit 73732063 "Suggest Payments Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        ExecuteBifrostTask(Rec);
    end;
    /// <summary>Reports whether the caller holds the table permissions this message type needs.</summary>
    /// <returns>True when the permissions are held.</returns>
    procedure IsEnabled(): Boolean
    var
        Shop: Record "Shpfy Shop";
        Transaction: Record "Shpfy Order Transaction";
        JournalLine: Record "Gen. Journal Line";
    begin
        exit(Shop.ReadPermission() and Transaction.ReadPermission() and JournalLine.ReadPermission() and JournalLine.WritePermission());
    end;

    /// <summary>Identifies the table used by the message filter contract.</summary>
    /// <returns>The table ID.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Shpfy Order Transaction");
    end;

    /// <summary>Describes this message type for callers selecting an operation.</summary>
    /// <returns>The description in the current language.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Suggests Shopify payments in a cash receipt journal without posting.', Comment = 'is-IS=Leggur til Shopify greiðslur í inngreiðslubók án bókunar.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search terms users say for this type, English with the Icelandic translation.</summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'shopify payments, suggest payments, cash receipt journal, order transactions, payment journal', Comment = 'is-IS=shopify greiðslur, leggja til greiðslur, inngreiðslubók, pantanafærslur, greiðslubók';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Use to suggest payments from successful Capture, Sale and Refund transactions. Writes journal lines and does not post.', Comment = 'is-IS=Notað til að leggja til greiðslur úr heppnuðum Capture, Sale og Refund færslum. Skrifar færslur í bók en bókar ekki.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Supplies the envelope chapter; the standard envelope applies.</summary>
    /// <param name="Envelope">Unchanged.</param>
    /// <returns>False; this chapter is not supplied.</returns>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Supplies the target chapter for this message type.</summary>
    /// <param name="Target">Out: the record the request addresses.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(ContractMgt.TargetEntry('Gen. Journal Batch', 'data.journalTemplateName, data.journalBatchName', 'An existing batch in a Cash Receipts template.'));
        exit(true);
    end;

    /// <summary>Declares accepted request parameters.</summary>
    /// <param name="Parameters">Receives the parameter declarations.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('journalTemplateName', 'string', true, 'Existing Cash Receipts template name, 1 to 10 characters.'));
        Parameters.Add(ContractMgt.Parameter('journalBatchName', 'string', true, 'Existing journal batch name, 1 to 10 characters.'));
        Parameters.Add(ContractMgt.Parameter('postingDate', 'string', true, 'Required ISO date, YYYY-MM-DD.'));
        Parameters.Add(ContractMgt.Parameter('expectedCount', 'integer', true, 'Exact nonnegative eligible transaction count using the filters described in Notes.'));
        Parameters.Add(ContractMgt.Parameter('shopCode', 'string', false, 'Optional enabled shop, 1 to 20 characters. Exact match, not a filter expression.'));
        Parameters.Add(ContractMgt.Parameter('createdAtFrom', 'string', false, 'Inclusive ISO 8601 Created At lower bound.'));
        Parameters.Add(ContractMgt.Parameter('createdAtTo', 'string', false, 'Inclusive ISO 8601 Created At upper bound.'));
        Parameters.Add(ContractMgt.Parameter('gateway', 'string', false, 'Optional exact gateway, up to 30 characters.'));
        Parameters.Add(ContractMgt.Parameter('startingDocumentNo', 'string', false, 'Optional starting document number, up to 20 characters; must contain a number.'));
        Parameters.Add(ContractMgt.Parameter('newDocNoPerLine', 'boolean', false, 'New document number per line. Default false.'));
        Parameters.Add(ContractMgt.Parameter('orderNoInDescription', 'boolean', false, 'Include order number in the description. Default false.'));
        exit(true);
    end;

    /// <summary>Supplies the response chapter for this message type.</summary>
    /// <param name="Response">Out: the response fields.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success.'));
        Fields.Add(ContractMgt.ResponseField('journalTemplateName', 'string', 'Cash receipt journal template.'));
        Fields.Add(ContractMgt.ResponseField('journalBatchName', 'string', 'Target batch.'));
        Fields.Add(ContractMgt.ResponseField('transactionsConsidered', 'integer', 'Eligible transactions after excluding used and already suggested transactions.'));
        Fields.Add(ContractMgt.ResponseField('journalLinesCreated', 'integer', 'Increase in journal line count in the target batch. May differ from transactionsConsidered.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Supplies the errors chapter for this message type.</summary>
    /// <param name="Errors">Receives the declared errors.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'Required parameter is missing.', 'Nothing changed.', 'Send the required parameter.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'Invalid or unknown parameter.', 'Nothing changed.', 'Read the parameter contract and use ISO dates or timestamps.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'Journal template, batch or shop not found.', 'Nothing changed.', 'Read the relevant table using Data.Records.Get.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Expected count, template type or shop state does not match.', 'Nothing changed.', 'Use a Cash Receipts template, enabled shops and refresh the eligible count.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Permission to suggest payments is required.', 'Nothing changed.', 'Ask an administrator for SHOPIFY Full ori and journal permissions.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Connector run failed.', 'Journal writes made by this run were rolled back.', 'Correct the cause and refresh the eligible count before retrying.'));
        exit(true);
    end;

    /// <summary>Supplies the effect chapter for this message type.</summary>
    /// <param name="Effect">Out: effect, changes, idempotency and preconditions.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Runs report 30118 Shpfy Suggest Payments to add general journal lines. Does not post. Connector gift card, manual gateway and invoice matching rules apply. Commits before the isolated runner; a failed runner rolls back its journal writes.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'SHOPIFY Full ori');
        exit(true);
    end;

    /// <summary>Declares that this implementation supplies no metering chapter.</summary>
    /// <param name="Metering">Unchanged.</param>
    /// <returns>False.</returns>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Supplies the related chapter for this message type.</summary>
    /// <param name="Related">Out: related message types.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', 'Count successful Capture, Sale and Refund transactions in table 30133 with Used=false and the same shop, gateway and Created At filters. Exclude transaction IDs already in Gen. Journal Line (table 81).'));
        Related.Add(ContractMgt.RelatedEntry('Shopify.Order.Import', 'Import order transactions before suggesting payments.'));
        exit(true);
    end;

    /// <summary>Declares that this implementation supplies no workflow chapter.</summary>
    /// <param name="Workflow">Unchanged.</param>
    /// <returns>False.</returns>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Returns the English examples for this message type.</summary>
    /// <param name="Examples">Out: request and answer pairs.</param>
    /// <returns>True; examples are supplied.</returns>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Suggest two payments without posting',
            '{"type":"Shopify.Transaction.SuggestPayments","data":{"journalTemplateName":"CASHRCPT","journalBatchName":"DEFAULT","postingDate":"2026-11-26","shopCode":"WEBSHOP","expectedCount":2}}',
            '{"status":"Success","journalTemplateName":"CASHRCPT","journalBatchName":"DEFAULT","transactionsConsidered":2,"journalLinesCreated":2}'));
        exit(true);
    end;

    /// <summary>Summarizes the operation.</summary>
    /// <param name="Overview">Out: the overview.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Writes suggested Shopify payment lines to an existing cash receipt journal batch through report 30118. Does not post the journal. The connector determines invoice, gift card and manual gateway handling.';
        exit(true);
    end;

    /// <summary>Explains the rules and limits of the operation.</summary>
    /// <param name="Notes">Out: the notes.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Idempotent: transactions used on customer ledger entries or already present in any general journal are excluded. Count table 30133 with Type=Capture|Sale|Refund, Status=Success, Used=false and the same optional Shop, Gateway and Created At filters; exclude transaction IDs in table 81. A repeat with the refreshed expectedCount creates no duplicate lines. The count can exceed the resulting lines because connector business rules may skip transactions or split a payment. Dates use YYYY-MM-DD; Created At bounds use ISO 8601 timestamps and are inclusive. All selected shops must be enabled. The report is isolated with Codeunit.Run and explicit connector commits are refused; failure rolls back all lines from this run. SHOPIFY Full ori plus Microsoft journal and connector permissions are required.';
        exit(true);
    end;

    /// <summary>Classifies the message direction for Foundation.</summary>
    /// <returns>The direction of the operation.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Validates the complete request before running the connector transaction.</summary>
    /// <param name="Argument">Request and typed response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        JnlTemplate: Record "Gen. Journal Template";
        Batch: Record "Gen. Journal Batch";
        Shop: Record "Shpfy Shop";
        Transactions: Record "Shpfy Order Transaction";
        Runner: Codeunit "Suggest Payments Run ori";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        ParameterName: Text;
        TextValue: Text;
        TemplateName: Text;
        BatchName: Text;
        ShopCode: Text;
        Gateway: Text;
        PostingDate: Date;
        FromDateTime: DateTime;
        ToDateTime: DateTime;
        ExpectedCount: Integer;
        ActualCount: Integer;
        IdFilter: Text;
        Raw: Text;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if not IsEnabled() then begin
            Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, 'permissions');
            exit;
        end;
        Request := Argument.GetRequestJson();
        foreach ParameterName in Request.Keys() do
            if not (ParameterName in ['journalTemplateName', 'journalBatchName', 'postingDate', 'expectedCount', 'shopCode', 'gateway', 'createdAtFrom', 'createdAtTo', 'startingDocumentNo', 'newDocNoPerLine', 'orderNoInDescription']) then begin
                Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, ParameterName);
                exit;
            end;
        if not ReadText(Argument, Request, 'journalTemplateName', true, 10, TemplateName) then
            exit;
        if not ReadText(Argument, Request, 'journalBatchName', true, 10, BatchName) then
            exit;
        if not ReadText(Argument, Request, 'postingDate', true, 10, TextValue) then
            exit;
        if not Evaluate(PostingDate, TextValue, 9) or (PostingDate = 0D) then begin
            Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'postingDate');
            exit;
        end;
        if Format(PostingDate, 0, 9) <> TextValue then begin
            Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'postingDate');
            exit;
        end;
        if not Request.Get('expectedCount', Token) then begin
            Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, 'expectedCount');
            exit;
        end;
        Token.WriteTo(Raw);
        if not Evaluate(ExpectedCount, Raw, 9) then begin
            Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'expectedCount');
            exit;
        end;
        if (ExpectedCount < 0) or (Format(ExpectedCount, 0, 9) <> Raw) then begin
            Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'expectedCount');
            exit;
        end;
        if not ReadText(Argument, Request, 'shopCode', false, 20, ShopCode) then
            exit;
        if not ReadText(Argument, Request, 'gateway', false, 30, Gateway) then
            exit;
        if not ReadText(Argument, Request, 'startingDocumentNo', false, 20, TextValue) then
            exit;
        if (TextValue <> '') and (IncStr(TextValue) = '') then begin
            Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'startingDocumentNo');
            exit;
        end;
        foreach ParameterName in Request.Keys() do
            if ParameterName in ['newDocNoPerLine', 'orderNoInDescription'] then begin
                Request.Get(ParameterName, Token);
                Token.WriteTo(Raw);
                if not (Raw in ['true', 'false']) then begin
                    Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, ParameterName);
                    exit;
                end;
            end;
        if not ReadDateTime(Argument, Request, 'createdAtFrom', FromDateTime) then
            exit;
        if not ReadDateTime(Argument, Request, 'createdAtTo', ToDateTime) then
            exit;
        if (FromDateTime <> 0DT) and (ToDateTime <> 0DT) and (FromDateTime > ToDateTime) then begin
            Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'createdAtTo');
            exit;
        end;
        JnlTemplate.SetLoadFields(Type);
        if not JnlTemplate.Get(CopyStr(TemplateName, 1, 10)) then begin
            Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'journalTemplateName');
            exit;
        end;
        if JnlTemplate.Type <> JnlTemplate.Type::"Cash Receipts" then begin
            Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'journalTemplateName');
            exit;
        end;
        if not Batch.Get(JnlTemplate.Name, CopyStr(BatchName, 1, 10)) then begin
            Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'journalBatchName');
            exit;
        end;
        if ShopCode <> '' then begin
            Shop.SetLoadFields(Enabled);
            if not Shop.Get(CopyStr(ShopCode, 1, 20)) then begin
                Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'shopCode');
                exit;
            end;
            if not Shop.Enabled then begin
                Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'shopCode');
                exit;
            end;
            Transactions.SetRange(Shop, Shop.Code);
        end;
        Transactions.SetFilter(Type, '%1|%2|%3', Transactions.Type::Capture, Transactions.Type::Sale, Transactions.Type::Refund);
        Transactions.SetRange(Status, Transactions.Status::Success);
        Transactions.SetRange(Used, false);
        if Gateway <> '' then
            Transactions.SetRange(Gateway, Gateway);
        if (FromDateTime <> 0DT) and (ToDateTime <> 0DT) then
            Transactions.SetRange("Created At", FromDateTime, ToDateTime)
        else
            if FromDateTime <> 0DT then
                Transactions.SetFilter("Created At", '>=%1', FromDateTime)
            else
                if ToDateTime <> 0DT then
                    Transactions.SetFilter("Created At", '<=%1', ToDateTime);
        if Transactions.FindSet() then
            repeat
                Shop.SetLoadFields(Enabled);
                if not Shop.Get(Transactions.Shop) then begin
                    Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'shopCode');
                    exit;
                end;
                if not Shop.Enabled then begin
                    Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'shopCode');
                    exit;
                end;
            until Transactions.Next() = 0;
        ActualCount := Runner.CollectEligible(Transactions, IdFilter);
        if ActualCount <> ExpectedCount then begin
            Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'expectedCount');
            exit;
        end;
        Runner.SetOptions(Request, Transactions.GetView(false), JnlTemplate.Name, Batch.Name, ExpectedCount);
        // The public dispatcher owns queue writes; commit them before the isolated connector transaction.
        Commit();
        ClearLastError();
        if not Runner.Run() then begin
            Refuse(Argument, "Bifrost Error Code ori"::BusinessCentralError, 'connector');
            exit;
        end;
        Response.Add('status', 'Success');
        Response.Add('journalTemplateName', JnlTemplate.Name);
        Response.Add('journalBatchName', Batch.Name);
        Response.Add('transactionsConsidered', ActualCount);
        Response.Add('journalLinesCreated', Runner.GetLinesCreated());
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure Refuse(var Argument: Record "Message Argument ori"; Code: Enum "Bifrost Error Code ori"; Parameter: Text)
    var
        MissingLbl: Label 'Required parameter %1 is missing.', Comment = '%1 = parameter||is-IS=Nauðsynlega færibreytu %1 vantar.';
        InvalidLbl: Label 'Parameter %1 is unknown or has an invalid format.', Comment = '%1 = parameter||is-IS=Færibreytan %1 er óþekkt eða á ógildu sniði.';
        NotFoundLbl: Label 'The record for parameter %1 was not found.', Comment = '%1 = parameter||is-IS=Færsla fyrir færibreytu %1 fannst ekki.';
        PreconditionLbl: Label 'Parameter %1 does not meet the preconditions: use a Cash Receipts template, an enabled shop and the exact eligible count.', Comment = '%1 = parameter||is-IS=Færibreytan %1 uppfyllir ekki forsendur: notaðu inngreiðslubók, virka verslun og nákvæman fjölda gildra færslna.';
        DeniedLbl: Label 'You do not have permission to suggest Shopify payments.', Comment = 'is-IS=Þú hefur ekki heimild til að leggja til Shopify greiðslur.';
        FailedLbl: Label 'The Shopify payment suggestion failed. Journal lines from this run were rolled back.', Comment = 'is-IS=Tillaga að Shopify greiðslum mistókst. Færslur í bók úr þessari keyrslu voru afturkallaðar.';
        ExpectedLbl: Label 'a valid parameter matching the message contract', Comment = 'is-IS=gild færibreyta sem samsvarar samningi skilaboða';
        NextLbl: Label 'Read the message help, correct the parameter and refresh the eligible count before retrying.', Comment = 'is-IS=Lestu hjálp skilaboðanna, leiðréttu færibreytuna og endurnýjaðu fjölda gildra færslna áður en þú reynir aftur.';
        MessageText: Text;
    begin
        case Code of
            Code::MissingParameter:
                MessageText := StrSubstNo(MissingLbl, Parameter);
            Code::InvalidParameterFormat:
                MessageText := StrSubstNo(InvalidLbl, Parameter);
            Code::RecordNotFound:
                MessageText := StrSubstNo(NotFoundLbl, Parameter);
            Code::PreconditionFailed:
                MessageText := StrSubstNo(PreconditionLbl, Parameter);
            Code::PermissionDenied:
                MessageText := DeniedLbl;
            else
                MessageText := FailedLbl;
        end;
        Argument.RespondWithError(Code, MessageText, Parameter, '', ExpectedLbl, NextLbl);
    end;

    local procedure ReadText(var Argument: Record "Message Argument ori"; Request: JsonObject; ParameterName: Text; Required: Boolean; MaxLength: Integer; var Value: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        Clear(Value);
        if not Request.Get(ParameterName, Token) then begin
            if not Required then
                exit(true);
            Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, ParameterName);
            exit(false);
        end;
        Token.WriteTo(Raw);
        if CopyStr(Raw, 1, 1) <> '"' then begin
            Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, ParameterName);
            exit(false);
        end;
        Value := Token.AsValue().AsText();
        if (StrLen(Value) > MaxLength) or (Required and (Value.Trim() = '')) or ((ParameterName = 'shopCode') and (Value.Trim() = '')) then begin
            Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, ParameterName);
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadDateTime(var Argument: Record "Message Argument ori"; Request: JsonObject; ParameterName: Text; var Value: DateTime): Boolean
    var
        TextValue: Text;
    begin
        if not ReadText(Argument, Request, ParameterName, false, 40, TextValue) then
            exit(false);
        if not Request.Contains(ParameterName) then
            exit(true);
        if Evaluate(Value, TextValue, 9) then
            if Value <> 0DT then
                exit(true);
        Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, ParameterName);
        exit(false);
    end;
}
