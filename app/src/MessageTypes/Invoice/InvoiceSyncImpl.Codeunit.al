namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.History;
using Origo.Bifrost;

/// <summary>Exports selected posted sales invoices as real completed, fulfilled Shopify orders through report 30119.</summary>
codeunit 73731955 "Invoice Sync Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        ExecuteBifrostTask(Rec);
    end;

    /// <summary>Checks the caller's invoice write and shop read permissions.</summary>
    /// <returns>Whether the required permissions are held.</returns>
    procedure IsEnabled(): Boolean
    var
        Invoice: Record "Sales Invoice Header";
        Shop: Record "Shpfy Shop";
    begin
        exit(Invoice.WritePermission() and Shop.ReadPermission());
    end;

    /// <summary>Identifies the posted invoice filter table.</summary>
    /// <returns>The table ID.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Sales Invoice Header");
    end;

    /// <summary>Supplies the GetDescription contract chapter.</summary>
    /// <returns>The chapter value or whether it is supplied.</returns>
    procedure GetDescription(): Text[250]
    var
        ValueLbl: Label 'Exports selected posted sales invoices as real completed, fulfilled Shopify orders.', Comment = 'is-IS=Flytur valda bókaða sölureikninga út sem raunverulegar, afgreiddar Shopify pantanir.';
    begin
        exit(ValueLbl);
    end;

    /// <summary>Supplies the GetKeywords contract chapter.</summary>
    /// <returns>The chapter value or whether it is supplied.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'shopify invoice sync, export posted sales invoices, fulfilled orders', Comment = 'is-IS=shopify reikningasamstilling, flytja út bókaða sölureikninga, afgreiddar pantanir';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Supplies the GetSelectionDescription contract chapter.</summary>
    /// <returns>The chapter value or whether it is supplied.</returns>
    procedure GetSelectionDescription(): Text
    var
        ValueLbl: Label 'Use to export 1 to 100 posted sales invoices to Shopify. Already exported invoices are skipped.', Comment = 'is-IS=Notað til að flytja 1 til 100 bókaða sölureikninga út til Shopify. Reikningum sem þegar hafa verið fluttir út er sleppt.';
    begin
        exit(ValueLbl);
    end;

    /// <summary>Supplies the GetMessageDirection contract chapter.</summary>
    /// <returns>The chapter value or whether it is supplied.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Supplies the GetEnvelope contract chapter.</summary>
    /// <param name="Envelope">Receives the chapter.</param>
    /// <returns>The chapter value or whether it is supplied.</returns>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Supplies the GetMetering contract chapter.</summary>
    /// <param name="Metering">Receives the chapter.</param>
    /// <returns>The chapter value or whether it is supplied.</returns>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Supplies the GetWorkflow contract chapter.</summary>
    /// <param name="Workflow">Receives the chapter.</param>
    /// <returns>The chapter value or whether it is supplied.</returns>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Supplies the GetTarget contract chapter.</summary>
    /// <param name="Target">Receives the chapter.</param>
    /// <returns>The chapter value or whether it is supplied.</returns>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(ContractMgt.TargetEntry('Sales Invoice Header', 'data.invoiceNos', 'Posted sales invoice numbers (table 112), exported to data.shopCode.'));
        exit(true);
    end;

    /// <summary>Supplies the GetParameters contract chapter.</summary>
    /// <param name="Parameters">Receives the chapter.</param>
    /// <returns>The chapter value or whether it is supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('shopCode', 'string', true, 'Enabled Shopify shop with Posted Invoice Sync and payment terms mapping configured.'));
        Parameters.Add(ContractMgt.Parameter('invoiceNos', 'array', true, '1 to 100 distinct posted sales invoice numbers, each at most 20 characters.'));
        Parameters.Add(ContractMgt.Parameter('expectedCount', 'integer', true, 'Must equal the number of invoiceNos.'));
        exit(true);
    end;

    /// <summary>Supplies the GetResponse contract chapter.</summary>
    /// <param name="Response">Receives the chapter.</param>
    /// <returns>The chapter value or whether it is supplied.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success means the batch was processed. Inspect each outcome; it can contain failed invoices.'));
        Fields.Add(ContractMgt.ResponseField('shopCode', 'string', 'Shop receiving the invoices.'));
        Fields.Add(ContractMgt.ResponseField('requested', 'integer', 'Number of selected invoices.'));
        Fields.Add(ContractMgt.ResponseField('exported', 'integer', 'Invoices exported by this call.'));
        Fields.Add(ContractMgt.ResponseField('failed', 'integer', 'Invoices with a failed connector call or order ID -1 or 0.'));
        Fields.Add(ContractMgt.ResponseField('notExportable', 'integer', 'Invoices with order ID -2.'));
        Fields.Add(ContractMgt.ResponseField('results', 'array', 'Per invoice: invoiceNo, outcome (exported, skipped, failed, notExportable), shopifyOrderId and text. Previously exported invoices are skipped; negative IDs are never reset or retried.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Supplies the GetErrors contract chapter.</summary>
    /// <param name="Errors">Receives the chapter.</param>
    /// <returns>The chapter value or whether it is supplied.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A required parameter is missing.', 'shopCode, invoiceNos and expectedCount are required.', 'Supply the missing parameter.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A parameter is invalid.', 'No invoices were changed.', 'Use a shop code, 1 to 100 distinct invoice numbers and an equal expectedCount.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'Shop or invoice not found.', 'No invoices were changed.', 'Check shopCode and invoiceNos.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Invoice export is not configured.', 'No invoices were changed.', 'Enable the shop, Posted Invoice Sync and payment terms mapping.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Invoice export permission is required.', 'No invoices were changed.', 'Ask an administrator for SHOPIFY Full ori and Microsoft Shopify and posted invoice permissions.'));
        exit(true);
    end;

    /// <summary>Supplies the GetEffect contract chapter.</summary>
    /// <param name="Effect">Receives the chapter.</param>
    /// <returns>The chapter value or whether it is supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Creates real completed and fulfilled Shopify orders through report 30119. Updates Shpfy Order Id and connector invoice/document links. Each invoice is a separate transaction. External orders cannot be rolled back from BC.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'SHOPIFY Full ori');
        Preconditions.Add('Shop is enabled, Posted Invoice Sync is enabled and payment terms mapping exists for each invoice or a primary mapping is configured.');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    /// <summary>Supplies the GetRelated contract chapter.</summary>
    /// <param name="Related">Receives the chapter.</param>
    /// <returns>The chapter value or whether it is supplied.</returns>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', 'Find posted invoices in table 112 and Shopify shops in table 30102.'));
        exit(true);
    end;

    /// <summary>Supplies the GetExamples contract chapter.</summary>
    /// <param name="Examples">Receives the chapter.</param>
    /// <returns>The chapter value or whether it is supplied.</returns>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Export one posted invoice',
            '{"type":"Shopify.Invoice.Sync","data":{"shopCode":"WEBSHOP","invoiceNos":["INV-1001"],"expectedCount":1}}',
            '{"status":"Success","shopCode":"WEBSHOP","requested":1,"exported":1,"failed":0,"notExportable":0,"results":[{"invoiceNo":"INV-1001","outcome":"exported","shopifyOrderId":123,"text":""}]}'));
        exit(true);
    end;

    /// <summary>Supplies the GetOverview contract chapter.</summary>
    /// <param name="Overview">Receives the chapter.</param>
    /// <returns>The chapter value or whether it is supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Exports selected posted BC sales invoices to Shopify as real completed, fulfilled orders through Microsoft report 30119. This creates external orders and writes invoice links and Shpfy Order Id in BC.';
        exit(true);
    end;

    /// <summary>Supplies the GetNotes contract chapter.</summary>
    /// <param name="Notes">Receives the chapter.</param>
    /// <returns>The chapter value or whether it is supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'All request and setup validation runs before export starts. Each invoice is processed separately, so a failed invoice does not stop later ones. Success means the batch was processed; inspect results for failures. Positive Shopify order IDs are skipped on repeat calls. IDs -1 (failed) and -2 (not exportable) are reported without retry or reset, as the connector excludes them. External Shopify orders cannot be undone by BC rollback. A connection failure after an external order is created can require reconciliation in Shopify before retry. Requires SHOPIFY Full ori, Microsoft Shopify permissions and posted invoice write permissions. No posting, credit memo export or failed-ID resetting is performed.';
        exit(true);
    end;

    /// <summary>Validates the entire request before exporting each invoice independently.</summary>
    /// <param name="Argument">Licensed dispatcher request and response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Shop: Record "Shpfy Shop";
        Invoice: Record "Sales Invoice Header";
        Request: JsonObject;
        Response: JsonObject;
        Results: JsonArray;
        Token: JsonToken;
        InvoiceNos: List of [Code[20]];
        InvoiceNo: Code[20];
        ShopCode: Text;
        ExpectedText: Text;
        ExpectedCount: Decimal;
        Exported: Integer;
        Failed: Integer;
        NotExportable: Integer;
        NoPermissionErr: Label 'You do not have permission to export posted invoices to Shopify.', Comment = 'is-IS=Þú hefur ekki heimild til að flytja bókaða reikninga út til Shopify.';
        PermissionNextLbl: Label 'Ask an administrator for SHOPIFY Full ori and Microsoft Shopify and posted invoice permissions.', Comment = 'is-IS=Biddu kerfisstjóra um SHOPIFY Full ori og Microsoft Shopify heimildir og heimildir fyrir bókaða reikninga.';
        ShopMissingErr: Label 'Shopify shop %1 was not found.', Comment = '%1 = shop code||is-IS=Shopify verslun %1 fannst ekki.';
        ShopNextLbl: Label 'Check shopCode in Shopify Shops (table 30102).', Comment = 'is-IS=Athugaðu shopCode í Shopify verslunum (tafla 30102).';
        DisabledErr: Label 'Shop %1 is not enabled.', Comment = '%1 = shop code||is-IS=Verslun %1 er ekki virk.';
        EnableNextLbl: Label 'Enable the shop on the Shopify Shop Card.', Comment = 'is-IS=Virkjaðu verslunina á Shopify verslunarspjaldinu.';
        SyncDisabledErr: Label 'Posted Invoice Sync is not enabled for shop %1.', Comment = '%1 = shop code||is-IS=Posted Invoice Sync er ekki virkt fyrir verslun %1.';
        SyncNextLbl: Label 'Enable Posted Invoice Sync on the Shopify Shop Card.', Comment = 'is-IS=Virkjaðu Posted Invoice Sync á Shopify verslunarspjaldinu.';
        TermsErr: Label 'Payment terms mapping is missing for shop %1 or invoice %2.', Comment = '%1 = shop code, %2 = invoice number||is-IS=Vörpun greiðsluskilmála vantar fyrir verslun %1 eða reikning %2.';
        TermsNextLbl: Label 'Configure Payment Terms Mapping for this invoice payment terms code or select an Is Primary mapping for the shop.', Comment = 'is-IS=Stilltu Payment Terms Mapping fyrir greiðsluskilmála reikningsins eða veldu Is Primary vörpun fyrir verslunina.';
        InvoiceMissingErr: Label 'Posted sales invoice %1 was not found.', Comment = '%1 = invoice number||is-IS=Bókaður sölureikningur %1 fannst ekki.';
        InvoiceNextLbl: Label 'Check invoiceNos in Posted Sales Invoices (table 112).', Comment = 'is-IS=Athugaðu invoiceNos í bókuðum sölureikningum (tafla 112).';
    begin
        Argument.AssertIsLicensed();
        if not IsEnabled() then begin
            Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, NoPermissionErr, 'shopCode', PermissionNextLbl);
            exit;
        end;
        Request := Argument.GetRequestJson();
        if not RequireKey(Request, 'shopCode', Argument, Token) then
            exit;
        if not ReadCode(Token, ShopCode) then begin
            InvalidRequest(Argument, 'shopCode');
            exit;
        end;
        if not ReadInvoiceNos(Argument, Request, InvoiceNos) then
            exit;
        if not RequireKey(Request, 'expectedCount', Argument, Token) then
            exit;
        Token.WriteTo(ExpectedText);
        if not Evaluate(ExpectedCount, ExpectedText, 9) then begin
            InvalidRequest(Argument, 'expectedCount');
            exit;
        end;
        if (ExpectedCount <> InvoiceNos.Count()) or (ExpectedCount <> Round(ExpectedCount, 1)) then begin
            InvalidRequest(Argument, 'expectedCount');
            exit;
        end;
        if not Shop.Get(CopyStr(ShopCode, 1, MaxStrLen(Shop.Code))) then begin
            Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, StrSubstNo(ShopMissingErr, ShopCode), 'shopCode', ShopNextLbl);
            exit;
        end;
        if not Shop.Enabled then begin
            Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(DisabledErr, Shop.Code), 'shopCode', EnableNextLbl);
            exit;
        end;
        if not Shop."Posted Invoice Sync" then begin
            Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(SyncDisabledErr, Shop.Code), 'shopCode', SyncNextLbl);
            exit;
        end;
        // Complete preflight for the whole selection before the first connector transaction.
        foreach InvoiceNo in InvoiceNos do begin
            Invoice.SetLoadFields("No.", "Payment Terms Code", "Shpfy Order Id");
            if not Invoice.Get(InvoiceNo) then begin
                Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, StrSubstNo(InvoiceMissingErr, InvoiceNo), 'invoiceNos', InvoiceNextLbl);
                exit;
            end;
            if not HasPaymentTerms(Shop.Code, Invoice."Payment Terms Code") then begin
                Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(TermsErr, Shop.Code, InvoiceNo), 'shopCode', TermsNextLbl);
                exit;
            end;
        end;
        Commit();
        foreach InvoiceNo in InvoiceNos do
            ExportInvoice(Shop.Code, InvoiceNo, Results, Exported, Failed, NotExportable);
        Response.Add('status', 'Success');
        Response.Add('shopCode', Shop.Code);
        Response.Add('requested', InvoiceNos.Count());
        Response.Add('exported', Exported);
        Response.Add('failed', Failed);
        Response.Add('notExportable', NotExportable);
        Response.Add('results', Results);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure ReadInvoiceNos(var Argument: Record "Message Argument ori"; Request: JsonObject; var InvoiceNos: List of [Code[20]]): Boolean
    var
        Token: JsonToken;
        Entry: JsonToken;
        Nos: JsonArray;
        NoText: Text;
        InvoiceNo: Code[20];
    begin
        if not RequireKey(Request, 'invoiceNos', Argument, Token) then
            exit(false);
        if not Token.IsArray() then
            exit(InvalidRequest(Argument, 'invoiceNos'));
        Nos := Token.AsArray();
        if (Nos.Count() < 1) or (Nos.Count() > 100) then
            exit(InvalidRequest(Argument, 'invoiceNos'));
        foreach Entry in Nos do begin
            if not ReadCode(Entry, NoText) then
                exit(InvalidRequest(Argument, 'invoiceNos'));
            InvoiceNo := CopyStr(NoText, 1, MaxStrLen(InvoiceNo));
            if InvoiceNos.Contains(InvoiceNo) then
                exit(InvalidRequest(Argument, 'invoiceNos'));
            InvoiceNos.Add(InvoiceNo);
        end;
        exit(true);
    end;

    local procedure ReadCode(Token: JsonToken; var Value: Text): Boolean
    var
        Serialized: Text;
    begin
        Token.WriteTo(Serialized);
        if not Serialized.StartsWith('"') then
            exit(false);
        Value := Token.AsValue().AsText();
        exit((Value.Trim() <> '') and (StrLen(Value) <= 20));
    end;

    local procedure RequireKey(Request: JsonObject; PropertyName: Text; var Argument: Record "Message Argument ori"; var Token: JsonToken): Boolean
    var
        MissingErr: Label 'Parameter "%1" is required.', Comment = '%1 = parameter name||is-IS=Færibreytan "%1" er nauðsynleg.';
        NextLbl: Label 'Send data.%1 with the required value.', Comment = '%1 = parameter name||is-IS=Sendu data.%1 með nauðsynlegu gildi.';
    begin
        if Request.Get(PropertyName, Token) then
            exit(true);
        Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingErr, PropertyName), PropertyName, StrSubstNo(NextLbl, PropertyName));
        exit(false);
    end;

    local procedure InvalidRequest(var Argument: Record "Message Argument ori"; PropertyName: Text): Boolean
    var
        InvalidErr: Label 'Parameter "%1" has an invalid format or count.', Comment = '%1 = parameter name||is-IS=Færibreytan "%1" er á ógildu sniði eða með rangan fjölda.';
        NextLbl: Label 'Send shopCode as a code of at most 20 characters, invoiceNos as 1 to 100 distinct invoice numbers of at most 20 characters, and expectedCount as their exact integer count.', Comment = 'is-IS=Sendu shopCode sem kóða með að hámarki 20 stöfum, invoiceNos sem 1 til 100 ólík reikningsnúmer með að hámarki 20 stöfum og expectedCount sem nákvæman heiltölufjölda þeirra.';
    begin
        Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidErr, PropertyName), PropertyName, NextLbl);
        exit(false);
    end;

    local procedure Refuse(var Argument: Record "Message Argument ori"; ErrorCode: Enum "Bifrost Error Code ori"; MessageText: Text; Parameter: Text; NextStep: Text)
    begin
        Argument.RespondWithError(ErrorCode, MessageText, Parameter, '', '', NextStep);
    end;

    local procedure HasPaymentTerms(ShopCode: Code[20]; PaymentTermsCode: Code[10]): Boolean
    var
        Terms: RecordRef;
        Field: FieldRef;
        Found: Boolean;
    begin
        // Shopify's payment terms table is internal. Read its stable table/field IDs instead of internal procedures.
        Terms.Open(30158);
        Field := Terms.Field(1);
        Field.SetRange(ShopCode);
        Field := Terms.Field(70);
        Field.SetRange(PaymentTermsCode);
        Found := (PaymentTermsCode <> '') and not Terms.IsEmpty();
        if not Found then begin
            Field.SetRange();
            Field := Terms.Field(60);
            Field.SetRange(true);
            Found := not Terms.IsEmpty();
        end;
        Terms.Close();
        exit(Found);
    end;

    local procedure SkippedReason(Invoice: Record "Sales Invoice Header") Reason: Text
    var
        Skipped: RecordRef;
        Field: FieldRef;
    begin
        // The connector exposes its validation reason in the internal skipped-record log when logging is enabled.
        Skipped.Open(30159);
        Field := Skipped.Field(5);
        Field.SetRange(Invoice.RecordId());
        if Skipped.FindLast() then begin
            Field := Skipped.Field(7);
            Reason := Field.Value();
        end;
        Skipped.Close();
    end;

    local procedure ExportInvoice(ShopCode: Code[20]; InvoiceNo: Code[20]; var Results: JsonArray; var Exported: Integer; var Failed: Integer; var NotExportable: Integer)
    var
        Invoice: Record "Sales Invoice Header";
        SyncRun: Codeunit "Invoice Sync Run ori";
        Result: JsonObject;
        Outcome: Text;
        Detail: Text;
        Ran: Boolean;
        FailedLbl: Label 'The Shopify connector did not create an order. Check Shopify logs before retrying; negative order IDs are not reset.', Comment = 'is-IS=Shopify tengillinn stofnaði ekki pöntun. Athugaðu Shopify annála áður en reynt er aftur; neikvæð pöntunarauðkenni eru ekki endurstillt.';
        NotExportableLbl: Label 'The Shopify connector marked this invoice as not exportable. Check Shopify Skipped Records for the reason.', Comment = 'is-IS=Shopify tengillinn merkti þennan reikning sem óhæfan til útflutnings. Athugaðu Shopify Skipped Records til að sjá ástæðuna.';
    begin
        Invoice.Get(InvoiceNo);
        if Invoice."Shpfy Order Id" > 0 then
            Outcome := 'skipped'
        else begin
            Ran := true;
            if Invoice."Shpfy Order Id" = 0 then begin
                SyncRun.SetInvoice(ShopCode, InvoiceNo);
                ClearLastError();
                Ran := SyncRun.Run();
                Detail := GetLastErrorText();
                Invoice.Get(InvoiceNo);
            end;
            if not Ran then begin
                Outcome := 'failed';
                Failed += 1;
            end else
                case Invoice."Shpfy Order Id" of
                    -2:
                        begin
                            Outcome := 'notExportable';
                            NotExportable += 1;
                            Detail := SkippedReason(Invoice);
                            if Detail = '' then
                                Detail := NotExportableLbl;
                        end;
                    -1, 0:
                        begin
                            Outcome := 'failed';
                            Failed += 1;
                            if Detail = '' then
                                Detail := FailedLbl;
                        end;
                    else begin
                        Outcome := 'exported';
                        Exported += 1;
                    end;
                end;
        end;
        Result.Add('invoiceNo', InvoiceNo);
        Result.Add('outcome', Outcome);
        Result.Add('shopifyOrderId', Invoice."Shpfy Order Id");
        Result.Add('text', Detail);
        Results.Add(Result);
    end;
}
