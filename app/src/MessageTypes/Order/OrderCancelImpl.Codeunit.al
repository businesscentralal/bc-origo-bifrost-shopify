namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using Origo.Bifrost;

/// <summary>Cancels one imported order through the public Shopify Orders API, with explicit confirmation and options.</summary>
codeunit 73732042 "Order Cancel Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        ExecuteBifrostTask(Rec);
    end;

    /// <summary>Checks the Shopify permissions needed by the operation; execution also requires the Full role's codeunit grant.</summary>
    /// <returns>True when the caller can access the order and shop.</returns>
    procedure IsEnabled(): Boolean
    var
        OrderHeader: Record "Shpfy Order Header";
        Shop: Record "Shpfy Shop";
    begin
        exit(OrderHeader.WritePermission() and Shop.ReadPermission());
    end;

    /// <summary>Identifies the imported order table.</summary>
    /// <returns>Shopify Order Header table ID.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Shpfy Order Header");
    end;

    /// <summary>Supplies GetDescription for cancellation discovery.</summary>
    /// <returns>The localized discovery value.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Cancels one Shopify order irreversibly; may refund payment, restock inventory and email the customer.', Comment = 'is-IS=Afturkallar eina Shopify pöntun óafturkræft; getur endurgreitt greiðslu, endurheimt birgðir og sent viðskiptavini tölvupóst.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Supplies GetKeywords for cancellation discovery.</summary>
    /// <returns>The localized discovery value.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'shopify cancel order, cancel shopify purchase, refund cancelled order', Comment = 'is-IS=shopify afturkalla pöntun, afturkalla shopify kaup, endurgreiða afturkallaða pöntun';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Supplies GetSelectionDescription for cancellation discovery.</summary>
    /// <returns>The localized discovery value.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Use to cancel one imported order in Shopify. Choose refund, restock and notify explicitly; confirm expectedCount = 1.', Comment = 'is-IS=Notað til að afturkalla eina innflutta pöntun í Shopify. Veldu endurgreiðslu, birgðir og tilkynningu sérstaklega; staðfestu expectedCount = 1.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Supplies GetMessageDirection for cancellation discovery.</summary>
    /// <returns>The localized discovery value.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Supplies the envelope chapter.</summary>
    /// <param name="Envelope">Receives the chapter.</param>
    /// <returns>True when the chapter is provided.</returns>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Supplies the metering chapter.</summary>
    /// <param name="Metering">Receives the chapter.</param>
    /// <returns>True when the chapter is provided.</returns>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Supplies the workflow chapter.</summary>
    /// <param name="Workflow">Receives the chapter.</param>
    /// <returns>True when the chapter is provided.</returns>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Supplies the target chapter.</summary>
    /// <param name="Target">Receives the chapter.</param>
    /// <returns>True when the chapter is provided.</returns>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(ContractMgt.TargetEntry('Shpfy Order Header', 'data.orderId', 'One imported Shopify order (table 30118); the shop is derived from the order.'));
        exit(true);
    end;

    /// <summary>Supplies the parameters chapter.</summary>
    /// <param name="Parameters">Receives the chapter.</param>
    /// <returns>True when the chapter is provided.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('orderId', 'integer', true, 'The positive Shopify order ID of one imported order.'));
        Parameters.Add(ContractMgt.Parameter('reason', 'string', true, 'Customer, Fraud, Inventory, Other, Staff or Declined (English enum name).'));
        Parameters.Add(ContractMgt.Parameter('notifyCustomer', 'boolean', true, 'Whether Shopify should email the customer. Required; no default.'));
        Parameters.Add(ContractMgt.Parameter('refund', 'boolean', true, 'Whether Shopify should refund the payment. Required; no default.'));
        Parameters.Add(ContractMgt.Parameter('restock', 'boolean', true, 'Whether Shopify should restock inventory. Required; no default.'));
        Parameters.Add(ContractMgt.Parameter('expectedCount', 'integer', true, 'Must be 1 to confirm cancellation of exactly one order. Required; no default.'));
        exit(true);
    end;

    /// <summary>Supplies the response chapter.</summary>
    /// <param name="Response">Receives the chapter.</param>
    /// <returns>True when the chapter is provided.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success.'));
        Fields.Add(ContractMgt.ResponseField('orderId', 'integer', 'The Shopify order ID.'));
        Fields.Add(ContractMgt.ResponseField('shopCode', 'string', 'The shop code derived from the imported order.'));
        Fields.Add(ContractMgt.ResponseField('reason', 'string', 'The applied English enum name.'));
        Fields.Add(ContractMgt.ResponseField('notifyCustomer', 'boolean', 'The applied notification choice.'));
        Fields.Add(ContractMgt.ResponseField('refund', 'boolean', 'The applied refund choice.'));
        Fields.Add(ContractMgt.ResponseField('restock', 'boolean', 'The applied restock choice.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Supplies the errors chapter.</summary>
    /// <param name="Errors">Receives the chapter.</param>
    /// <returns>True when the chapter is provided.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A required parameter is missing.', 'No connector call is made.', 'Send all six required parameters.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A parameter has the wrong JSON type or value.', 'No connector call is made.', 'Use a positive integer orderId, a supported reason, JSON booleans and expectedCount = 1.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The imported order or its shop was not found.', 'No connector call is made.', 'Import the order and configure its shop first.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The shop is disabled or the imported order is already cancelled.', 'No connector call is made.', 'Check the imported order and enable the shop.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Permission to cancel Shopify orders is required.', 'No connector call is made.', 'Ask an administrator for SHOPIFY Full ori and Microsoft Shopify permissions.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Shopify refused the cancellation.', 'Local writes in the connector run are rolled back.', 'Review Shopify Log Entries (table 30115) and the current Shopify order before retrying.'));
        exit(true);
    end;

    /// <summary>Supplies the effect chapter.</summary>
    /// <param name="Effect">Receives the chapter.</param>
    /// <returns>True when the chapter is provided.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('An imported order that is not already cancelled and belongs to an enabled shop.');
        Preconditions.Add('All six parameters are explicit and expectedCount is 1.');
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Irreversibly cancels exactly one order in Shopify through Shpfy Orders.CancelOrder (30409). May refund payment, restock inventory and email the customer according to the explicit options. No Business Central order row, sales order or invoice is cancelled or deleted. Commit() before the connector run establishes the rollback boundary for local writes; remote Shopify effects cannot be rolled back.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'SHOPIFY Full ori');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    /// <summary>Supplies the related chapter.</summary>
    /// <param name="Related">Receives the chapter.</param>
    /// <returns>True when the chapter is provided.</returns>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', 'Find the imported order in table 30118.'));
        exit(true);
    end;

    /// <summary>Supplies the examples chapter.</summary>
    /// <param name="Examples">Receives the chapter.</param>
    /// <returns>True when the chapter is provided.</returns>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Cancel one order without refund, restock or email',
            '{"type":"Shopify.Order.Cancel","data":{"orderId":12345,"reason":"Customer","notifyCustomer":false,"refund":false,"restock":false,"expectedCount":1}}',
            '{"status":"Success","orderId":12345,"shopCode":"SHOP","reason":"Customer","notifyCustomer":false,"refund":false,"restock":false}'));
        exit(true);
    end;

    /// <summary>Supplies the overview chapter.</summary>
    /// <param name="Overview">Receives the chapter.</param>
    /// <returns>True when the chapter is provided.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Cancels one imported Shopify order irreversibly through the public Shpfy Orders.CancelOrder API (30409). Explicit options control refund, restock and customer email. Confirm exactly one order with expectedCount = 1.';
        exit(true);
    end;

    /// <summary>Supplies the notes chapter.</summary>
    /// <param name="Notes">Receives the chapter.</param>
    /// <returns>True when the chapter is provided.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Not idempotent. The imported Cancelled At value is checked before the API call, but can lag behind Shopify: verify current Shopify state before retrying an uncertain result. A linked Business Central sales order or invoice is not cancelled. Imported Business Central order rows are left unchanged. The public connector API returns only a Boolean, not a log-entry ID; on user errors review Shopify Log Entries (table 30115). The connector log may depend on the shop logging configuration. A local rollback cannot undo a Shopify cancellation, refund or email.';
        exit(true);
    end;

    /// <summary>Validates all choices before running the external operation within a local rollback boundary.</summary>
    /// <param name="Argument">Licensed request; receives success or a typed refusal.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        OrderHeader: Record "Shpfy Order Header";
        Shop: Record "Shpfy Shop";
        CancelRun: Codeunit "Order Cancel Run ori";
        Request: JsonObject;
        Response: JsonObject;
        OrderId: BigInteger;
        ExpectedCount: BigInteger;
        ReasonText: Text;
        Reason: Enum "Shpfy Cancel Reason";
        NotifyCustomer: Boolean;
        Refund: Boolean;
        Restock: Boolean;
        NoPermissionErr: Label 'You do not have permission to cancel Shopify orders.', Comment = 'is-IS=Þú hefur ekki heimild til að afturkalla Shopify pantanir.';
        PermissionNextLbl: Label 'Ask an administrator for SHOPIFY Full ori and Microsoft Shopify permissions.', Comment = 'is-IS=Biddu kerfisstjóra um SHOPIFY Full ori og Shopify heimildir Microsoft.';
        OrderNotFoundErr: Label 'Shopify order %1 was not found.', Comment = '%1 = order ID||is-IS=Shopify pöntun %1 fannst ekki.';
        OrderNextLbl: Label 'Import the order first and check its shop.', Comment = 'is-IS=Fluttu pöntunina fyrst inn og athugaðu verslun hennar.';
        ShopNotFoundErr: Label 'Shopify shop %1 was not found.', Comment = '%1 = shop code||is-IS=Shopify verslun %1 fannst ekki.';
        ShopDisabledErr: Label 'Shopify shop %1 is disabled.', Comment = '%1 = shop code||is-IS=Shopify verslun %1 er óvirk.';
        ShopNextLbl: Label 'Configure and enable the shop before cancelling the order.', Comment = 'is-IS=Settu upp og virkjaðu verslunina áður en þú afturkallar pöntunina.';
        CancelledErr: Label 'Shopify order %1 is already cancelled.', Comment = '%1 = order ID||is-IS=Shopify pöntun %1 hefur þegar verið afturkölluð.';
        CancelledNextLbl: Label 'Check the order in Shopify; do not repeat its cancellation.', Comment = 'is-IS=Athugaðu pöntunina í Shopify; ekki endurtaka afturköllun hennar.';
        RefusedErr: Label 'Cancellation of Shopify order %1 failed. %2', Comment = '%1 = order ID, %2 = connector error||is-IS=Afturköllun Shopify pöntunar %1 mistókst. %2';
        RefusedNextLbl: Label 'Review Shopify Log Entries (table 30115) and the current Shopify order before retrying.', Comment = 'is-IS=Skoðaðu Shopify Log Entries (töflu 30115) og núverandi stöðu pöntunarinnar í Shopify áður en þú reynir aftur.';
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if not IsEnabled() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, NoPermissionErr, '', '', '', PermissionNextLbl);
            exit;
        end;
        Request := Argument.GetRequestJson();
        if not ReadInteger(Request, 'orderId', Argument, OrderId) then
            exit;
        if OrderId < 1 then begin
            Invalid(Argument, 'orderId');
            exit;
        end;
        if not ReadReason(Request, Argument, ReasonText, Reason) then
            exit;
        if not ReadBoolean(Request, 'notifyCustomer', Argument, NotifyCustomer) then
            exit;
        if not ReadBoolean(Request, 'refund', Argument, Refund) then
            exit;
        if not ReadBoolean(Request, 'restock', Argument, Restock) then
            exit;
        if not ReadInteger(Request, 'expectedCount', Argument, ExpectedCount) then
            exit;
        if ExpectedCount <> 1 then begin
            Invalid(Argument, 'expectedCount');
            exit;
        end;
        OrderHeader.SetLoadFields("Shop Code", "Cancelled At");
        if not OrderHeader.Get(OrderId) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(OrderNotFoundErr, OrderId), 'orderId', Format(OrderId, 0, 9), '', OrderNextLbl);
            exit;
        end;
        if OrderHeader."Cancelled At" <> 0DT then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(CancelledErr, OrderId), 'orderId', Format(OrderId, 0, 9), '', CancelledNextLbl);
            exit;
        end;
        Shop.SetLoadFields(Enabled);
        if not Shop.Get(OrderHeader."Shop Code") then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(ShopNotFoundErr, OrderHeader."Shop Code"), 'orderId', Format(OrderId, 0, 9), '', ShopNextLbl);
            exit;
        end;
        if not Shop.Enabled then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(ShopDisabledErr, Shop.Code), 'orderId', Format(OrderId, 0, 9), '', ShopNextLbl);
            exit;
        end;
        CancelRun.SetParameters(OrderId, Shop.Code, NotifyCustomer, Reason, Refund, Restock);
        Commit();
        ClearLastError();
        if not CancelRun.Run() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, StrSubstNo(RefusedErr, OrderId, GetLastErrorText()), 'orderId', Format(OrderId, 0, 9), '', RefusedNextLbl);
            exit;
        end;
        Response.Add('status', 'Success');
        Response.Add('orderId', OrderId);
        Response.Add('shopCode', Shop.Code);
        Response.Add('reason', ReasonText);
        Response.Add('notifyCustomer', NotifyCustomer);
        Response.Add('refund', Refund);
        Response.Add('restock', Restock);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure ReadToken(Request: JsonObject; Name: Text; var Argument: Record "Message Argument ori"; var Token: JsonToken): Boolean
    var
        MissingErr: Label 'Parameter "%1" is required.', Comment = '%1 = parameter name||is-IS=Færibreytan "%1" er nauðsynleg.';
        NextLbl: Label 'Send all six parameters: orderId, reason, notifyCustomer, refund, restock and expectedCount.', Comment = 'is-IS=Sendu allar sex færibreyturnar: orderId, reason, notifyCustomer, refund, restock og expectedCount.';
    begin
        if not Request.Get(Name, Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingErr, Name), Name, '', '', NextLbl);
            exit(false);
        end;
        if not Token.IsValue() then begin
            Invalid(Argument, Name);
            exit(false);
        end;
        if Token.AsValue().IsNull() then begin
            Invalid(Argument, Name);
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadInteger(Request: JsonObject; Name: Text; var Argument: Record "Message Argument ori"; var Value: BigInteger): Boolean
    var
        Token: JsonToken;
        Serialized: Text;
    begin
        if not ReadToken(Request, Name, Argument, Token) then
            exit(false);
        Token.WriteTo(Serialized);
        if Evaluate(Value, Serialized, 9) then
            if Format(Value, 0, 9) = Serialized then
                exit(true);
        Invalid(Argument, Name);
        exit(false);
    end;

    local procedure ReadBoolean(Request: JsonObject; Name: Text; var Argument: Record "Message Argument ori"; var Value: Boolean): Boolean
    var
        Token: JsonToken;
        Serialized: Text;
    begin
        if not ReadToken(Request, Name, Argument, Token) then
            exit(false);
        Token.WriteTo(Serialized);
        if Serialized in ['true', 'false'] then begin
            Value := Serialized = 'true';
            exit(true);
        end;
        Invalid(Argument, Name);
        exit(false);
    end;

    local procedure ReadReason(Request: JsonObject; var Argument: Record "Message Argument ori"; var ReasonText: Text; var Reason: Enum "Shpfy Cancel Reason"): Boolean
    var
        Token: JsonToken;
        Serialized: Text;
        Position: Integer;
    begin
        if not ReadToken(Request, 'reason', Argument, Token) then
            exit(false);
        Token.WriteTo(Serialized);
        if CopyStr(Serialized, 1, 1) = '"' then begin
            ReasonText := Token.AsValue().AsText();
            // Compare invariant enum names, never localized captions or the connector's blank/Unknown fallbacks.
            Position := Reason.Names().IndexOf(ReasonText);
            if Position > 0 then begin
                Reason := "Shpfy Cancel Reason".FromInteger(Reason.Ordinals().Get(Position));
                if Reason in [Reason::Customer, Reason::Fraud, Reason::Inventory, Reason::Other, Reason::Staff, Reason::Declined] then
                    exit(true);
            end;
        end;
        Invalid(Argument, 'reason');
        exit(false);
    end;

    local procedure Invalid(var Argument: Record "Message Argument ori"; Name: Text)
    var
        InvalidErr: Label 'Parameter "%1" has an invalid format or value.', Comment = '%1 = parameter name||is-IS=Færibreytan "%1" er á röngu sniði eða hefur ógilt gildi.';
        NextLbl: Label 'Use a positive JSON integer orderId, reason Customer/Fraud/Inventory/Other/Staff/Declined, JSON booleans and expectedCount = 1.', Comment = 'is-IS=Notaðu jákvæða JSON heiltölu fyrir orderId, reason Customer/Fraud/Inventory/Other/Staff/Declined, JSON rökgildi og expectedCount = 1.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidErr, Name), Name, '', '', NextLbl);
    end;
}
