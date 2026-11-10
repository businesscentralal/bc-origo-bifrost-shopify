namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.Document;
using Origo.Bifrost;

/// <summary>
/// Implementation of <c>Shopify.Order.CreateSalesDocument</c>. Creates the Business Central sales order or sales
/// invoice of one imported Shopify order by running the Shopify report "Shpfy Create Sales Orders" (30103), which
/// runs the order process (codeunit 30167 Shpfy Process Orders) with all of Microsoft's own checks.
/// </summary>
codeunit 70013470 "Order CreateSalesDoc Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Reports whether the caller holds the table permissions this message type needs.</summary>
    /// <returns>True when the permissions are held.</returns>
    procedure IsEnabled(): Boolean
    var
        OrderHeader: Record "Shpfy Order Header";
        Shop: Record "Shpfy Shop";
        SalesHeader: Record "Sales Header";
    begin
        exit(OrderHeader.WritePermission() and Shop.ReadPermission() and SalesHeader.WritePermission());
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
        DescriptionLbl: Label 'Creates the Business Central sales order or invoice of an imported Shopify order.', Comment = 'is-IS=Býr til sölupöntun eða sölureikning í Business Central fyrir innflutta Shopify pöntun.';
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
        SelectionLbl: Label 'Use for an already imported Shopify order that has no Business Central document yet. It does not import orders from Shopify, does not release or post the document beyond the shop''s own setting, and does not create refunds.', Comment = 'is-IS=Notað fyrir innflutta Shopify pöntun sem hefur ekki Business Central skjal. Flytur ekki inn pantanir frá Shopify, losar ekki og bókar ekki skjalið umfram stillingu verslunarinnar og býr ekki til endurgreiðslur.';
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
        Target.Add(ContractMgt.TargetEntry('Shpfy Order Header', 'data.orderId', 'The Shopify Order Id of an imported order (table 30118).'));
        exit(true);
    end;

    /// <summary>Declares accepted request parameters.</summary>
    /// <param name="Parameters">Receives the parameter declarations.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('orderId', 'integer', true, 'The Shopify Order Id of an imported order, e.g. from Data.Records.Get on table 30118.'));
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
        Fields.Add(ContractMgt.ResponseField('orderId', 'integer', 'The Shopify Order Id.'));
        Fields.Add(ContractMgt.ResponseField('documentType', 'string', 'Order or Invoice, following the shop''s Create Invoices From Orders setting.'));
        Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The No. of the created sales document.'));
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
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'Parameter "orderId" is required.', 'The request has no orderId. Nothing was changed.', 'Send data.orderId with the Shopify Order Id.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'Parameter "orderId" must be a whole number greater than 0.', 'The value is not a positive integer. Nothing was changed.', 'Send the Shopify Order Id as a number.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'Shopify order {id} was not found.', 'No imported order has this Id. Nothing was changed.', 'Import the order first, or read table 30118 with Data.Records.Get.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Shopify order {id} already has a sales document.', 'The order is already processed. Nothing was changed.', 'Nothing to do.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Shop {code} is not enabled.', 'The shop of the order is disabled. Nothing was changed.', 'Enable the shop.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Can not create a sales document for the order {id}.', 'Business Central refused: a customer, item, location or setup is missing. The order keeps the error text and nothing is created.', 'Fix the cause named in the text, then call again.'));
        exit(true);
    end;

    /// <summary>Supplies the effect chapter for this message type.</summary>
    /// <param name="Effect">Out: effect, changes, idempotency and preconditions.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The order is imported and not yet processed (no linked sales document).');
        Preconditions.Add('The shop of the order is enabled.');
        Preconditions.Add('Customer mapping, item mapping and posting setup of the shop allow Business Central to create the document.');
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Runs the Shopify report Shpfy Create Sales Orders for the one order: inserts a sales order (or a sales invoice when the shop has Create Invoices From Orders) with its lines, may create a customer when the shop allows it, and releases the document when the shop has Auto Release Sales Orders. The Shopify code commits (Commit()) during the processing, so a result is kept even if a later step of the message fails.');
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
        Examples.Add(ContractMgt.Example('Create the sales order of an imported order',
            '{"type":"Shopify.Order.CreateSalesDocument","data":{"orderId":820982911946154508}}',
            '{"status":"Success","orderId":820982911946154508,"documentType":"Order","documentNo":"101001"}'));
        exit(true);
    end;

    /// <summary>Summarizes the operation.</summary>
    /// <param name="Overview">Out: the overview.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Creates the Business Central sales order or sales invoice of one imported Shopify order by running the Shopify report Shpfy Create Sales Orders (30103, which runs codeunit 30167 Shpfy Process Orders), so Business Central''s own validation and checks run.';
        exit(true);
    end;

    /// <summary>Explains the rules and limits of the operation.</summary>
    /// <param name="Notes">Out: the notes.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Not idempotent: a second call on the same order answers that it already has a sales document. The Shopify code commits during the processing. A refusal from the Shopify process is returned as a refusal and creates nothing; the order keeps the error text on its Has Error and Error Message fields. Permissions: SHOPIFY Full ori, plus the Microsoft Shopify permissions for orders and sales documents.';
        exit(true);
    end;

    /// <summary>Classifies the message direction for Foundation.</summary>
    /// <returns>The direction of the operation.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Validates the request and creates the sales document through the Shopify report.</summary>
    /// <param name="Argument">The licensed request; receives the response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        OrderHeader: Record "Shpfy Order Header";
        Shop: Record "Shpfy Shop";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        OrderIdText: Text;
        OrderId: BigInteger;
        NoPermissionErr: Label 'You do not have the permissions to create sales documents from Shopify orders.', Comment = 'is-IS=Þú hefur ekki heimildir til að búa til sölugögn úr Shopify pöntunum.';
        PermissionExpectedLbl: Label 'a user with the permission set SHOPIFY Full ori and the Shopify Connector permissions', Comment = 'is-IS=notandi með heimildasettið SHOPIFY Full ori og heimildir Shopify Connector';
        AskAdminLbl: Label 'Ask an administrator to assign the permission set SHOPIFY Full ori.', Comment = 'is-IS=Biddu kerfisstjóra um að úthluta heimildasettinu SHOPIFY Full ori.';
        MissingErr: Label 'Parameter "orderId" is required.', Comment = 'is-IS=Færibreytan "orderId" er nauðsynleg.';
        MissingNextLbl: Label 'Send data.orderId with the Shopify Order Id.', Comment = 'is-IS=Sendu data.orderId með auðkenni Shopify pöntunarinnar.';
        NumberExpectedLbl: Label 'a whole number greater than 0', Comment = 'is-IS=heiltala stærri en 0';
        InvalidErr: Label 'Parameter "orderId" must be a whole number greater than 0.', Comment = 'is-IS=Færibreytan "orderId" verður að vera heiltala stærri en 0.';
        InvalidNextLbl: Label 'Send the Shopify Order Id as a number.', Comment = 'is-IS=Sendu auðkenni Shopify pöntunarinnar sem tölu.';
        NotFoundErr: Label 'Shopify order %1 was not found.', Comment = '%1 = Order Id||is-IS=Shopify pöntun %1 fannst ekki.';
        ImportedExpectedLbl: Label 'the Id of an imported order', Comment = 'is-IS=auðkenni innfluttrar pöntunar';
        ImportFirstLbl: Label 'Import the order first, or read table 30118 with Data.Records.Get.', Comment = 'is-IS=Fluttu pöntunina fyrst inn eða lestu töflu 30118 með Data.Records.Get.';
        ProcessedErr: Label 'Shopify order %1 already has a sales document.', Comment = '%1 = Order Id||is-IS=Shopify pöntun %1 hefur þegar sölugagn.';
        UnprocessedExpectedLbl: Label 'an order that is not processed', Comment = 'is-IS=pöntun sem hefur ekki verið unnin';
        NothingToDoLbl: Label 'Nothing to do.', Comment = 'is-IS=Ekkert að gera.';
        ShopDisabledErr: Label 'Shop %1 is not enabled.', Comment = '%1 = Shop code||is-IS=Verslun %1 er ekki virk.';
        ShopEnabledExpectedLbl: Label 'an order of an enabled shop', Comment = 'is-IS=pöntun í virkri verslun';
        EnableShopLbl: Label 'Enable the shop.', Comment = 'is-IS=Virkjaðu verslunina.';
        CreatedExpectedLbl: Label 'an order that Business Central can create a sales document for', Comment = 'is-IS=pöntun sem Business Central getur búið til sölugagn fyrir';
        FixCauseLbl: Label 'Fix the cause named in the text, then call again.', Comment = 'is-IS=Lagaðu orsökina sem textinn nefnir og kallaðu aftur.';
        RefusedErr: Label 'Can not create a sales document for the order %1. %2', Comment = '%1 = Order Id, %2 = detailed text||is-IS=Ekki er hægt að búa til sölugagn fyrir pöntunina %1. %2';
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if not IsEnabled() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, NoPermissionErr, 'orderId', '', PermissionExpectedLbl, AskAdminLbl);
            exit;
        end;
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('orderId', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, 'orderId', '', NumberExpectedLbl, MissingNextLbl);
            exit;
        end;
        OrderIdText := Argument.TokenAsText(Token);
        if not Evaluate(OrderId, OrderIdText, 9) or (OrderId < 1) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidErr, 'orderId', OrderIdText, NumberExpectedLbl, InvalidNextLbl);
            exit;
        end;
        if not OrderHeader.Get(OrderId) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, OrderId), 'orderId', Format(OrderId, 0, 9), ImportedExpectedLbl, ImportFirstLbl);
            exit;
        end;
        if OrderHeader.Processed then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(ProcessedErr, OrderId), 'orderId', Format(OrderId, 0, 9), UnprocessedExpectedLbl, NothingToDoLbl);
            exit;
        end;
        Shop.Get(OrderHeader."Shop Code");
        if not Shop.Enabled then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(ShopDisabledErr, Shop.Code), 'orderId', Format(OrderId, 0, 9), ShopEnabledExpectedLbl, EnableShopLbl);
            exit;
        end;

        // The Shopify report runs the shop's own order process, catches its errors per order and commits.
        RunCreateSalesOrders(Shop.Code, OrderId);
        Clear(OrderHeader);
        OrderHeader.Get(OrderId);
        if not OrderHeader.Processed then begin
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, StrSubstNo(RefusedErr, OrderId, OrderHeader."Error Message"), 'orderId', Format(OrderId, 0, 9), CreatedExpectedLbl, FixCauseLbl);
            exit;
        end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('orderId', OrderId);
        if OrderHeader."Sales Invoice No." <> '' then begin
            ResponseJson.Add('documentType', 'Invoice');
            ResponseJson.Add('documentNo', OrderHeader."Sales Invoice No.");
        end else begin
            ResponseJson.Add('documentType', 'Order');
            ResponseJson.Add('documentNo', OrderHeader."Sales Order No.");
        end;
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure RunCreateSalesOrders(ShopCode: Code[20]; OrderId: BigInteger)
    var
        Shop: Record "Shpfy Shop";
        OrderHeader: Record "Shpfy Order Header";
        Parameters: Text;
    begin
        Shop.SetRange(Code, ShopCode);
        OrderHeader.SetRange("Shopify Order Id", OrderId);
        Parameters := '<?xml version="1.0" standalone="yes"?><ReportParameters name="Shpfy Create Sales Orders" id="30103"><DataItems>' +
            '<DataItem name="Shop">' + Shop.GetView(false) + '</DataItem>' +
            '<DataItem name="ShopifyOrder">' + OrderHeader.GetView(false) + '</DataItem>' +
            '</DataItems></ReportParameters>';
        Report.Execute(Report::"Shpfy Create Sales Orders", Parameters);
    end;
}
