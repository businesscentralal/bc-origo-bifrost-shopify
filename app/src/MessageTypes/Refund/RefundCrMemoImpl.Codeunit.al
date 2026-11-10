namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.Document;
using Origo.Bifrost;

/// <summary>
/// Implementation of <c>Shopify.Refund.CreateCreditMemo</c>. Creates the Business Central credit memo of an
/// imported Shopify refund through the shop's own refund process (Shpfy RetRefProc Cr.Memo, which runs
/// Shpfy Create Sales Doc. Refund, codeunit 30246).
/// </summary>
codeunit 70013404 "Refund CrMemo Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Reports whether the caller holds the table permissions this message type needs.</summary>
    /// <returns>True when the permissions are held.</returns>
    procedure IsEnabled(): Boolean
    var
        RefundHeader: Record "Shpfy Refund Header";
        Shop: Record "Shpfy Shop";
        SalesHeader: Record "Sales Header";
    begin
        exit(RefundHeader.WritePermission() and Shop.ReadPermission() and SalesHeader.WritePermission());
    end;

    /// <summary>Identifies the table used by the message filter contract.</summary>
    /// <returns>The table ID.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Shpfy Refund Header");
    end;

    /// <summary>Describes this message type for callers selecting an operation.</summary>
    /// <returns>The description in the current language.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Creates the Business Central credit memo of an imported Shopify refund.', Comment = 'is-IS=Býr til kreditreikning í Business Central fyrir innflutta Shopify endurgreiðslu.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search terms users say for this type, English with the Icelandic translation.</summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'shopify refund, create credit memo, refund credit memo, process shopify refund, return money to customer', Comment = 'is-IS=shopify endurgreiðsla, búa til kreditreikning, kreditreikningur endurgreiðslu, vinna shopify endurgreiðslu, endurgreiða viðskiptavini';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Use for an already imported Shopify refund whose shop is set to Auto Create Credit Memo and that has no credit memo yet. It does not import refunds from Shopify and does not post the credit memo.', Comment = 'is-IS=Notað fyrir innflutta Shopify endurgreiðslu þar sem verslun er stillt á Auto Create Credit Memo og enginn kreditreikningur er til. Flytur ekki inn endurgreiðslur frá Shopify og bókar ekki kreditreikninginn.';
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
        Target.Add(ContractMgt.TargetEntry('Shpfy Refund Header', 'data.refundId', 'The Shopify refund Id of an imported refund (table 30142).'));
        exit(true);
    end;

    /// <summary>Declares accepted request parameters.</summary>
    /// <param name="Parameters">Receives the parameter declarations.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('refundId', 'integer', true, 'The Shopify Refund Id of an imported refund, e.g. from Data.Records.Get on table 30142.'));
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
        Fields.Add(ContractMgt.ResponseField('refundId', 'integer', 'The Shopify Refund Id.'));
        Fields.Add(ContractMgt.ResponseField('documentType', 'string', 'The document type of the created sales document, normally Credit Memo (the shop''s Process Returns As).'));
        Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The No. of the created sales document.'));
        Fields.Add(ContractMgt.ResponseField('documentStatus', 'string', 'The status of the created document after the release, normally Released.'));
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
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'Parameter "refundId" is required.', 'The request has no refundId. Nothing was changed.', 'Send data.refundId with the Shopify Refund Id.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'Parameter "refundId" must be a whole number greater than 0.', 'The value is not a positive integer. Nothing was changed.', 'Send the Shopify Refund Id as a number.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'Shopify refund {id} was not found.', 'No imported refund has this Id. Nothing was changed.', 'Import the refund first, or read table 30142 with Data.Records.Get.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Shopify refund {id} already has a credit memo or was processed.', 'The refund is already processed. Nothing was changed.', 'Nothing to do.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Shop {code} does not create credit memos automatically.', 'The shop''s Return and Refund Process is not Auto Create Credit Memo. Nothing was changed.', 'Set the shop''s Return and Refund Process to Auto Create Credit Memo.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Can not create a credit memo for the refund {id}.', 'Business Central refused: the Shopify order is not processed yet, a refund line cannot create a credit memo, refund transactions are pending, or setup is missing. The refund keeps the error text and nothing is created.', 'Fix the cause named in the text, then call again.'));
        exit(true);
    end;

    /// <summary>Supplies the effect chapter for this message type.</summary>
    /// <param name="Effect">Out: effect, changes, idempotency and preconditions.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The refund is imported and not yet processed (no linked credit memo).');
        Preconditions.Add('The shop''s Return and Refund Process is Auto Create Credit Memo.');
        Preconditions.Add('The Shopify order of the refund is processed and no refund line is blocked from creating a credit memo.');
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Runs the shop''s refund process (Shpfy Create Sales Doc. Refund): inserts and releases a sales document of the shop''s Process Returns As type with its lines, and links it to the refund. The Shopify code commits (Commit()) before and after the creation, so the result is kept even if a later step of the message fails.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'SHOPIFY Full ori');
        Effect.Add('preconditions', Preconditions);
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
        Related.Add(ContractMgt.RelatedEntry('Sales.Document.Post', 'You want to post the created credit memo.'));
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', 'You need to find the refund, e.g. table 30142 Shpfy Refund Header.'));
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
        Examples.Add(ContractMgt.Example('Create the credit memo of a refund',
            '{"type":"Shopify.Refund.CreateCreditMemo","data":{"refundId":901234567}}',
            '{"status":"Success","refundId":901234567,"documentType":"Credit Memo","documentNo":"1001","documentStatus":"Released"}'));
        exit(true);
    end;

    /// <summary>Summarizes the operation.</summary>
    /// <param name="Overview">Out: the overview.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Creates the Business Central credit memo of an imported Shopify refund through the shop''s refund process (codeunit Shpfy RetRefProc Cr.Memo, which runs Shpfy Create Sales Doc. Refund 30246), so Business Central''s own validation and checks run.';
        exit(true);
    end;

    /// <summary>Explains the rules and limits of the operation.</summary>
    /// <param name="Notes">Out: the notes.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Not idempotent: a second call on the same refund answers that it is already processed. The shop must have Return and Refund Process = Auto Create Credit Memo. The Shopify code commits before and after the creation. A refusal from the Shopify process is returned as a refusal and creates nothing; the refund keeps the error text on its Has Processing Error and Last Error Description fields. Permissions: SHOPIFY Full ori, plus the Microsoft Shopify permissions for the refund and sales documents.';
        exit(true);
    end;

    /// <summary>Classifies the message direction for Foundation.</summary>
    /// <returns>The direction of the operation.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Validates the request and creates the credit memo through the shop's refund process.</summary>
    /// <param name="Argument">The licensed request; receives the response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RefundHeader: Record "Shpfy Refund Header";
        Shop: Record "Shpfy Shop";
        SalesHeader: Record "Sales Header";
        RefundProcess: Interface "Shpfy IReturnRefund Process";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        ErrorInfo: ErrorInfo;
        RefundIdText: Text;
        ErrorText: Text;
        RefundId: BigInteger;
        NoPermissionErr: Label 'You do not have the permissions to create credit memos from Shopify refunds.', Comment = 'is-IS=Þú hefur ekki heimildir til að búa til kreditreikninga úr Shopify endurgreiðslum.';
        PermissionExpectedLbl: Label 'a user with the permission set SHOPIFY Full ori and the Shopify Connector permissions', Comment = 'is-IS=notandi með heimildasettið SHOPIFY Full ori og heimildir Shopify Connector';
        AskAdminLbl: Label 'Ask an administrator to assign the permission set SHOPIFY Full ori.', Comment = 'is-IS=Biddu kerfisstjóra um að úthluta heimildasettinu SHOPIFY Full ori.';
        MissingErr: Label 'Parameter "refundId" is required.', Comment = 'is-IS=Færibreytan "refundId" er nauðsynleg.';
        MissingNextLbl: Label 'Send data.refundId with the Shopify Refund Id.', Comment = 'is-IS=Sendu data.refundId með auðkenni Shopify endurgreiðslunnar.';
        NumberExpectedLbl: Label 'a whole number greater than 0', Comment = 'is-IS=heiltala stærri en 0';
        InvalidErr: Label 'Parameter "refundId" must be a whole number greater than 0.', Comment = 'is-IS=Færibreytan "refundId" verður að vera heiltala stærri en 0.';
        InvalidNextLbl: Label 'Send the Shopify Refund Id as a number.', Comment = 'is-IS=Sendu auðkenni Shopify endurgreiðslunnar sem tölu.';
        NotFoundErr: Label 'Shopify refund %1 was not found.', Comment = '%1 = Refund Id||is-IS=Shopify endurgreiðsla %1 fannst ekki.';
        ImportedExpectedLbl: Label 'the Id of an imported refund', Comment = 'is-IS=auðkenni innfluttrar endurgreiðslu';
        ImportFirstLbl: Label 'Import the refund first, or read table 30142 with Data.Records.Get.', Comment = 'is-IS=Fluttu endurgreiðsluna fyrst inn eða lestu töflu 30142 með Data.Records.Get.';
        ProcessedErr: Label 'Shopify refund %1 is already processed.', Comment = '%1 = Refund Id||is-IS=Shopify endurgreiðsla %1 hefur þegar verið unnin.';
        UnprocessedExpectedLbl: Label 'a refund that is not processed', Comment = 'is-IS=endurgreiðsla sem hefur ekki verið unnin';
        NothingToDoLbl: Label 'Nothing to do.', Comment = 'is-IS=Ekkert að gera.';
        NotAutoErr: Label 'Shop %1 does not create credit memos automatically.', Comment = '%1 = Shop code||is-IS=Verslun %1 býr ekki til kreditreikninga sjálfkrafa.';
        AutoExpectedLbl: Label 'a shop with Return and Refund Process = Auto Create Credit Memo', Comment = 'is-IS=verslun með Return and Refund Process = Auto Create Credit Memo';
        SetAutoLbl: Label 'Set the shop''s Return and Refund Process to Auto Create Credit Memo.', Comment = 'is-IS=Stilltu Return and Refund Process verslunarinnar á Auto Create Credit Memo.';
        CreatedExpectedLbl: Label 'a refund that Business Central can create a credit memo for', Comment = 'is-IS=endurgreiðsla sem Business Central getur búið til kreditreikning fyrir';
        FixCauseLbl: Label 'Fix the cause named in the text, then call again.', Comment = 'is-IS=Lagaðu orsökina sem textinn nefnir og kallaðu aftur.';
        RefusedErr: Label 'Can not create a credit memo for the refund %1. %2', Comment = '%1 = Refund Id, %2 = detailed text||is-IS=Ekki er hægt að búa til kreditreikning fyrir endurgreiðsluna %1. %2';
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if not IsEnabled() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, NoPermissionErr, 'refundId', '', PermissionExpectedLbl, AskAdminLbl);
            exit;
        end;
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('refundId', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, 'refundId', '', NumberExpectedLbl, MissingNextLbl);
            exit;
        end;
        RefundIdText := Argument.TokenAsText(Token);
        if not Evaluate(RefundId, RefundIdText, 9) or (RefundId < 1) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidErr, 'refundId', RefundIdText, NumberExpectedLbl, InvalidNextLbl);
            exit;
        end;
        RefundHeader.SetAutoCalcFields("Is Processed");
        if not RefundHeader.Get(RefundId) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, RefundId), 'refundId', Format(RefundId, 0, 9), ImportedExpectedLbl, ImportFirstLbl);
            exit;
        end;
        if RefundHeader."Is Processed" then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(ProcessedErr, RefundId), 'refundId', Format(RefundId, 0, 9), UnprocessedExpectedLbl, NothingToDoLbl);
            exit;
        end;
        Shop.Get(RefundHeader."Shop Code");
        if Shop."Return and Refund Process" <> Shop."Return and Refund Process"::"Auto Create Credit Memo" then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NotAutoErr, Shop.Code), 'refundId', Format(RefundId, 0, 9), AutoExpectedLbl, SetAutoLbl);
            exit;
        end;

        // The shop's own refund process checks the refund, runs codeunit 30246 and commits.
        RefundProcess := Shop."Return and Refund Process";
        if not RefundProcess.CanCreateSalesDocumentFor("Shpfy Source Document Type"::Refund, RefundId, ErrorInfo) then
            if ErrorInfo.Verbosity = Verbosity::Error then begin
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, ErrorInfo.Message, 'refundId', Format(RefundId, 0, 9), CreatedExpectedLbl, FixCauseLbl);
                exit;
            end;
        SalesHeader := RefundProcess.CreateSalesDocument("Shpfy Source Document Type"::Refund, RefundId);
        if SalesHeader."No." = '' then begin
            ErrorText := ReadLastError(RefundId);
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, StrSubstNo(RefusedErr, RefundId, ErrorText), 'refundId', Format(RefundId, 0, 9), CreatedExpectedLbl, FixCauseLbl);
            exit;
        end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('refundId', RefundId);
        ResponseJson.Add('documentType', Format(SalesHeader."Document Type"));
        ResponseJson.Add('documentNo', SalesHeader."No.");
        ResponseJson.Add('documentStatus', Format(SalesHeader.Status));
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure ReadLastError(RefundId: BigInteger): Text
    var
        RefundHeader: Record "Shpfy Refund Header";
        InStr: InStream;
        ErrorText: Text;
    begin
        if not RefundHeader.Get(RefundId) then
            exit('');
        RefundHeader.CalcFields("Last Error Description");
        RefundHeader."Last Error Description".CreateInStream(InStr, TextEncoding::UTF8);
        InStr.ReadText(ErrorText);
        exit(ErrorText);
    end;
}
