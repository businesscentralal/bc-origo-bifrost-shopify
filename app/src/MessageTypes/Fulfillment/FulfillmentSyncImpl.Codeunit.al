namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.History;
using Origo.Bifrost;

/// <summary>
/// Implementation of <c>Shopify.Fulfillment.Sync</c>. Sends one posted sales shipment of a Shopify order, with its tracking
/// information, to Shopify as a fulfillment by running the connector report Sync Shipments To Shopify (30109) for that shipment.
/// </summary>
codeunit 70013430 "Fulfillment Sync Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Reports whether the caller holds the table permissions this message type needs.</summary>
    /// <returns>True when the permissions are held.</returns>
    procedure IsEnabled(): Boolean
    var
        SalesShipmentHeader: Record "Sales Shipment Header";
        ShopifyOrderHeader: Record "Shpfy Order Header";
        Shop: Record "Shpfy Shop";
    begin
        exit(SalesShipmentHeader.WritePermission() and ShopifyOrderHeader.ReadPermission() and Shop.ReadPermission());
    end;

    /// <summary>Identifies the table used by the message filter contract.</summary>
    /// <returns>The table ID.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Sales Shipment Header");
    end;

    /// <summary>Describes this message type for callers selecting an operation.</summary>
    /// <returns>The description in the current language.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Sends a posted sales shipment of a Shopify order to Shopify as a fulfillment with its tracking information.', Comment = 'is-IS=Sendir bókaða vöruafhendingu Shopify pöntunar til Shopify sem afgreiðslu ásamt rakningarupplýsingum.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search terms users say for this type, English with the Icelandic translation.</summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'shopify fulfillment, sync shipment, send tracking number, fulfill shopify order, export shipment to shopify', Comment = 'is-IS=shopify afgreiðsla, senda vöruafhendingu, senda rakningarnúmer, afgreiða shopify pöntun, flytja vöruafhendingu út til shopify';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Use for a posted sales shipment created from an imported Shopify order that has not been sent to Shopify yet. It does not import orders and does not post shipments.', Comment = 'is-IS=Notað fyrir bókaða vöruafhendingu úr innfluttri Shopify pöntun sem hefur ekki enn verið send til Shopify. Flytur ekki inn pantanir og bókar ekki vöruafhendingar.';
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
        Target.Add(ContractMgt.TargetEntry('Sales Shipment Header', 'data.shipmentNo', 'The No. of a posted sales shipment created from a Shopify order (table 110).'));
        exit(true);
    end;

    /// <summary>Declares accepted request parameters.</summary>
    /// <param name="Parameters">Receives the parameter declarations.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('shipmentNo', 'string', true, 'The No. of the posted sales shipment, e.g. from Data.Records.Get on table 110.'));
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
        Fields.Add(ContractMgt.ResponseField('shipmentNo', 'string', 'The No. of the posted sales shipment.'));
        Fields.Add(ContractMgt.ResponseField('shopifyOrderId', 'integer', 'The Shopify order Id of the shipment.'));
        Fields.Add(ContractMgt.ResponseField('fulfillmentId', 'integer', 'The Shopify fulfillment Id stored on the shipment.'));
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
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'Parameter "shipmentNo" is required.', 'The request has no shipmentNo. Nothing was changed.', 'Send data.shipmentNo with the posted shipment No.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'Parameter "shipmentNo" must be text of at most 20 characters.', 'The value is empty or too long. Nothing was changed.', 'Send the posted sales shipment No.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'Posted sales shipment {no} was not found.', 'No posted sales shipment has this No. Nothing was changed.', 'Read table 110 with Data.Records.Get.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Shipment {no} does not belong to a Shopify order, was already sent, or has no item lines to send.', 'The shipment cannot be fulfilled in Shopify. Nothing was changed.', 'Use a shipment of an imported Shopify order that has item lines and no fulfillment yet.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Can not send shipment {no} to Shopify.', 'Shopify or the connector refused or did not answer, or Shopify created no fulfillment. The shipment keeps its previous state and nothing is stored.', 'Fix the cause named in the text (shop connection, fulfillment order), then call again.'));
        exit(true);
    end;

    /// <summary>Supplies the effect chapter for this message type.</summary>
    /// <param name="Effect">Out: effect, changes, idempotency and preconditions.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The shipment was created from an imported Shopify order (Shopify Order Id is set).');
        Preconditions.Add('The shipment has not been sent to Shopify (Shopify Fulfillment Id is 0) and has at least one item line with quantity above 0.');
        Preconditions.Add('The Shopify order is imported in Business Central and its shop connection works.');
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Runs the connector report Sync Shipments To Shopify (30109) for the one shipment: calls the Shopify GraphQL API to create a fulfillment with the tracking information, imports the fulfillment into Business Central and stores its Id in Shopify Fulfillment Id on the shipment. This is an outbound Shopify write that cannot be rolled back by Business Central; the connector may commit while it runs.');
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
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', 'You need to find the shipment, e.g. table 110 Sales Shipment Header.'));
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
        Examples.Add(ContractMgt.Example('Send a shipment to Shopify',
            '{"type":"Shopify.Fulfillment.Sync","data":{"shipmentNo":"102001"}}',
            '{"status":"Success","shipmentNo":"102001","shopifyOrderId":930000001,"fulfillmentId":1234567890}'));
        exit(true);
    end;

    /// <summary>Summarizes the operation.</summary>
    /// <param name="Overview">Out: the overview.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Sends one posted sales shipment of a Shopify order, with its tracking information, to Shopify as a fulfillment by running the connector report Sync Shipments To Shopify (30109) for that shipment, so the connector''s own checks and export code run.';
        exit(true);
    end;

    /// <summary>Explains the rules and limits of the operation.</summary>
    /// <param name="Notes">Out: the notes.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Not idempotent: a shipment that has a fulfillment is refused on the second call. The call writes to Shopify, which Business Central cannot roll back. A failure of the Shopify call or a skipped shipment is returned as a refusal and the markers the connector wrote on the shipment are rolled back. Permissions: SHOPIFY Full ori, plus the Microsoft Shopify permissions for shipments and fulfillments.';
        exit(true);
    end;

    /// <summary>Classifies the message direction for Foundation.</summary>
    /// <returns>The direction of the operation.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    /// <summary>Validates the request and sends the shipment to Shopify through the connector report.</summary>
    /// <param name="Argument">The licensed request; receives the response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        SalesShipmentHeader: Record "Sales Shipment Header";
        SalesShipmentLine: Record "Sales Shipment Line";
        ShopifyOrderHeader: Record "Shpfy Order Header";
        SyncRun: Codeunit "Fulfillment Sync Run ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        ShipmentNoText: Text;
        NoPermissionErr: Label 'You do not have the permissions to send shipments to Shopify.', Comment = 'is-IS=Þú hefur ekki heimildir til að senda vöruafhendingar til Shopify.';
        PermissionExpectedLbl: Label 'a user with the permission set SHOPIFY Full ori and the Shopify Connector permissions', Comment = 'is-IS=notandi með heimildasettið SHOPIFY Full ori og heimildir Shopify Connector';
        AskAdminLbl: Label 'Ask an administrator to assign the permission set SHOPIFY Full ori.', Comment = 'is-IS=Biddu kerfisstjóra um að úthluta heimildasettinu SHOPIFY Full ori.';
        MissingErr: Label 'Parameter "shipmentNo" is required.', Comment = 'is-IS=Færibreytan "shipmentNo" er nauðsynleg.';
        MissingNextLbl: Label 'Send data.shipmentNo with the posted shipment No.', Comment = 'is-IS=Sendu data.shipmentNo með númeri bókuðu vöruafhendingarinnar.';
        TextExpectedLbl: Label 'a posted sales shipment No. of at most 20 characters', Comment = 'is-IS=númer bókaðrar vöruafhendingar, mest 20 stafir';
        InvalidErr: Label 'Parameter "shipmentNo" must be text of at most 20 characters.', Comment = 'is-IS=Færibreytan "shipmentNo" verður að vera texti, mest 20 stafir.';
        InvalidNextLbl: Label 'Send the posted sales shipment No.', Comment = 'is-IS=Sendu númer bókuðu vöruafhendingarinnar.';
        NotFoundErr: Label 'Posted sales shipment %1 was not found.', Comment = '%1 = Shipment No.||is-IS=Bókuð vöruafhending %1 fannst ekki.';
        ExistingShipmentLbl: Label 'the No. of a posted sales shipment', Comment = 'is-IS=númer bókaðrar vöruafhendingar';
        FindShipmentLbl: Label 'Read table 110 with Data.Records.Get.', Comment = 'is-IS=Lestu töflu 110 með Data.Records.Get.';
        NotShopifyErr: Label 'Shipment %1 does not belong to a Shopify order.', Comment = '%1 = Shipment No.||is-IS=Vöruafhending %1 tilheyrir ekki Shopify pöntun.';
        ShopifyShipmentLbl: Label 'a shipment of an imported Shopify order', Comment = 'is-IS=vöruafhending innfluttrar Shopify pöntunar';
        UseShopifyShipmentLbl: Label 'Use a shipment of an imported Shopify order that has item lines and no fulfillment yet.', Comment = 'is-IS=Notaðu vöruafhendingu innfluttrar Shopify pöntunar sem er með vörulínur og enga afgreiðslu enn.';
        SentErr: Label 'Shipment %1 was already sent to Shopify or skipped (Shopify Fulfillment Id %2).', Comment = '%1 = Shipment No., %2 = Fulfillment Id||is-IS=Vöruafhending %1 hefur þegar verið send til Shopify eða sleppt (Shopify Fulfillment Id %2).';
        UnsentLbl: Label 'a shipment that is not sent to Shopify yet', Comment = 'is-IS=vöruafhending sem hefur ekki enn verið send til Shopify';
        NoLinesErr: Label 'Shipment %1 has no item lines with a quantity above 0.', Comment = '%1 = Shipment No.||is-IS=Vöruafhending %1 er ekki með vörulínur með magn yfir 0.';
        LinesLbl: Label 'a shipment with item lines', Comment = 'is-IS=vöruafhending með vörulínum';
        NoOrderErr: Label 'The Shopify order %1 of shipment %2 is not imported.', Comment = '%1 = Shopify Order Id, %2 = Shipment No.||is-IS=Shopify pöntun %1 vöruafhendingar %2 er ekki innflutt.';
        ImportedOrderLbl: Label 'a shipment whose Shopify order is imported', Comment = 'is-IS=vöruafhending þar sem Shopify pöntunin er innflutt';
        ImportOrderLbl: Label 'Import the Shopify order first.', Comment = 'is-IS=Fluttu Shopify pöntunina fyrst inn.';
        RefusedErr: Label 'Can not send shipment %1 to Shopify. %2', Comment = '%1 = Shipment No., %2 = detailed text||is-IS=Ekki er hægt að senda vöruafhendingu %1 til Shopify. %2';
        SentExpectedLbl: Label 'a shipment Shopify can fulfill', Comment = 'is-IS=vöruafhending sem Shopify getur afgreitt';
        FixCauseLbl: Label 'Fix the cause named in the text, then call again.', Comment = 'is-IS=Lagaðu orsökina sem textinn nefnir og kallaðu aftur.';
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if not IsEnabled() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, NoPermissionErr, 'shipmentNo', '', PermissionExpectedLbl, AskAdminLbl);
            exit;
        end;
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('shipmentNo', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, 'shipmentNo', '', TextExpectedLbl, MissingNextLbl);
            exit;
        end;
        ShipmentNoText := Argument.TokenAsText(Token);
        if (ShipmentNoText = '') or (StrLen(ShipmentNoText) > MaxStrLen(SalesShipmentHeader."No.")) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidErr, 'shipmentNo', ShipmentNoText, TextExpectedLbl, InvalidNextLbl);
            exit;
        end;
        if not SalesShipmentHeader.Get(CopyStr(ShipmentNoText, 1, MaxStrLen(SalesShipmentHeader."No."))) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, ShipmentNoText), 'shipmentNo', ShipmentNoText, ExistingShipmentLbl, FindShipmentLbl);
            exit;
        end;
        if SalesShipmentHeader."Shpfy Order Id" = 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NotShopifyErr, ShipmentNoText), 'shipmentNo', ShipmentNoText, ShopifyShipmentLbl, UseShopifyShipmentLbl);
            exit;
        end;
        if SalesShipmentHeader."Shpfy Fulfillment Id" <> 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(SentErr, ShipmentNoText, SalesShipmentHeader."Shpfy Fulfillment Id"), 'shipmentNo', ShipmentNoText, UnsentLbl, UseShopifyShipmentLbl);
            exit;
        end;
        SalesShipmentLine.SetRange("Document No.", SalesShipmentHeader."No.");
        SalesShipmentLine.SetRange(Type, SalesShipmentLine.Type::Item);
        SalesShipmentLine.SetFilter(Quantity, '>0');
        if SalesShipmentLine.IsEmpty() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoLinesErr, ShipmentNoText), 'shipmentNo', ShipmentNoText, LinesLbl, UseShopifyShipmentLbl);
            exit;
        end;
        if not ShopifyOrderHeader.Get(SalesShipmentHeader."Shpfy Order Id") then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoOrderErr, SalesShipmentHeader."Shpfy Order Id", ShipmentNoText), 'shipmentNo', ShipmentNoText, ImportedOrderLbl, ImportOrderLbl);
            exit;
        end;

        // The connector report loads the fulfillment orders, creates the fulfillment in Shopify and stores its Id on the shipment.
        SyncRun.SetShipmentNo(SalesShipmentHeader."No.");
        ClearLastError();
        if not SyncRun.Run() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, StrSubstNo(RefusedErr, ShipmentNoText, GetLastErrorText()), 'shipmentNo', ShipmentNoText, SentExpectedLbl, FixCauseLbl);
            exit;
        end;
        SalesShipmentHeader.Get(SalesShipmentHeader."No.");
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('shipmentNo', SalesShipmentHeader."No.");
        ResponseJson.Add('shopifyOrderId', SalesShipmentHeader."Shpfy Order Id");
        ResponseJson.Add('fulfillmentId', SalesShipmentHeader."Shpfy Fulfillment Id");
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
