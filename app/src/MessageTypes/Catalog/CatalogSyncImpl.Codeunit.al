namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using Origo.Bifrost;

/// <summary>Imports Shopify catalogs through the connector report, with isolated rollback.</summary>
codeunit 73732080 "Catalog Sync Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        Catalog: Record "Shpfy Catalog";
        Relation: Record "Shpfy Market Catalog Relation";
    begin
        exit(Shop.ReadPermission() and Catalog.ReadPermission() and Catalog.WritePermission() and Relation.WritePermission());
    end;

    /// <summary>Identifies the table used by the message filter contract.</summary>
    /// <returns>The table ID.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Shpfy Shop");
    end;

    /// <summary>Describes this message type for callers selecting an operation.</summary>
    /// <returns>The description in the current language.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Imports company catalogs and market catalogs from one Shopify shop into Business Central.', Comment = 'is-IS=Flytur fyrirtækjavörulista og markaðsvörulista úr einni Shopify verslun inn í Business Central.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search terms users say for this type, English with the Icelandic translation.</summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'shopify catalogs, import catalogs, company catalogs, market catalogs, sync catalogs', Comment = 'is-IS=shopify vörulistar, flytja inn vörulista, fyrirtækjavörulistar, markaðsvörulistar, samstilla vörulista';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Use to import catalogs and refresh market relations for one enabled shop. Run Shopify.Company.Sync first for company catalogs. Does not synchronize prices or create catalogs in Shopify.', Comment = 'is-IS=Notað til að flytja inn vörulista og endurnýja markaðstengsl fyrir eina virka verslun. Keyrðu Shopify.Company.Sync fyrst fyrir fyrirtækjavörulista. Samstillir ekki verð eða stofnar vörulista í Shopify.';
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
        Target.Add(ContractMgt.TargetEntry('Shpfy Shop', 'data.shopCode', 'The code of an enabled Shopify shop (table 30102).'));
        exit(true);
    end;

    /// <summary>Declares accepted request parameters.</summary>
    /// <param name="Parameters">Receives the parameter declarations.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('shopCode', 'string', true, 'The code of one enabled Shopify shop, at most 20 characters.'));
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
        Fields.Add(ContractMgt.ResponseField('shopCode', 'string', 'The synchronized shop.'));
        Fields.Add(ContractMgt.ResponseField('catalogsBefore', 'integer', 'Catalog rows of this shop before the connector ran.'));
        Fields.Add(ContractMgt.ResponseField('catalogsAfter', 'integer', 'Catalog rows of this shop after the connector ran.'));
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
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'shopCode is required.', 'No shop code supplied.', 'Send data.shopCode.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'Invalid request parameter.', 'Unknown key or malformed shop code.', 'Send only shopCode as a nonempty string of at most 20 characters.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'Shop not found.', 'The shop does not exist.', 'Read table 30102 to find a shop.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Shop is disabled.', 'The shop is not enabled.', 'Enable the shop before retrying.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Permission denied.', 'The caller cannot import catalogs.', 'Ask for SHOPIFY Full ori and Microsoft Shopify write permissions.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Catalog import failed.', 'Connector text is returned; local writes of this run are rolled back.', 'Correct the reported cause and retry.'));
        exit(true);
    end;

    /// <summary>Supplies the effect chapter for this message type.</summary>
    /// <param name="Effect">Out: effect, changes, idempotency and preconditions.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The shop exists, is enabled and has a working Shopify connection.');
        Preconditions.Add('Import companies first with Shopify.Company.Sync to include their catalogs. Without companies, market catalogs are still imported.');
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Runs report 30115 Shpfy Sync Catalogs with its default options for exactly one shop. Imports or updates catalog rows (30152) and refreshes market catalog relations (30400). Nothing is sent to Shopify. Commits the dispatcher transaction before the isolated runner; a failure rolls back this run. Explicit connector commits are refused.');
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
        Related.Add(ContractMgt.RelatedEntry('Shopify.Company.Sync', 'Import companies before importing their catalogs.'));
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', 'Read shops (30102), catalogs (30152) and market catalog relations (30400).'));
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
        Examples.Add(ContractMgt.Example('Import catalogs for one shop', '{"type":"Shopify.Catalog.Sync","data":{"shopCode":"WEBSHOP"}}', '{"status":"Success","shopCode":"WEBSHOP","catalogsBefore":0,"catalogsAfter":2}'));
        exit(true);
    end;

    /// <summary>Summarizes the operation.</summary>
    /// <param name="Overview">Out: the overview.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Imports company catalogs and market catalogs from one enabled Shopify shop into Business Central through report 30115 Shpfy Sync Catalogs. Writes local rows only; does not synchronize prices.';
        exit(true);
    end;

    /// <summary>Explains the rules and limits of the operation.</summary>
    /// <param name="Notes">Out: the notes.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Run Shopify.Company.Sync first for company catalogs. Without imported companies, the connector still imports market catalogs. Repeated calls update existing catalogs, so this operation is idempotent. The connector does not remove local catalog rows absent from Shopify. For every returned market catalog, it deletes and rebuilds its market relations; relations of catalogs not returned are retained. Counts cover only the selected shop. A failure returns BusinessCentralError with the connector text and rolls back local writes from this run. The dispatcher transaction is committed before the isolated run; explicit connector commits are refused. Requires SHOPIFY Full ori and Microsoft Shopify permissions. No page or action is added.';
        exit(true);
    end;

    /// <summary>Classifies the message direction for Foundation.</summary>
    /// <returns>The direction of the operation.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    /// <summary>Validates the request and imports catalogs for one shop.</summary>
    /// <param name="Argument">Request and typed response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Shop: Record "Shpfy Shop";
        Catalog: Record "Shpfy Catalog";
        Runner: Codeunit "Catalog Sync Run ori";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        RequestKey: Text;
        ShopCode: Text;
        Raw: Text;
        BeforeCount: Integer;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if not IsEnabled() then begin
            Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, 'shopCode', '');
            exit;
        end;
        Request := Argument.GetRequestJson();
        foreach RequestKey in Request.Keys() do
            if RequestKey <> 'shopCode' then begin
                Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, RequestKey, '');
                exit;
            end;
        if not Request.Get('shopCode', Token) then begin
            Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, 'shopCode', '');
            exit;
        end;
        Token.WriteTo(Raw);
        if CopyStr(Raw, 1, 1) <> '"' then begin
            Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'shopCode', '');
            exit;
        end;
        ShopCode := Token.AsValue().AsText();
        if (ShopCode.Trim() = '') or (StrLen(ShopCode) > MaxStrLen(Shop.Code)) then begin
            Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'shopCode', '');
            exit;
        end;
        Shop.SetLoadFields(Enabled);
        if not Shop.Get(CopyStr(ShopCode, 1, MaxStrLen(Shop.Code))) then begin
            Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'shopCode', '');
            exit;
        end;
        if not Shop.Enabled then begin
            Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'shopCode', '');
            exit;
        end;
        Catalog.SetRange("Shop Code", Shop.Code);
        BeforeCount := Catalog.Count();
        Runner.SetShopCode(Shop.Code);
        // Complete dispatcher writes before starting the catchable connector transaction.
        Commit();
        ClearLastError();
        if not Runner.Run() then begin
            Refuse(Argument, "Bifrost Error Code ori"::BusinessCentralError, 'shopCode', GetLastErrorText());
            exit;
        end;
        Response.Add('status', 'Success');
        Response.Add('shopCode', Shop.Code);
        Response.Add('catalogsBefore', BeforeCount);
        Response.Add('catalogsAfter', Catalog.Count());
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure Refuse(var Argument: Record "Message Argument ori"; Code: Enum "Bifrost Error Code ori"; Parameter: Text; Detail: Text)
    var
        MissingLbl: Label 'Parameter shopCode is required.', Comment = 'is-IS=Færibreytan shopCode er nauðsynleg.';
        InvalidLbl: Label 'Parameter %1 is unknown or has an invalid format. Send only shopCode as a nonempty string of at most 20 characters.', Comment = '%1 = parameter||is-IS=Færibreytan %1 er óþekkt eða á ógildu sniði. Sendu aðeins shopCode sem texta sem er ekki tómur og er að hámarki 20 stafir.';
        NotFoundLbl: Label 'The Shopify shop was not found.', Comment = 'is-IS=Shopify verslunin fannst ekki.';
        DisabledLbl: Label 'The Shopify shop is not enabled.', Comment = 'is-IS=Shopify verslunin er ekki virk.';
        DeniedLbl: Label 'You do not have permission to import Shopify catalogs.', Comment = 'is-IS=Þú hefur ekki heimild til að flytja inn Shopify vörulista.';
        FailedLbl: Label 'Catalog import failed. Local writes from this run were rolled back. %1', Comment = '%1 = connector text||is-IS=Innflutningur vörulista mistókst. Staðbundnar breytingar úr þessari keyrslu voru afturkallaðar. %1';
        ExpectedLbl: Label 'an enabled Shopify shop and permission to import catalogs', Comment = 'is-IS=virk Shopify verslun og heimild til að flytja inn vörulista';
        NextLbl: Label 'Correct the request or the reported cause. Enable the shop and ask an administrator for SHOPIFY Full ori and Microsoft Shopify write permissions, then retry.', Comment = 'is-IS=Leiðréttu beiðnina eða tilgreinda orsök. Virkjaðu verslunina og biddu kerfisstjóra um SHOPIFY Full ori og Microsoft Shopify skrifheimildir og reyndu aftur.';
        MessageText: Text;
    begin
        case Code of
            Code::MissingParameter:
                MessageText := MissingLbl;
            Code::InvalidParameterFormat:
                MessageText := StrSubstNo(InvalidLbl, Parameter);
            Code::RecordNotFound:
                MessageText := NotFoundLbl;
            Code::PreconditionFailed:
                MessageText := DisabledLbl;
            Code::PermissionDenied:
                MessageText := DeniedLbl;
            else
                MessageText := StrSubstNo(FailedLbl, Detail);
        end;
        Argument.RespondWithError(Code, MessageText, Parameter, '', ExpectedLbl, NextLbl);
    end;
}
