namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using Origo.Bifrost;

/// <summary>Validates and sends catalog prices through the Microsoft Shopify Connector report.</summary>
codeunit 73732080 "Catalog SyncPrices Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Reports whether the caller holds the table permissions this message type needs.</summary>
    /// <returns>True when the permissions are held.</returns>
    procedure IsEnabled(): Boolean
    var
        Shop: Record "Shpfy Shop";
        Catalog: Record "Shpfy Catalog";
        ShopifyCompany: Record "Shpfy Company";
        Skipped: RecordRef;
    begin
        // The connector keeps this log table internal; only its metadata and row counts are read here.
        Skipped.Open(30159);
        exit(Shop.ReadPermission() and Catalog.ReadPermission() and ShopifyCompany.ReadPermission() and Skipped.ReadPermission() and Skipped.WritePermission());
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
        DescriptionLbl: Label 'Sends Business Central prices to the price lists of a Shopify shop''s catalogs.', Comment = 'is-IS=Sendir verð Business Central í verðlista vöruskráa Shopify verslunar.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search terms users say for this type, English with the Icelandic translation.</summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'shopify catalogs, catalog prices, sync catalog prices', Comment = 'is-IS=shopify vöruskrár, verð vöruskráa, samstilla verð vöruskráa';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Use to send prices for catalogs with Sync Prices enabled. Optionally select one catalog, a catalog type or a Shopify company.', Comment = 'is-IS=Notað til að senda verð fyrir vöruskrár með verðsamstillingu virka. Hægt er að velja eina vöruskrá, tegund vöruskrár eða Shopify fyrirtæki.';
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
        Target.Add(ContractMgt.TargetEntry('Shpfy Shop', 'data.shopCode', 'The code of the Shopify shop (table 30102) whose catalogs are priced.'));
        exit(true);
    end;

    /// <summary>Declares accepted request parameters.</summary>
    /// <param name="Parameters">Receives the parameter declarations.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('shopCode', 'string', true, 'Required Shopify shop code, at most 20 characters.'));
        Parameters.Add(ContractMgt.Parameter('catalogId', 'integer', false, 'Positive Shopify catalog ID. Omit to select all matching catalogs.'));
        Parameters.Add(ContractMgt.Parameter('catalogType', 'string', false, 'Company or Market. Omit for both types.'));
        Parameters.Add(ContractMgt.Parameter('companyId', 'integer', false, 'Positive Shopify company ID, resolved to its local SystemId within the selected shop.'));
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
        Fields.Add(ContractMgt.ResponseField('shopCode', 'string', 'The Shopify shop code.'));
        Fields.Add(ContractMgt.ResponseField('catalogsConsidered', 'integer', 'Matching catalog rows with Sync Prices enabled, including currency mismatches.'));
        Fields.Add(ContractMgt.ResponseField('skippedRecords', 'integer', 'New skipped-record log rows for the selected catalogs during this call.'));
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
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'shopCode is required.', 'Required key missing.', 'Send data.shopCode.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'Invalid parameter.', 'Shop code must be text; IDs positive integers; type Company or Market.', 'Correct the named parameter.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'Unknown parameter.', 'Only the four declared keys are accepted.', 'Remove the unknown key.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'Shop, catalog or company not found.', 'No matching record in this shop.', 'Read Shopify shops, catalogs or companies with Data.Records.Get.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Shop disabled or no matching enabled catalog.', 'No connector call was made.', 'Enable the shop or Sync Prices, or adjust the filters.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Permission denied.', 'Caller lacks required permissions.', 'Ask for SHOPIFY Full ori and Microsoft Shopify permissions.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Connector failed.', 'The connector error text is returned.', 'Fix the reported cause and retry.'));
        exit(true);
    end;

    /// <summary>Supplies the effect chapter for this message type.</summary>
    /// <param name="Effect">Out: effect, changes, idempotency and preconditions.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The shop exists and is enabled.');
        Preconditions.Add('At least one catalog matches and has Sync Prices enabled.');
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Runs connector report 30116 to send changed catalog prices to Shopify price lists. Business Central records skipped catalogs in table 30159. Currency mismatch is a skip, not an error.');
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
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', 'You need to find the shop, e.g. table 30102 Shpfy Shop.'));
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
        Examples.Add(ContractMgt.Example('Send catalog prices to Shopify',
            '{"type":"Shopify.Catalog.SyncPrices","data":{"shopCode":"MAIN"}}',
            '{"status":"Success","shopCode":"MAIN","catalogsConsidered":2,"skippedRecords":0}'));
        exit(true);
    end;

    /// <summary>Summarizes the operation.</summary>
    /// <param name="Overview">Out: the overview.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Sends Business Central prices to the Shopify price lists of matching catalogs with Sync Prices enabled, through connector report 30116 Shpfy Sync Catalog Prices. Uses catalog price, discount and posting groups.';
        exit(true);
    end;

    /// <summary>Explains the rules and limits of the operation.</summary>
    /// <param name="Notes">Out: the notes.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Requires Shopify Connector 29 or later; version 28 is refused because report 30116 cannot filter catalogs. Idempotent: the connector reads current Shopify prices and sends only changes, in batches of 250. catalogId selects one Shopify catalog; catalogType is Company or Market; companyId is the Shopify company ID, resolved to its local SystemId. Filters intersect and never select another shop. Currency mismatches count in catalogsConsidered and produce skippedRecords. Counts describe local rows, not prices sent. A connector failure rolls back uncommitted BC changes; prices already sent to Shopify cannot be rolled back. Retry after fixing the reported cause. Requires SHOPIFY Full ori and Microsoft Shopify permissions.';
        exit(true);
    end;

    /// <summary>Classifies the message direction for Foundation.</summary>
    /// <returns>The direction of the operation.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    /// <summary>Validates all filters before invoking the connector in an isolated codeunit.</summary>
    /// <param name="Argument">The request and its typed response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Shop: Record "Shpfy Shop";
        Catalog: Record "Shpfy Catalog";
        ShopifyCompany: Record "Shpfy Company";
        SyncRun: Codeunit "Catalog SyncPrices Run ori";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        ShopCode: Text;
        CatalogTypeText: Text;
        CatalogId: BigInteger;
        CompanyId: BigInteger;
        CatalogType: Enum "Shpfy Catalog Type";
        CatalogCount: Integer;
        LastSkipEntry: Integer;
        NoPermissionLbl: Label 'You do not have permission to send catalog prices to Shopify.', Comment = 'is-IS=Þú hefur ekki heimild til að senda verð vöruskráa til Shopify.';
        PermissionNextLbl: Label 'Ask an administrator for SHOPIFY Full ori and Microsoft Shopify permissions.', Comment = 'is-IS=Biddu kerfisstjóra um SHOPIFY Full ori og Microsoft Shopify heimildir.';
        MissingLbl: Label 'Parameter "shopCode" is required.', Comment = 'is-IS=Færibreytan "shopCode" er nauðsynleg.';
        ShopNextLbl: Label 'Send data.shopCode with an existing Shopify shop code.', Comment = 'is-IS=Sendu data.shopCode með kóða Shopify verslunar sem er til.';
        NotFoundLbl: Label 'The requested %1 was not found in this shop.', Comment = '%1 = parameter name||is-IS=Umbeðið %1 fannst ekki í þessari verslun.';
        FindNextLbl: Label 'Read Shopify shops (30102), catalogs (30152) or companies (30150) with Data.Records.Get and correct the filter.', Comment = 'is-IS=Lestu Shopify verslanir (30102), vöruskrár (30152) eða fyrirtæki (30150) með Data.Records.Get og leiðréttu síuna.';
        DisabledLbl: Label 'Shopify shop %1 is not enabled.', Comment = '%1 = shop code||is-IS=Shopify verslun %1 er ekki virk.';
        EnableNextLbl: Label 'Enable the shop on the Shopify Shop Card.', Comment = 'is-IS=Virkjaðu verslunina á Shopify verslunarspjaldinu.';
        EmptyLbl: Label 'No catalog with Sync Prices enabled matches the filters.', Comment = 'is-IS=Engin vöruskrá með verðsamstillingu virka passar við síurnar.';
        EmptyNextLbl: Label 'Enable Sync Prices on a catalog in this shop or adjust the catalog filters.', Comment = 'is-IS=Virkjaðu verðsamstillingu á vöruskrá í þessari verslun eða breyttu vöruskrársíunum.';
        FailedLbl: Label 'The catalog price sync failed. %1', Comment = '%1 = connector error text||is-IS=Verðsamstilling vöruskráa mistókst. %1';
        RetryLbl: Label 'Fix the cause reported by the connector, then retry.', Comment = 'is-IS=Lagaðu orsökina sem tengillinn tilgreinir og reyndu aftur.';
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if not IsEnabled() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, NoPermissionLbl, '', '', '', PermissionNextLbl);
            exit;
        end;
        Request := Argument.GetRequestJson();
        if not Request.Get('shopCode', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingLbl, 'shopCode', '', '', ShopNextLbl);
            exit;
        end;
        if not ReadString(Token, ShopCode) then begin
            InvalidParameter(Argument, 'shopCode');
            exit;
        end;
        if (ShopCode = '') or (StrLen(ShopCode) > MaxStrLen(Shop.Code)) then begin
            InvalidParameter(Argument, 'shopCode');
            exit;
        end;
        if Request.Get('catalogId', Token) then
            if not ReadPositiveId(Token, CatalogId) then begin
                InvalidParameter(Argument, 'catalogId');
                exit;
            end;
        if Request.Get('companyId', Token) then
            if not ReadPositiveId(Token, CompanyId) then begin
                InvalidParameter(Argument, 'companyId');
                exit;
            end;
        if Request.Get('catalogType', Token) then begin
            if not ReadString(Token, CatalogTypeText) then begin
                InvalidParameter(Argument, 'catalogType');
                exit;
            end;
            case CatalogTypeText of
                'Company':
                    CatalogType := CatalogType::Company;
                'Market':
                    CatalogType := CatalogType::Market;
                else begin
                    InvalidParameter(Argument, 'catalogType');
                    exit;
                end;
            end;
        end;
        Shop.SetLoadFields(Code, Enabled);
        if not Shop.Get(CopyStr(ShopCode, 1, MaxStrLen(Shop.Code))) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundLbl, 'shopCode'), 'shopCode', ShopCode, '', FindNextLbl);
            exit;
        end;
        if not Shop.Enabled then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(DisabledLbl, Shop.Code), 'shopCode', Shop.Code, '', EnableNextLbl);
            exit;
        end;
        Catalog.SetRange("Shop Code", Shop.Code);
        if CatalogId <> 0 then begin
            Catalog.SetRange(Id, CatalogId);
            if Catalog.IsEmpty() then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundLbl, 'catalogId'), 'catalogId', Format(CatalogId, 0, 9), '', FindNextLbl);
                exit;
            end;
        end;
        if CompanyId <> 0 then begin
            ShopifyCompany.SetLoadFields(Id, "Shop Code", SystemId);
            ShopifyCompany.SetRange(Id, CompanyId);
            ShopifyCompany.SetRange("Shop Code", Shop.Code);
            if not ShopifyCompany.FindFirst() then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundLbl, 'companyId'), 'companyId', Format(CompanyId, 0, 9), '', FindNextLbl);
                exit;
            end;
            Catalog.SetRange("Company SystemId", ShopifyCompany.SystemId);
        end;
        if CatalogTypeText <> '' then
            Catalog.SetRange("Catalog Type", CatalogType);
        Catalog.SetRange("Sync Prices", true);
        CatalogCount := Catalog.Count();
        if CatalogCount = 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, EmptyLbl, 'catalogId', '', '', EmptyNextLbl);
            exit;
        end;
        // BC 28 report 30116 cannot accept a Catalog view. Never let a selected-catalog request become a shop-wide write.
        if not SupportsCatalogView(Argument) then
            exit;
        LastSkipEntry := LastSkippedEntry();
        Shop.SetRecFilter();
        SyncRun.SetParameters(Shop.Code, Shop.GetView(false), Catalog.GetView(false), CatalogType);
        Commit();
        ClearLastError();
        if not SyncRun.Run() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, StrSubstNo(FailedLbl, GetLastErrorText()), 'shopCode', Shop.Code, '', RetryLbl);
            exit;
        end;
        Response.Add('status', 'Success');
        Response.Add('shopCode', Shop.Code);
        Response.Add('catalogsConsidered', CatalogCount);
        Response.Add('skippedRecords', CountNewSkips(Catalog, LastSkipEntry));
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure SupportsCatalogView(var Argument: Record "Message Argument ori"): Boolean
    var
        ConnectorInfo: ModuleInfo;
        ConnectorId: Guid;
        UnsupportedLbl: Label 'Catalog price synchronization requires Shopify Connector version 29 or later.', Comment = 'is-IS=Verðsamstilling vöruskráa krefst Shopify Connector útgáfu 29 eða nýrri.';
        UpgradeLbl: Label 'Upgrade the Shopify Connector before retrying; version 28 cannot filter this report by catalog.', Comment = 'is-IS=Uppfærðu Shopify Connector áður en þú reynir aftur; útgáfa 28 getur ekki síað þessa skýrslu eftir vöruskrá.';
    begin
        ConnectorId := 'ec255f57-31d0-4ca2-b751-f2fa7c745abb';
        NavApp.GetModuleInfo(ConnectorId, ConnectorInfo);
        if ConnectorInfo.AppVersion.Major >= 29 then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, UnsupportedLbl, '', '', '', UpgradeLbl);
    end;

    local procedure InvalidParameter(var Argument: Record "Message Argument ori"; ParameterName: Text)
    var
        InvalidLbl: Label 'Parameter "%1" has an invalid value.', Comment = '%1 = parameter name||is-IS=Færibreytan "%1" hefur ógilt gildi.';
        NextLbl: Label 'Send shopCode as non-empty text up to 20 characters, IDs as positive integers and catalogType as Company or Market; omit unused filters.', Comment = 'is-IS=Sendu shopCode sem texta með 1 til 20 stöfum, auðkenni sem jákvæðar heiltölur og catalogType sem Company eða Market; slepptu síum sem eru ekki notaðar.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidLbl, ParameterName), ParameterName, '', '', NextLbl);
    end;

    local procedure ReadString(Token: JsonToken; var Value: Text): Boolean
    var
        JsonText: Text;
    begin
        Token.WriteTo(JsonText);
        if not JsonText.StartsWith('"') then
            exit(false);
        Value := Token.AsValue().AsText();
        exit(true);
    end;

    local procedure ReadPositiveId(Token: JsonToken; var Id: BigInteger): Boolean
    var
        ValueText: Text;
    begin
        Token.WriteTo(ValueText);
        if ValueText = '' then
            exit(false);
        if DelChr(ValueText, '=', '0123456789') <> '' then
            exit(false);
        if not Evaluate(Id, ValueText, 9) then
            exit(false);
        exit(Id > 0);
    end;

    local procedure LastSkippedEntry(): Integer
    var
        Skipped: RecordRef;
    begin
        Skipped.Open(30159);
        Skipped.SetLoadFields(1);
        if Skipped.FindLast() then
            exit(Skipped.Field(1).Value());
    end;

    local procedure CountNewSkips(var Catalog: Record "Shpfy Catalog"; LastEntry: Integer) Counted: Integer
    var
        Skipped: RecordRef;
    begin
        Skipped.Open(30159);
        Skipped.Field(1).SetFilter('>%1', LastEntry);
        Skipped.Field(3).SetRange(Database::"Shpfy Catalog");
        Catalog.SetLoadFields(Id, "Company SystemId");
        if Catalog.FindSet() then
            repeat
                Skipped.Field(5).SetRange(Catalog.RecordId());
                Counted += Skipped.Count();
            until Catalog.Next() = 0;
    end;
}
