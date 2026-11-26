namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using Origo.Bifrost;

/// <summary>Marks one imported order as paid through the connector's public Orders API.</summary>
codeunit 73732090 "Order MarkPaid Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        ExecuteBifrostTask(Rec);
    end;

    /// <summary>Checks the permissions needed for this write.</summary>
    /// <returns>The requested value or whether the chapter is supplied.</returns>
    procedure IsEnabled(): Boolean
    var
        OrderHeader: Record "Shpfy Order Header";
        Shop: Record "Shpfy Shop";
        PaidMarker: Record "Order Paid Marker ori";
    begin
        exit(OrderHeader.ReadPermission() and Shop.ReadPermission() and PaidMarker.WritePermission());
    end;

    /// <summary>Supplies the message contract chapter.</summary>
    /// <returns>The requested value or whether the chapter is supplied.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Shpfy Order Header");
    end;

    /// <summary>Supplies the message contract chapter.</summary>
    /// <returns>The requested value or whether the chapter is supplied.</returns>
    procedure GetDescription(): Text[250]
    var
        TextLbl: Label 'Marks one imported Shopify order as paid in Shopify. This write is hard to undo.', Comment = 'is-IS=Merkir eina innflutta Shopify pöntun sem greidda í Shopify. Erfitt er að afturkalla þessi skrif.';
    begin
        exit(TextLbl);
    end;

    /// <summary>Supplies the message contract chapter.</summary>
    /// <returns>The requested value or whether the chapter is supplied.</returns>
    procedure GetKeywords(): Text
    var
        TextLbl: Label 'shopify order, mark as paid, payment confirmation, paid order, confirm payment', Comment = 'is-IS=shopify pöntun, merkja sem greitt, greiðslustaðfesting, greidd pöntun, staðfesta greiðslu';
    begin
        exit(TextLbl);
    end;

    /// <summary>Supplies the message contract chapter.</summary>
    /// <returns>The requested value or whether the chapter is supplied.</returns>
    procedure GetSelectionDescription(): Text
    var
        TextLbl: Label 'Use to mark an unpaid imported order as paid in Shopify with expectedCount = 1. Refresh the local order separately.', Comment = 'is-IS=Notað til að merkja ógreidda innflutta pöntun sem greidda í Shopify með expectedCount = 1. Uppfærðu staðbundnu pöntunina sérstaklega.';
    begin
        exit(TextLbl);
    end;

    /// <summary>Supplies the message contract chapter.</summary>
    /// <param name="Envelope">Request or output value.</param>
    /// <returns>The requested value or whether the chapter is supplied.</returns>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Supplies the message contract chapter.</summary>
    /// <param name="Metering">Request or output value.</param>
    /// <returns>The requested value or whether the chapter is supplied.</returns>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Supplies the message contract chapter.</summary>
    /// <param name="Workflow">Request or output value.</param>
    /// <returns>The requested value or whether the chapter is supplied.</returns>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Supplies the message contract chapter.</summary>
    /// <param name="Target">Request or output value.</param>
    /// <returns>The requested value or whether the chapter is supplied.</returns>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        OrderLbl: Label 'The Shopify Id of an imported order (table 30118).', Comment = 'is-IS=Shopify auðkenni innfluttrar pöntunar (tafla 30118).';
    begin
        Target.Add(ContractMgt.TargetEntry('Shpfy Order Header', 'data.orderId', OrderLbl));
        exit(true);
    end;

    /// <summary>Supplies the message contract chapter.</summary>
    /// <param name="Parameters">Request or output value.</param>
    /// <returns>The requested value or whether the chapter is supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        OrderLbl: Label 'The positive Shopify order Id, as a JSON integer.', Comment = 'is-IS=Jákvætt Shopify pöntunarauðkenni sem JSON heiltala.';
        CountLbl: Label 'Must be 1 to confirm this hard-to-undo write to one Shopify order.', Comment = 'is-IS=Verður að vera 1 til að staðfesta þessi skrif á eina Shopify pöntun sem erfitt er að afturkalla.';
    begin
        Parameters.Add(ContractMgt.Parameter('orderId', 'integer', true, OrderLbl));
        Parameters.Add(ContractMgt.Parameter('expectedCount', 'integer', true, CountLbl));
        exit(true);
    end;

    /// <summary>Supplies the message contract chapter.</summary>
    /// <param name="Response">Request or output value.</param>
    /// <returns>The requested value or whether the chapter is supplied.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        StatusLbl: Label 'Success.', Comment = 'is-IS=Success (tókst).';
        OrderidLbl: Label 'The imported Shopify order Id.', Comment = 'is-IS=Auðkenni innfluttu Shopify pöntunarinnar.';
        ShopcodeLbl: Label 'The shop derived from the order.', Comment = 'is-IS=Verslunin sem pöntunin tilheyrir.';
        FullypaidLbl: Label 'True: Shopify confirmed the order as fully paid.', Comment = 'is-IS=True: Shopify staðfesti að pöntunin væri að fullu greidd.';
    begin
        Fields.Add(ContractMgt.ResponseField('status', 'string', StatusLbl));
        Fields.Add(ContractMgt.ResponseField('orderId', 'integer', OrderidLbl));
        Fields.Add(ContractMgt.ResponseField('shopCode', 'string', ShopcodeLbl));
        Fields.Add(ContractMgt.ResponseField('fullyPaid', 'boolean', FullypaidLbl));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Supplies the message contract chapter.</summary>
    /// <param name="Effect">Request or output value.</param>
    /// <returns>The requested value or whether the chapter is supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
        ReadyLbl: Label 'An imported unpaid order, an enabled shop, no previous successful request and expectedCount = 1.', Comment = 'is-IS=Innflutt ógreidd pöntun, virk verslun, engin fyrri heppnuð beiðni og expectedCount = 1.';
        ChangesLbl: Label 'Marks the order paid in Shopify; hard to undo. Keeps a local success marker to refuse repeats; does not refresh the imported order. Explicit connector commits are ignored inside the rollback runner. A remote payment cannot be rolled back if the response is lost.', Comment = 'is-IS=Merkir pöntunina greidda í Shopify; erfitt að afturkalla. Geymir staðbundna staðfestingu til að hafna endurtekningum; uppfærir ekki innfluttu pöntunina. Beinum staðfestingum tengilsins er sleppt innan afturköllunarvinnslunnar. Ekki er hægt að afturkalla ytri greiðslu ef svarið glatast.';
    begin
        Preconditions.Add(ReadyLbl);
        Effect.Add('effect', 'write');
        Effect.Add('changes', ChangesLbl);
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'SHOPIFY Full ori');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    /// <summary>Supplies the message contract chapter.</summary>
    /// <param name="Related">Request or output value.</param>
    /// <returns>The requested value or whether the chapter is supplied.</returns>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        RefreshLbl: Label 'Refresh the local imported order after marking it paid.', Comment = 'is-IS=Uppfærðu staðbundnu innfluttu pöntunina eftir að hún er merkt greidd.';
    begin
        Related.Add(ContractMgt.RelatedEntry('Shopify.Order.Import', RefreshLbl));
        exit(true);
    end;

    /// <summary>Supplies the message contract chapter.</summary>
    /// <param name="Examples">Request or output value.</param>
    /// <returns>The requested value or whether the chapter is supplied.</returns>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Mark one imported order paid',
            '{"type":"Shopify.Order.MarkAsPaid","data":{"orderId":123456,"expectedCount":1}}',
            '{"status":"Success","orderId":123456,"shopCode":"MAIN","fullyPaid":true}'));
        exit(true);
    end;

    /// <summary>Supplies the message contract chapter.</summary>
    /// <param name="Overview">Request or output value.</param>
    /// <returns>The requested value or whether the chapter is supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Marks one imported order as paid in Shopify through public codeunit Shpfy Orders (30409), MarkAsPaid(OrderId, ShopCode). This is a hard-to-undo write in Shopify, confirmed with expectedCount = 1.';
        exit(true);
    end;

    /// <summary>Supplies the message contract chapter.</summary>
    /// <param name="Notes">Request or output value.</param>
    /// <returns>The requested value or whether the chapter is supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Not idempotent: a second successful request is refused using a local success marker, even before the imported order is refreshed. An already Fully Paid order is refused. The call does not refresh Business Central''s copy: use Shopify.Order.ForceSync or Shopify.Order.Import. A false connector result or exception returns BusinessCentralError and rolls back local writes, including the success marker. The runner ignores explicit connector commits to preserve this boundary; a rolled-back request may have no persisted log. Check Shopify log entries (table 30115) for available details. The remote Shopify payment is irreversible by this type. If the response is lost, check Shopify before retrying. Requires SHOPIFY Full ori and Microsoft Shopify permissions. No Business Central payment is posted.';
        exit(true);
    end;

    /// <summary>Supplies the message contract chapter.</summary>
    /// <returns>The requested value or whether the chapter is supplied.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    /// <summary>Supplies the message contract chapter.</summary>
    /// <param name="Errors">Request or output value.</param>
    /// <returns>The requested value or whether the chapter is supplied.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingErr, MissingErr, MissingErrNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, InvalidErr, InvalidErr, InvalidErrNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundErr, NotFoundErr, NotFoundErrNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, PreconditionErr, PreconditionErr, PreconditionErrNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionErr, PermissionErr, PermissionErrNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, ConnectorErr, ConnectorErr, ConnectorErrNextLbl));
        exit(true);
    end;

    /// <summary>Validates all input before the isolated connector write.</summary>
    /// <param name="Argument">Licensed request and response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        OrderHeader: Record "Shpfy Order Header";
        Shop: Record "Shpfy Shop";
        PaidMarker: Record "Order Paid Marker ori";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        OrderId: BigInteger;
        ExpectedCount: BigInteger;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if not IsEnabled() then begin
            Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, PermissionErr, '', PermissionErrNextLbl);
            exit;
        end;
        Request := Argument.GetRequestJson();
        if not Request.Get('orderId', Token) then begin
            Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, MissingErr, 'orderId', MissingErrNextLbl);
            exit;
        end;
        if not ReadInteger(Argument, Token, 'orderId', OrderId) then
            exit;
        if OrderId < 1 then begin
            Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, InvalidErr, 'orderId', InvalidErrNextLbl);
            exit;
        end;
        if not Request.Get('expectedCount', Token) then begin
            Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, MissingErr, 'expectedCount', MissingErrNextLbl);
            exit;
        end;
        if not ReadInteger(Argument, Token, 'expectedCount', ExpectedCount) then
            exit;
        if ExpectedCount <> 1 then begin
            Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, CountErr, 'expectedCount', PreconditionErrNextLbl);
            exit;
        end;
        OrderHeader.SetLoadFields("Shop Code", "Fully Paid");
        if not OrderHeader.Get(OrderId) then begin
            Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, NotFoundErr, 'orderId', NotFoundErrNextLbl);
            exit;
        end;
        Shop.SetLoadFields(Enabled);
        if not Shop.Get(OrderHeader."Shop Code") then begin
            Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, NotFoundErr, 'orderId', NotFoundErrNextLbl);
            exit;
        end;
        if not Shop.Enabled then begin
            Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, DisabledErr, 'orderId', PreconditionErrNextLbl);
            exit;
        end;
        if OrderHeader."Fully Paid" then begin
            Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, PaidErr, 'orderId', PreconditionErrNextLbl);
            exit;
        end;
        if PaidMarker.Get(Shop.Code, OrderId) then begin
            Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, RepeatedErr, 'orderId', PreconditionErrNextLbl);
            exit;
        end;
        Commit();
        if not Codeunit.Run(Codeunit::"Order MarkPaid Run ori", OrderHeader) then begin
            Refuse(Argument, "Bifrost Error Code ori"::BusinessCentralError, ConnectorErr, 'orderId', ConnectorErrNextLbl);
            exit;
        end;
        Response.Add('status', 'Success');
        Response.Add('orderId', OrderId);
        Response.Add('shopCode', OrderHeader."Shop Code");
        Response.Add('fullyPaid', true);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure ReadInteger(var Argument: Record "Message Argument ori"; Token: JsonToken; ParameterName: Text; var Value: BigInteger): Boolean
    var
        Raw: Text;
        Digits: Text;
    begin
        Token.WriteTo(Raw);
        Digits := Raw;
        if CopyStr(Digits, 1, 1) = '-' then
            Digits := CopyStr(Digits, 2);
        if (Digits = '') or (DelChr(Digits, '=', '0123456789') <> '') or not Evaluate(Value, Raw, 9) then begin
            Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, InvalidErr, ParameterName, InvalidErrNextLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure Refuse(var Argument: Record "Message Argument ori"; Code: Enum "Bifrost Error Code ori"; Message: Text; Parameter: Text; NextStep: Text)
    begin
        Argument.RespondWithError(Code, Message, Parameter, '', '', NextStep);
    end;

    var
        CountErr: Label 'expectedCount must be 1 to confirm marking this order as paid.', Comment = 'is-IS=expectedCount verður að vera 1 til að staðfesta að þessi pöntun verði merkt greidd.';
        DisabledErr: Label 'The shop of this order is disabled.', Comment = 'is-IS=Verslun þessarar pöntunar er óvirk.';
        PaidErr: Label 'The imported order is already marked Fully Paid.', Comment = 'is-IS=Innflutta pöntunin er þegar merkt að fullu greidd.';
        RepeatedErr: Label 'This order was already successfully marked as paid by an earlier request.', Comment = 'is-IS=Þessi pöntun var þegar merkt greidd með fyrri heppnaðri beiðni.';
        MissingErr: Label 'A required parameter is missing.', Comment = 'is-IS=Nauðsynlega færibreytu vantar.';
        MissingErrNextLbl: Label 'Send orderId and expectedCount = 1.', Comment = 'is-IS=Sendu orderId og expectedCount = 1.';
        InvalidErr: Label 'The parameter must be a JSON integer in range.', Comment = 'is-IS=Færibreytan verður að vera JSON heiltala innan marka.';
        InvalidErrNextLbl: Label 'Send a positive orderId and expectedCount as integers.', Comment = 'is-IS=Sendu jákvætt orderId og expectedCount sem heiltölur.';
        NotFoundErr: Label 'The imported order or its shop was not found.', Comment = 'is-IS=Innflutta pöntunin eða verslun hennar fannst ekki.';
        NotFoundErrNextLbl: Label 'Import the order and verify its shop.', Comment = 'is-IS=Flyttu pöntunina inn og staðfestu verslun hennar.';
        PreconditionErr: Label 'The shop is disabled, the order is already paid or previously submitted, or expectedCount is not 1.', Comment = 'is-IS=Verslunin er óvirk, pöntunin er þegar greidd eða áður send, eða expectedCount er ekki 1.';
        PreconditionErrNextLbl: Label 'Enable the shop, choose an unpaid order and confirm expectedCount = 1.', Comment = 'is-IS=Virkjaðu verslunina, veldu ógreidda pöntun og staðfestu expectedCount = 1.';
        PermissionErr: Label 'You do not have permission to mark Shopify orders as paid.', Comment = 'is-IS=Þú hefur ekki heimild til að merkja Shopify pantanir sem greiddar.';
        PermissionErrNextLbl: Label 'Ask an administrator for SHOPIFY Full ori and Shopify Connector permissions.', Comment = 'is-IS=Biddu kerfisstjóra um SHOPIFY Full ori og heimildir Shopify Connector.';
        ConnectorErr: Label 'Shopify did not confirm payment. Check Shopify log entries (table 30115).', Comment = 'is-IS=Shopify staðfesti ekki greiðslu. Skoðaðu Shopify annálsfærslur (töflu 30115).';
        ConnectorErrNextLbl: Label 'Check Shopify and available log entries before retrying.', Comment = 'is-IS=Skoðaðu Shopify og tiltækar annálsfærslur áður en þú reynir aftur.';
}
