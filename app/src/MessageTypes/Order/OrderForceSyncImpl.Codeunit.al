namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using Origo.Bifrost;

/// <summary>Re-imports one known Shopify order with guarded, atomic local changes.</summary>
codeunit 73731951 "Order ForceSync Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Reports whether the caller holds the table permissions this message type needs.</summary>
    /// <returns>True when the permissions are held.</returns>
    procedure IsEnabled(): Boolean
    var
        Header: Record "Shpfy Order Header";
        Line: Record "Shpfy Order Line";
        Shop: Record "Shpfy Shop";
    begin
        exit(Header.WritePermission() and Line.WritePermission() and Shop.ReadPermission());
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
        DescriptionLbl: Label 'Re-imports one Shopify order and overwrites its local header, lines and related data.', Comment = 'is-IS=Flytur eina Shopify pöntun inn aftur og yfirskrifar staðbundinn haus, línur og tengd gögn.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search terms users say for this type, English with the Icelandic translation.</summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'shopify order, force sync, re-import order, overwrite local order, refresh order', Comment = 'is-IS=shopify pöntun, þvinga samstillingu, endurinnflytja pöntun, yfirskrifa staðbundna pöntun, endurnýja pöntun';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Use for an existing local order with expectedCount = 1. Reads Shopify, overwrites local order data, and does not re-run mapping or change BC sales documents.', Comment = 'is-IS=Notað fyrir fyrirliggjandi staðbundna pöntun með expectedCount = 1. Les Shopify, yfirskrifar staðbundin pöntunargögn og endurkeyrir ekki vörpun eða breytir BC söluskjölum.';
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
        Target.Add(ContractMgt.TargetEntry('Shpfy Order Header', 'data.orderId', 'An existing imported order, table 30118.'));
        exit(true);
    end;

    /// <summary>Declares accepted request parameters.</summary>
    /// <param name="Parameters">Receives the parameter declarations.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('orderId', 'integer', true, 'Positive Shopify order ID that already exists locally.'));
        Parameters.Add(ContractMgt.Parameter('expectedCount', 'integer', true, 'Must be 1, confirming that local data for one order may be overwritten.'));
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
        Fields.Add(ContractMgt.ResponseField('orderId', 'integer', 'The Shopify order ID.'));
        Fields.Add(ContractMgt.ResponseField('shopCode', 'string', 'The shop of the imported order.'));
        Fields.Add(ContractMgt.ResponseField('processed', 'boolean', 'The order is already processed or linked to a BC sales document.'));
        Fields.Add(ContractMgt.ResponseField('hasOrderStateError', 'boolean', 'The connector reports an order conflict after the import.'));
        Fields.Add(ContractMgt.ResponseField('linesBefore', 'integer', 'Local order line count before the import.'));
        Fields.Add(ContractMgt.ResponseField('linesAfter', 'integer', 'Local order line count after the import.'));
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
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A required parameter is missing.', 'A required parameter is missing.', 'Send orderId and expectedCount = 1.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A parameter is not a JSON integer in range.', 'A parameter is not a JSON integer in range.', 'Use a positive orderId and integer expectedCount.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The local order or its shop was not found.', 'The local order or its shop was not found.', 'Use Shopify.Order.Import first and verify the shop.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The shop is disabled, expectedCount is not 1, or a shop setting permits an outgoing write.', 'The shop is disabled, expectedCount is not 1, or a shop setting permits an outgoing write.', 'Enable the shop; confirm expectedCount = 1; check Archive Processed Orders, Allow Outgoing Requests and Fulfillment Service Activated.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller lacks write permission.', 'The caller lacks write permission.', 'Ask an administrator for SHOPIFY Full ori and Microsoft Shopify permissions.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'The connector failed; all local changes in the run, including Shopify logs, were rolled back.', 'The connector failed; all local changes in the run, including Shopify logs, were rolled back.', 'Correct the cause in the connector error text and retry.'));
        exit(true);
    end;

    /// <summary>Supplies the effect chapter for this message type.</summary>
    /// <param name="Effect">Out: effect, changes, idempotency and preconditions.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('Existing local order, enabled shop and expectedCount = 1.');
        Preconditions.Add('Archive Processed Orders must be off when Sales Order No. or Sales Invoice No. is set.');
        Preconditions.Add('Allow Outgoing Requests must be off or Fulfillment Service Activated must be on.');
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Reads Shopify using codeunit 30161 and overwrites local order header, lines and related rows. No Shopify mutations, mapping or BC sales document changes. Explicit connector commits are ignored inside the rollback boundary; a failure also rolls back Shopify log entries.');
        Effect.Add('idempotent', true);
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
        Related.Add(ContractMgt.RelatedEntry('Shopify.Order.Import', 'Import an order that does not yet exist locally.'));
        Related.Add(ContractMgt.RelatedEntry('Shopify.Order.CreateSalesDocument', 'Create a BC sales document separately.'));
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
        Examples.Add(ContractMgt.Example('Re-import one known order',
            '{"type":"Shopify.Order.ForceSync","data":{"orderId":12345,"expectedCount":1}}',
            '{"status":"Success","orderId":12345,"shopCode":"WEBSHOP","processed":false,"hasOrderStateError":false,"linesBefore":1,"linesAfter":2}'));
        exit(true);
    end;

    /// <summary>Summarizes the operation.</summary>
    /// <param name="Overview">Out: the overview.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Re-imports one existing Shopify order through Shpfy Import Order (30161), even when its updated-at has not changed. expectedCount = 1 confirms overwriting local order data. Shopify is read only.';
        exit(true);
    end;

    /// <summary>Explains the rules and limits of the operation.</summary>
    /// <param name="Notes">Out: the notes.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Idempotent for unchanged Shopify data. The connector refreshes order number, dates, totals, currencies, payment/fulfillment/return statuses, customer and company IDs, billing/shipping names and addresses, contact data, tags, tax, attributes, risks, fulfillments, refunds and returns; order lines refresh product/variant IDs, descriptions, quantities, prices, discounts and tax data. Mapping is not re-run. A changed processed order can set Has Order State Error; existing BC sales documents remain untouched. The request refuses Archive Processed Orders with a linked Sales Order No. or Sales Invoice No., and Allow Outgoing Requests with Fulfillment Service Activated off. Shop settings are never changed to bypass these guards. Only a temporary Orders to Import row is used. A pre-run commit separates prior request work from the connector transaction. Explicit connector commits are ignored; failure rolls back the header, lines, related rows and Shopify log entries written during this run. The response retains the connector error text. Permissions: SHOPIFY Full ori and Microsoft Shopify permissions. The internal connector is invoked by object ID and must be rechecked when its version changes.';
        exit(true);
    end;

    /// <summary>Classifies the message direction for Foundation.</summary>
    /// <returns>The direction of the operation.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;
    /// <summary>Validates confirmation and shop settings before an atomic re-import.</summary>
    /// <param name="Argument">Licensed request and response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Header: Record "Shpfy Order Header";
        Line: Record "Shpfy Order Line";
        Shop: Record "Shpfy Shop";
        Runner: Codeunit "Order ForceSync Run ori";
        Request: JsonObject;
        Response: JsonObject;
        OrderId: BigInteger;
        ExpectedCount: BigInteger;
        BeforeCount: Integer;
        Processed: Boolean;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if not IsEnabled() then begin
            Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, PermissionErr, '', PermissionNextLbl);
            exit;
        end;
        Request := Argument.GetRequestJson();
        if not ReadInteger(Argument, Request, 'orderId', OrderId) then
            exit;
        if OrderId <= 0 then begin
            Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, InvalidErr, 'orderId', InputNextLbl);
            exit;
        end;
        if not ReadInteger(Argument, Request, 'expectedCount', ExpectedCount) then
            exit;
        if ExpectedCount <> 1 then begin
            Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, CountErr, 'expectedCount', InputNextLbl);
            exit;
        end;
        Header.SetLoadFields("Shop Code", Processed, "Sales Order No.", "Sales Invoice No.", "Has Order State Error");
        if not Header.Get(OrderId) then begin
            Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, OrderMissingErr, 'orderId', ImportNextLbl);
            exit;
        end;
        Shop.SetLoadFields(Enabled, "Archive Processed Orders", "Allow Outgoing Requests", "Fulfillment Service Activated");
        if not Shop.Get(Header."Shop Code") then begin
            Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, ShopMissingErr, 'orderId', ShopNextLbl);
            exit;
        end;
        if not Shop.Enabled then begin
            Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, DisabledErr, 'orderId', ShopNextLbl);
            exit;
        end;
        if Shop."Archive Processed Orders" and ((Header."Sales Order No." <> '') or (Header."Sales Invoice No." <> '')) then begin
            Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, ArchiveErr, 'orderId', ArchiveNextLbl);
            exit;
        end;
        if Shop."Allow Outgoing Requests" and not Shop."Fulfillment Service Activated" then begin
            Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, ServiceErr, 'orderId', ServiceNextLbl);
            exit;
        end;
        Processed := IsProcessed(Header);
        Line.SetRange("Shopify Order Id", OrderId);
        BeforeCount := Line.Count();
        Runner.SetOrder(Shop.Code, OrderId);
        Commit();
        ClearLastError();
        if not Runner.Run() then begin
            Refuse(Argument, "Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), 'orderId', ConnectorNextLbl);
            exit;
        end;
        Header.Get(OrderId);
        Response.Add('status', 'Success');
        Response.Add('orderId', OrderId);
        Response.Add('shopCode', Shop.Code);
        Response.Add('processed', Processed);
        Response.Add('hasOrderStateError', Header."Has Order State Error");
        Response.Add('linesBefore', BeforeCount);
        Response.Add('linesAfter', Line.Count());
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure IsProcessed(Header: Record "Shpfy Order Header"): Boolean
    var
        Link: Record "Shpfy Doc. Link To Doc.";
    begin
        if Header.Processed or (Header."Sales Order No." <> '') or (Header."Sales Invoice No." <> '') then
            exit(true);
        Link.SetRange("Shopify Document Type", Link."Shopify Document Type"::"Shopify Shop Order");
        Link.SetRange("Shopify Document Id", Header."Shopify Order Id");
        exit(not Link.IsEmpty());
    end;

    local procedure ReadInteger(var Argument: Record "Message Argument ori"; Request: JsonObject; KeyName: Text; var Value: BigInteger): Boolean
    var
        Token: JsonToken;
        Serialized: Text;
        Digits: Text;
    begin
        if not Request.Get(KeyName, Token) then begin
            Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingErr, KeyName), KeyName, InputNextLbl);
            exit(false);
        end;
        Token.WriteTo(Serialized);
        Digits := Serialized;
        if CopyStr(Digits, 1, 1) = '-' then
            Digits := CopyStr(Digits, 2);
        if (Digits = '') or (DelChr(Digits, '=', '0123456789') <> '') or not Evaluate(Value, Serialized, 9) then begin
            Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, InvalidErr, KeyName, InputNextLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure Refuse(var Argument: Record "Message Argument ori"; ErrorCode: Enum "Bifrost Error Code ori"; Message: Text; KeyName: Text; NextStep: Text)
    begin
        Argument.RespondWithError(ErrorCode, Message, KeyName, '', ExpectedLbl, NextStep);
    end;

    var
        PermissionErr: Label 'You do not have permission to re-import Shopify orders.', Comment = 'is-IS=Þú hefur ekki heimild til að flytja Shopify pantanir inn aftur.';
        PermissionNextLbl: Label 'Ask an administrator for SHOPIFY Full ori and Microsoft Shopify permissions.', Comment = 'is-IS=Biddu kerfisstjóra um SHOPIFY Full ori og Microsoft Shopify heimildir.';
        MissingErr: Label 'Parameter "%1" is required.', Comment = '%1 = parameter name||is-IS=Færibreytan "%1" er nauðsynleg.';
        InvalidErr: Label 'Use JSON integers, with an orderId greater than zero.', Comment = 'is-IS=Notaðu JSON heiltölur og orderId stærra en núll.';
        InputNextLbl: Label 'Send the existing orderId and expectedCount = 1 to confirm overwriting local data.', Comment = 'is-IS=Sendu fyrirliggjandi orderId og expectedCount = 1 til að staðfesta yfirskrift staðbundinna gagna.';
        CountErr: Label 'expectedCount must be 1 to confirm overwriting this order.', Comment = 'is-IS=expectedCount verður að vera 1 til að staðfesta yfirskrift þessarar pöntunar.';
        OrderMissingErr: Label 'The Shopify order does not exist locally.', Comment = 'is-IS=Shopify pöntunin er ekki til staðbundið.';
        ImportNextLbl: Label 'Import the order with Shopify.Order.Import first.', Comment = 'is-IS=Flyttu pöntunina fyrst inn með Shopify.Order.Import.';
        ShopMissingErr: Label 'The Shopify shop was not found.', Comment = 'is-IS=Shopify verslunin fannst ekki.';
        DisabledErr: Label 'The Shopify shop is disabled.', Comment = 'is-IS=Shopify verslunin er óvirk.';
        ShopNextLbl: Label 'Verify and enable the shop on the Shopify Shop Card.', Comment = 'is-IS=Athugaðu og virkjaðu verslunina á Shopify Shop Card.';
        ArchiveErr: Label 'Archive Processed Orders can close this linked order in Shopify.', Comment = 'is-IS=Archive Processed Orders getur lokað þessari tengdu pöntun í Shopify.';
        ArchiveNextLbl: Label 'Review Archive Processed Orders on the Shopify Shop Card before re-importing a linked order.', Comment = 'is-IS=Farðu yfir Archive Processed Orders á Shopify Shop Card áður en tengd pöntun er flutt inn aftur.';
        ServiceErr: Label 'This shop can register a fulfillment service in Shopify during the import.', Comment = 'is-IS=Þessi verslun getur skráð afhendingarþjónustu í Shopify við innflutning.';
        ServiceNextLbl: Label 'Review Allow Outgoing Requests and Fulfillment Service Activated on the Shopify Shop Card.', Comment = 'is-IS=Farðu yfir Allow Outgoing Requests og Fulfillment Service Activated á Shopify Shop Card.';
        ConnectorNextLbl: Label 'Correct the connector error and retry. Local changes and Shopify log entries from this failed run were rolled back.', Comment = 'is-IS=Lagaðu villu tengilsins og reyndu aftur. Staðbundnar breytingar og Shopify annálsfærslur úr þessari misheppnuðu keyrslu voru afturkallaðar.';
        ExpectedLbl: Label 'An existing order, an enabled shop that cannot send these Shopify writes, expectedCount = 1 and write permission.', Comment = 'is-IS=Fyrirliggjandi pöntun, virk verslun sem getur ekki sent þessar Shopify breytingar, expectedCount = 1 og skrifheimild.';
}
