namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.Document;
using Origo.Bifrost;

/// <summary>
/// Implementation of <c>Shopify.Order.CreateSalesDocument</c>. Creates the Business Central sales order or invoice
/// of one imported Shopify order through the standard report 30103 Shpfy Create Sales Orders, which runs
/// codeunit 30167 Shpfy Process Orders and codeunit 30166 Shpfy Process Order.
/// </summary>
codeunit 73732020 "Order CreateSalesDoc Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Reports whether the caller holds the table permissions this message type needs.</summary>
    /// <returns>True when the permissions are held.</returns>
    procedure IsEnabled(): Boolean
    var
        OrderHeader: Record "Shpfy Order Header";
        Shop: Record "Shpfy Shop";
        SalesHeader: Record "Sales Header";
        RefundHeader: Record "Shpfy Refund Header";
    begin
        exit(OrderHeader.WritePermission() and Shop.ReadPermission() and SalesHeader.WritePermission() and RefundHeader.ReadPermission());
    end;

    /// <summary>Identifies the table used by the message filter contract.</summary>
    /// <returns>The table ID.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Shpfy Order Header");
    end;

    /// <summary>Describes this message type for callers selecting an operation.</summary>
    /// <returns>The description in the current language.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Creates the Business Central sales order or invoice of an imported Shopify order.', Comment = 'is-IS=Býr til sölupöntun eða reikning í Business Central fyrir innflutta Shopify pöntun.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search terms users say for this type, English with the Icelandic translation.</summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'shopify order, create sales order, create sales invoice, process shopify order, convert shopify order', Comment = 'is-IS=shopify pöntun, búa til sölupöntun, búa til sölureikning, vinna shopify pöntun, umbreyta shopify pöntun';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Use for an already imported Shopify order that has no sales document yet. It does not import orders from Shopify and does not post the sales document.', Comment = 'is-IS=Notað fyrir innflutta Shopify pöntun sem hefur engan sölureikning eða sölupöntun. Flytur ekki inn pantanir frá Shopify og bókar ekki sölufylgiskjalið.';
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
        Target.Add(ContractMgt.TargetEntry('Shpfy Order Header', 'data.shopifyOrderId', 'The Shopify Order Id of an imported order (table 30118).'));
        exit(true);
    end;

    /// <summary>Declares accepted request parameters.</summary>
    /// <param name="Parameters">Receives the parameter declarations.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('shopifyOrderId', 'integer', true, 'The Shopify Order Id of an imported order, e.g. from Data.Records.Get on table 30118.'));
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
        Fields.Add(ContractMgt.ResponseField('shopifyOrderId', 'integer', 'The Shopify Order Id.'));
        Fields.Add(ContractMgt.ResponseField('documentType', 'string', 'The document type of the created sales document: Order, or Invoice when the shop creates invoices for fulfilled orders.'));
        Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The No. of the created sales document.'));
        Fields.Add(ContractMgt.ResponseField('documentStatus', 'string', 'The status of the created document: Released when the shop auto-releases sales orders, otherwise Open.'));
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
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'Parameter "shopifyOrderId" is required.', 'The request has no shopifyOrderId. Nothing was changed.', 'Send data.shopifyOrderId with the Shopify Order Id.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'Parameter "shopifyOrderId" must be a whole number greater than 0.', 'The value is not a positive integer. Nothing was changed.', 'Send the Shopify Order Id as a number.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'Shopify order {id} was not found.', 'No imported order has this Id. Nothing was changed.', 'Import the order from Shopify first, or read table 30118 with Data.Records.Get.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Shopify order {id} is already processed.', 'The order already has a sales document. Nothing was changed.', 'Nothing to do.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Shop {shop} creates credit memos for refunds automatically and there are unprocessed refunds.', 'The standard Shopify process would also create credit memos for every unprocessed refund, of any order and any shop. Nothing was changed.', 'Process the refunds first, or create the documents with the standard Create Sales Orders action.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Can not create a sales document for the Shopify order {id}.', 'Business Central refused: the customer or an item cannot be mapped or is blocked, or setup is missing. The order keeps the error text in Has Error and Error Message, and the partly created document is removed.', 'Fix the cause named in the text, then call again.'));
        exit(true);
    end;

    /// <summary>Supplies the effect chapter for this message type.</summary>
    /// <param name="Effect">Out: effect, changes, idempotency and preconditions.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The order is imported into table 30118 Shpfy Order Header and not yet processed.');
        Preconditions.Add('The shop of the order is enabled.');
        Preconditions.Add('The customer and the items of the order can be mapped, and they are not blocked.');
        Preconditions.Add('When the shop''s Return and Refund Process is Auto Create Credit Memo, there is no unprocessed refund in table 30142 Shpfy Refund Header.');
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Runs report 30103 Shpfy Create Sales Orders for this one order (codeunit 30167 Shpfy Process Orders, codeunit 30166 Shpfy Process Order): maps customer and items, inserts a sales order (or a sales invoice for a fulfilled order when the shop creates invoices) with its lines, releases it when the shop auto-releases sales orders, and marks the order Processed. When the shop has Order Attributes To Shopify, the process also writes the BC document number to the Shopify order as an attribute (a call to Shopify). The standard report also runs a refund phase that, when the shop''s Return and Refund Process is Auto Create Credit Memo, creates credit memos for every unprocessed refund of any order and shop; this message refuses such a request before anything is changed while unprocessed refunds exist, so the refund phase never runs and never changes refunds or creates credit memos. On a refusal of the order the order gets Has Error and Error Message and the partly created document is removed. The Shopify code commits (Commit()) before and after the creation, so the result is kept even if a later step of the message fails.');
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
        Related.Add(ContractMgt.RelatedEntry('Sales.Document.Post', 'You want to post the created sales document.'));
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', 'You need to find the order, e.g. table 30118 Shpfy Order Header.'));
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
        Examples.Add(ContractMgt.Example('Create the sales order of an imported Shopify order',
            '{"type":"Shopify.Order.CreateSalesDocument","data":{"shopifyOrderId":5123456789}}',
            '{"status":"Success","shopifyOrderId":5123456789,"documentType":"Order","documentNo":"101005","documentStatus":"Released"}'));
        exit(true);
    end;

    /// <summary>Summarizes the operation.</summary>
    /// <param name="Overview">Out: the overview.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Creates the Business Central sales order or invoice of one imported Shopify order through the standard report 30103 Shpfy Create Sales Orders (codeunits 30167 Shpfy Process Orders and 30166 Shpfy Process Order), so Business Central''s own mapping, validation and checks run.';
        exit(true);
    end;

    /// <summary>Explains the rules and limits of the operation.</summary>
    /// <param name="Notes">Out: the notes.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Not idempotent: a second call on the same order answers that it is already processed and creates nothing. The Shopify code commits before and after the creation. A refusal from the Shopify process is returned as a refusal; the order keeps the error text on its Has Error and Error Message fields and the partly created document is removed. Whether an order or an invoice is created, whether it is released and whether the document number is written back to Shopify (Order Attributes To Shopify) follows the shop setup. The message changes only the requested order: when the shop''s Return and Refund Process is Auto Create Credit Memo and any unprocessed refund exists, the request is refused before anything is changed, because the standard process would also create credit memos for those refunds. The response values documentType (Order, Invoice) and documentStatus (Open, Released, Pending Approval, Pending Prepayment) are the same in every language. Permissions: SHOPIFY Full ori, plus the Microsoft Shopify permissions for orders and sales documents.';
        exit(true);
    end;

    /// <summary>Classifies the message direction for Foundation.</summary>
    /// <returns>The direction of the operation.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Validates the request and creates the sales document through the standard Shopify report.</summary>
    /// <param name="Argument">The licensed request; receives the response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        OrderHeader: Record "Shpfy Order Header";
        SalesHeader: Record "Sales Header";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        OrderIdText: Text;
        OrderId: BigInteger;
        NoPermissionErr: Label 'You do not have the permissions to create sales documents from Shopify orders.', Comment = 'is-IS=Þú hefur ekki heimildir til að búa til sölufylgiskjöl úr Shopify pöntunum.';
        PermissionExpectedLbl: Label 'a user with the permission set SHOPIFY Full ori and the Shopify Connector permissions', Comment = 'is-IS=notandi með heimildasettið SHOPIFY Full ori og heimildir Shopify Connector';
        AskAdminLbl: Label 'Ask an administrator to assign the permission set SHOPIFY Full ori.', Comment = 'is-IS=Biddu kerfisstjóra um að úthluta heimildasettinu SHOPIFY Full ori.';
        MissingErr: Label 'Parameter "shopifyOrderId" is required.', Comment = 'is-IS=Færibreytan "shopifyOrderId" er nauðsynleg.';
        MissingNextLbl: Label 'Send data.shopifyOrderId with the Shopify Order Id.', Comment = 'is-IS=Sendu data.shopifyOrderId með auðkenni Shopify pöntunarinnar.';
        NumberExpectedLbl: Label 'a whole number greater than 0', Comment = 'is-IS=heiltala stærri en 0';
        InvalidErr: Label 'Parameter "shopifyOrderId" must be a whole number greater than 0.', Comment = 'is-IS=Færibreytan "shopifyOrderId" verður að vera heiltala stærri en 0.';
        InvalidNextLbl: Label 'Send the Shopify Order Id as a number.', Comment = 'is-IS=Sendu auðkenni Shopify pöntunarinnar sem tölu.';
        NotFoundErr: Label 'Shopify order %1 was not found.', Comment = '%1 = Shopify Order Id||is-IS=Shopify pöntun %1 fannst ekki.';
        ImportedExpectedLbl: Label 'the Id of an imported Shopify order', Comment = 'is-IS=auðkenni innfluttrar Shopify pöntunar';
        ImportFirstLbl: Label 'Import the order from Shopify first, or read table 30118 with Data.Records.Get.', Comment = 'is-IS=Fluttu pöntunina fyrst inn frá Shopify eða lestu töflu 30118 með Data.Records.Get.';
        ProcessedErr: Label 'Shopify order %1 is already processed.', Comment = '%1 = Shopify Order Id||is-IS=Shopify pöntun %1 hefur þegar verið unnin.';
        UnprocessedExpectedLbl: Label 'an order that is not processed', Comment = 'is-IS=pöntun sem hefur ekki verið unnin';
        NothingToDoLbl: Label 'Nothing to do.', Comment = 'is-IS=Ekkert að gera.';
        CreatedExpectedLbl: Label 'an order that Business Central can create a sales document for', Comment = 'is-IS=pöntun sem Business Central getur búið til sölufylgiskjal fyrir';
        FixCauseLbl: Label 'Fix the cause named in the text, then call again.', Comment = 'is-IS=Lagaðu orsökina sem textinn nefnir og kallaðu aftur.';
        RefusedErr: Label 'Can not create a sales document for the Shopify order %1. %2', Comment = '%1 = Shopify Order Id, %2 = detailed text||is-IS=Ekki er hægt að búa til sölufylgiskjal fyrir Shopify pöntunina %1. %2';
        RefundsPendingErr: Label 'Shop %1 creates credit memos for refunds automatically and there are unprocessed refunds.', Comment = '%1 = Shop Code||is-IS=Verslunin %1 býr sjálfkrafa til kreditreikninga fyrir endurgreiðslur og það eru óunnar endurgreiðslur.';
        NoPendingRefundsExpectedLbl: Label 'no unprocessed refunds while the shop creates credit memos automatically', Comment = 'is-IS=engar óunnar endurgreiðslur meðan verslunin býr sjálfkrafa til kreditreikninga';
        ProcessRefundsFirstLbl: Label 'Process the refunds first, or create the documents with the standard Create Sales Orders action.', Comment = 'is-IS=Vinndu endurgreiðslurnar fyrst eða búðu til fylgiskjölin með stöðluðu aðgerðinni Create Sales Orders.';
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if not IsEnabled() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, NoPermissionErr, 'shopifyOrderId', '', PermissionExpectedLbl, AskAdminLbl);
            exit;
        end;
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('shopifyOrderId', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, 'shopifyOrderId', '', NumberExpectedLbl, MissingNextLbl);
            exit;
        end;
        OrderIdText := Argument.TokenAsText(Token);
        if not Evaluate(OrderId, OrderIdText, 9) or (OrderId < 1) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidErr, 'shopifyOrderId', OrderIdText, NumberExpectedLbl, InvalidNextLbl);
            exit;
        end;
        if not OrderHeader.Get(OrderId) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, OrderId), 'shopifyOrderId', Format(OrderId, 0, 9), ImportedExpectedLbl, ImportFirstLbl);
            exit;
        end;
        if OrderHeader.Processed then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(ProcessedErr, OrderId), 'shopifyOrderId', Format(OrderId, 0, 9), UnprocessedExpectedLbl, NothingToDoLbl);
            exit;
        end;
        // Report 30103 ends with a refund phase that is not limited to this order or shop and runs after the order commit.
        if RefundPhaseWouldRun(OrderHeader."Shop Code") then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(RefundsPendingErr, OrderHeader."Shop Code"), 'shopifyOrderId', Format(OrderId, 0, 9), NoPendingRefundsExpectedLbl, ProcessRefundsFirstLbl);
            exit;
        end;

        // The standard report maps, checks, creates the document and commits; a refusal is stored on the order.
        RunCreateSalesOrders(OrderHeader);

        OrderHeader.Get(OrderId);
        if not FindCreatedDocument(OrderHeader, SalesHeader) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, StrSubstNo(RefusedErr, OrderId, OrderHeader."Error Message"), 'shopifyOrderId', Format(OrderId, 0, 9), CreatedExpectedLbl, FixCauseLbl);
            exit;
        end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('shopifyOrderId', OrderId);
        ResponseJson.Add('documentType', DocumentTypeName(SalesHeader."Document Type"));
        ResponseJson.Add('documentNo', SalesHeader."No.");
        ResponseJson.Add('documentStatus', StatusName(SalesHeader.Status));
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure RunCreateSalesOrders(OrderHeader: Record "Shpfy Order Header")
    var
        Shop: Record "Shpfy Shop";
        OrderFilter: Record "Shpfy Order Header";
        CreateSalesOrders: Report "Shpfy Create Sales Orders";
    begin
        // Report 30103 runs codeunit 30167, which runs codeunit 30166 for the order in its own error handling.
        Shop.SetRange(Code, OrderHeader."Shop Code");
        OrderFilter.SetRange("Shopify Order Id", OrderHeader."Shopify Order Id");
        CreateSalesOrders.SetTableView(Shop);
        CreateSalesOrders.SetTableView(OrderFilter);
        CreateSalesOrders.UseRequestPage(false);
        CreateSalesOrders.RunModal();
    end;

    local procedure RefundPhaseWouldRun(ShopCode: Code[20]): Boolean
    var
        Shop: Record "Shpfy Shop";
        RefundHeader: Record "Shpfy Refund Header";
    begin
        // Mirrors the condition and the filter of the refund phase of codeunit 30167 Shpfy Process Orders.
        Shop.SetLoadFields("Return and Refund Process");
        if not Shop.Get(ShopCode) then
            exit(false);
        if Shop."Return and Refund Process" <> "Shpfy ReturnRefund ProcessType"::"Auto Create Credit Memo" then
            exit(false);
        RefundHeader.SetRange("Is Processed", false);
        exit(not RefundHeader.IsEmpty());
    end;

    local procedure DocumentTypeName(DocumentType: Enum "Sales Document Type"): Text
    begin
        exit(DocumentType.Names().Get(DocumentType.Ordinals().IndexOf(DocumentType.AsInteger())));
    end;

    local procedure StatusName(Status: Enum "Sales Document Status"): Text
    begin
        exit(Status.Names().Get(Status.Ordinals().IndexOf(Status.AsInteger())));
    end;

    local procedure FindCreatedDocument(OrderHeader: Record "Shpfy Order Header"; var SalesHeader: Record "Sales Header"): Boolean
    begin
        if not OrderHeader.Processed or OrderHeader."Has Error" then
            exit(false);
        if OrderHeader."Sales Order No." <> '' then
            exit(SalesHeader.Get(SalesHeader."Document Type"::Order, OrderHeader."Sales Order No."));
        if OrderHeader."Sales Invoice No." <> '' then
            exit(SalesHeader.Get(SalesHeader."Document Type"::Invoice, OrderHeader."Sales Invoice No."));
        exit(false);
    end;
}
