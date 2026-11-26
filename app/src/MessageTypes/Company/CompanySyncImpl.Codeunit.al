namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.Customer;
using Origo.Bifrost;

/// <summary>Synchronizes companies for one shop through the Microsoft connector, with a local rollback boundary.</summary>
codeunit 73732044 "Company Sync Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Supplies IsEnabled for Shopify.Company.Sync.</summary>
    /// <returns>The declared value or whether the chapter is supplied.</returns>
    procedure IsEnabled(): Boolean
    var
        Shop: Record "Shpfy Shop";
        Company: Record "Shpfy Company";
        Customer: Record Customer;
    begin
        exit(Shop.WritePermission() and Company.WritePermission() and Customer.WritePermission());
    end;

    /// <summary>Supplies GetFilterTableNo for Shopify.Company.Sync.</summary>
    /// <returns>The declared value or whether the chapter is supplied.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Shpfy Shop");
    end;

    /// <summary>Supplies GetDescription for Shopify.Company.Sync.</summary>
    /// <returns>The declared value or whether the chapter is supplied.</returns>
    procedure GetDescription(): Text[250]
    var
        TextLbl: Label 'Imports and updates Shopify companies and their Business Central customer links for one shop, as the shop is set up.', Comment = 'is-IS=Flytur inn og uppfærir Shopify fyrirtæki og tengingar þeirra við viðskiptamenn í Business Central fyrir eina verslun samkvæmt uppsetningu hennar.';
    begin
        exit(TextLbl);
    end;

    /// <summary>Supplies GetKeywords for Shopify.Company.Sync.</summary>
    /// <returns>The declared value or whether the chapter is supplied.</returns>
    procedure GetKeywords(): Text
    var
        TextLbl: Label 'shopify company sync, import shopify companies, update shopify companies, synchronize b2b companies, company customer links', Comment = 'is-IS=shopify samstilling fyrirtækja, flytja inn shopify fyrirtæki, uppfæra shopify fyrirtæki, samstilla b2b fyrirtæki, fyrirtæki tengingar viðskiptamanna';
    begin
        exit(TextLbl);
    end;

    /// <summary>Supplies GetSelectionDescription for Shopify.Company.Sync.</summary>
    /// <returns>The declared value or whether the chapter is supplied.</returns>
    procedure GetSelectionDescription(): Text
    var
        TextLbl: Label 'Use to synchronize companies for one Shopify shop. Use Shopify.Customer.Sync for individual customers; this type follows company mapping and import/export settings.', Comment = 'is-IS=Notað til að samstilla fyrirtæki fyrir eina Shopify verslun. Notaðu Shopify.Customer.Sync fyrir einstaka viðskiptamenn; þessi tegund fylgir vörpun fyrirtækja og inn- og útflutningsstillingum.';
    begin
        exit(TextLbl);
    end;

    /// <summary>Supplies GetEnvelope for Shopify.Company.Sync.</summary>
    /// <param name="Envelope">Receives the contract chapter.</param>
    /// <returns>The declared value or whether the chapter is supplied.</returns>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Supplies GetMetering for Shopify.Company.Sync.</summary>
    /// <param name="Metering">Receives the contract chapter.</param>
    /// <returns>The declared value or whether the chapter is supplied.</returns>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Supplies GetWorkflow for Shopify.Company.Sync.</summary>
    /// <param name="Workflow">Receives the contract chapter.</param>
    /// <returns>The declared value or whether the chapter is supplied.</returns>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Supplies GetTarget for Shopify.Company.Sync.</summary>
    /// <param name="Target">Receives the contract chapter.</param>
    /// <returns>The declared value or whether the chapter is supplied.</returns>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ShopLbl: Label 'Enabled Shopify shop (table 30102).', Comment = 'is-IS=Virk Shopify verslun (tafla 30102).';
    begin
        Target.Add(ContractMgt.TargetEntry('Shpfy Shop', 'data.shopCode', ShopLbl));
        exit(true);
    end;

    /// <summary>Supplies GetParameters for Shopify.Company.Sync.</summary>
    /// <param name="Parameters">Receives the contract chapter.</param>
    /// <returns>The declared value or whether the chapter is supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ShopLbl: Label 'Code of an enabled Shopify shop, at most 20 characters. Company settings determine import and export.', Comment = 'is-IS=Kóði virkrar Shopify verslunar, að hámarki 20 stafir. Fyrirtækjastillingar ráða inn- og útflutningi.';
    begin
        Parameters.Add(ContractMgt.Parameter('shopCode', 'string', true, ShopLbl));
        exit(true);
    end;

    /// <summary>Supplies GetResponse for Shopify.Company.Sync.</summary>
    /// <param name="Response">Receives the contract chapter.</param>
    /// <returns>The declared value or whether the chapter is supplied.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        StatusLbl: Label 'Success only when the connector returns without an error.', Comment = 'is-IS=Success aðeins þegar tengillinn lýkur án villu.';
        ShopLbl: Label 'The synchronized shop.', Comment = 'is-IS=Samstillta verslunin.';
        ImportLbl: Label 'Applied Company Import From Shopify setting: None, AllCompanies or WithOrderImport.', Comment = 'is-IS=Stillingin Company Import From Shopify sem var notuð: None, AllCompanies eða WithOrderImport.';
        ExportLbl: Label 'Applied Can Update Shopify Companies setting.', Comment = 'is-IS=Stillingin Can Update Shopify Companies sem var notuð.';
        BeforeLbl: Label 'Company rows for this shop before the run.', Comment = 'is-IS=Fyrirtækjafærslur þessarar verslunar fyrir keyrslu.';
        AfterLbl: Label 'Company rows for this shop after the run; not a count of remote writes.', Comment = 'is-IS=Fyrirtækjafærslur þessarar verslunar eftir keyrslu; ekki fjöldi fjarskrifta.';
    begin
        Fields.Add(ContractMgt.ResponseField('status', 'string', StatusLbl));
        Fields.Add(ContractMgt.ResponseField('shopCode', 'string', ShopLbl));
        Fields.Add(ContractMgt.ResponseField('companyImportFromShopify', 'string', ImportLbl));
        Fields.Add(ContractMgt.ResponseField('canUpdateShopifyCompanies', 'boolean', ExportLbl));
        Fields.Add(ContractMgt.ResponseField('companiesBefore', 'integer', BeforeLbl));
        Fields.Add(ContractMgt.ResponseField('companiesAfter', 'integer', AfterLbl));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Supplies GetErrors for Shopify.Company.Sync.</summary>
    /// <param name="Errors">Receives the contract chapter.</param>
    /// <returns>The declared value or whether the chapter is supplied.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ErrorLbl: Label 'Company synchronization was refused; the response code and text identify the cause.', Comment = 'is-IS=Samstillingu fyrirtækja var hafnað; svarskóði og texti tilgreina orsökina.';
        NothingLbl: Label 'Validation makes no changes. A connector failure rolls back local writes; completed Shopify requests cannot be undone.', Comment = 'is-IS=Staðfesting breytir engu. Villa í tengli afturkallar staðbundnar breytingar; ekki er hægt að afturkalla loknar Shopify beiðnir.';
        NextLbl: Label 'Correct the named parameter, shop setup or permission, then retry.', Comment = 'is-IS=Leiðréttu nefnda færibreytu, uppsetningu verslunar eða heimild og reyndu aftur.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, ErrorLbl, NothingLbl, NextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, ErrorLbl, NothingLbl, NextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, ErrorLbl, NothingLbl, NextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, ErrorLbl, NothingLbl, NextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, ErrorLbl, NothingLbl, NextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, ErrorLbl, NothingLbl, NextLbl));
        exit(true);
    end;

    /// <summary>Supplies GetEffect for Shopify.Company.Sync.</summary>
    /// <param name="Effect">Receives the contract chapter.</param>
    /// <returns>The declared value or whether the chapter is supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The shop exists and is enabled.');
        Preconditions.Add('SHOPIFY Full ori and the Microsoft Shopify and customer write permissions are required.');
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Runs Shpfy Sync Companies (30285), behind report 30114. Imports Shopify company/location rows and creates or updates BC customer links according to mapping and auto-create settings. Exports mapped BC company changes when enabled. Commits once before the isolated run; explicit connector commits are ignored inside it so a failure rolls back local writes. Completed Shopify API requests cannot be rolled back. The connector also stamps its company synchronization time.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'SHOPIFY Full ori');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    /// <summary>Supplies GetRelated for Shopify.Company.Sync.</summary>
    /// <param name="Related">Receives the contract chapter.</param>
    /// <returns>The declared value or whether the chapter is supplied.</returns>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ReadLbl: Label 'Read shops in table 30102 and synchronized companies in table 30150.', Comment = 'is-IS=Lestu verslanir í töflu 30102 og samstillt fyrirtæki í töflu 30150.';
    begin
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', ReadLbl));
        exit(true);
    end;

    /// <summary>Supplies GetExamples for Shopify.Company.Sync.</summary>
    /// <param name="Examples">Receives the contract chapter.</param>
    /// <returns>The declared value or whether the chapter is supplied.</returns>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Synchronize companies for one shop',
            '{"type":"Shopify.Company.Sync","data":{"shopCode":"WEBSHOP"}}',
            '{"status":"Success","shopCode":"WEBSHOP","companyImportFromShopify":"AllCompanies","canUpdateShopifyCompanies":true,"companiesBefore":0,"companiesAfter":2}'));
        exit(true);
    end;

    /// <summary>Supplies GetOverview for Shopify.Company.Sync.</summary>
    /// <param name="Overview">Receives the contract chapter.</param>
    /// <returns>The declared value or whether the chapter is supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Imports and updates Shopify B2B companies and their BC customer links for one enabled shop through Shpfy Sync Companies (30285), the code behind report 30114. The connector owns mapping and customer creation; this adapter does not send GraphQL or change shop settings.';
        exit(true);
    end;

    /// <summary>Supplies GetNotes for Shopify.Company.Sync.</summary>
    /// <param name="Notes">Receives the contract chapter.</param>
    /// <returns>The declared value or whether the chapter is supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Company Import From Shopify = AllCompanies imports companies; WithOrderImport imports updates only when Shopify Can Update Companies is enabled. Can Update Shopify Companies enables export. Both directions can be off: company counts stay unchanged, although the connector stamps its sync time. Counts are local company rows for the selected shop. Repeating the operation updates mapped companies rather than creating duplicates; synchronization time changes each run. No Shopify plan gate is added. Connector codeunit 30285 is internal and invoked by object ID, verified against Connector 28.0. Its explicit commits are ignored within the rollback runner. A connector error returns BusinessCentralError with its text and rolls back local company, location, customer and link writes. Completed remote Shopify operations cannot be rolled back. The public connector can skip records without raising an error; Success means the run returned without an error, not that every remote company was changed. Unknown request keys receive Foundation standard UnknownParameter before execution.';
        exit(true);
    end;

    /// <summary>Supplies GetMessageDirection for Shopify.Company.Sync.</summary>
    /// <returns>The declared value or whether the chapter is supplied.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Validates the request and runs the connector within a local transaction.</summary>
    /// <param name="Argument">Licensed dispatcher request and response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Shop: Record "Shpfy Shop";
        Company: Record "Shpfy Company";
        Runner: Codeunit "Company Sync Run ori";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        ShopCode: Text;
        ImportSetting: Text;
        ExportSetting: Boolean;
        CompaniesBefore: Integer;
        PermissionErr: Label 'You do not have permission to synchronize Shopify companies.', Comment = 'is-IS=Þú hefur ekki heimild til að samstilla Shopify fyrirtæki.';
        PermissionNextLbl: Label 'Ask an administrator for SHOPIFY Full ori and Microsoft Shopify and customer write permissions.', Comment = 'is-IS=Biddu kerfisstjóra um SHOPIFY Full ori og Shopify og viðskiptamannaheimildir Microsoft til skrifa.';
        MissingErr: Label 'Parameter "shopCode" is required.', Comment = 'is-IS=Færibreytan "shopCode" er nauðsynleg.';
        InvalidErr: Label 'Parameter "shopCode" must be a non-empty JSON string of at most 20 characters.', Comment = 'is-IS=Færibreytan "shopCode" verður að vera JSON texti sem er ekki tómur, að hámarki 20 stafir.';
        InputNextLbl: Label 'Send data.shopCode with the code of an enabled Shopify shop.', Comment = 'is-IS=Sendu data.shopCode með kóða virkrar Shopify verslunar.';
        NotFoundErr: Label 'Shopify shop %1 was not found.', Comment = 'is-IS=Shopify verslun %1 fannst ekki.';
        FindNextLbl: Label 'Read table 30102 with Data.Records.Get to find the shop code.', Comment = 'is-IS=Lestu töflu 30102 með Data.Records.Get til að finna verslunarkóðann.';
        DisabledErr: Label 'Shop %1 is not enabled.', Comment = 'is-IS=Verslun %1 er ekki virk.';
        EnableNextLbl: Label 'Enable the shop on the Shopify Shop Card.', Comment = 'is-IS=Virkjaðu verslunina á Shopify Shop Card.';
        ConnectorErr: Label 'Cannot synchronize companies for shop %1. %2', Comment = 'is-IS=Ekki er hægt að samstilla fyrirtæki fyrir verslun %1. %2';
        RetryNextLbl: Label 'Fix the connector error and retry; completed Shopify requests cannot be rolled back.', Comment = 'is-IS=Lagaðu villu tengilsins og reyndu aftur; ekki er hægt að afturkalla loknar Shopify beiðnir.';
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if not IsEnabled() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionErr, '', '', '', PermissionNextLbl);
            exit;
        end;
        Request := Argument.GetRequestJson();
        if not Request.Get('shopCode', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, 'shopCode', '', '', InputNextLbl);
            exit;
        end;
        if not Token.IsValue() then begin
            InvalidShopCode(Argument, InvalidErr, InputNextLbl);
            exit;
        end;
        if Token.AsValue().IsNull() then begin
            InvalidShopCode(Argument, InvalidErr, InputNextLbl);
            exit;
        end;
        Token.WriteTo(ShopCode);
        if not ShopCode.StartsWith('"') then begin
            InvalidShopCode(Argument, InvalidErr, InputNextLbl);
            exit;
        end;
        ShopCode := Token.AsValue().AsText();
        if (ShopCode.Trim() = '') or (StrLen(ShopCode) > MaxStrLen(Shop.Code)) then begin
            InvalidShopCode(Argument, InvalidErr, InputNextLbl);
            exit;
        end;
        Shop.SetLoadFields(Code, Enabled, "Company Import From Shopify", "Can Update Shopify Companies");
        if not Shop.Get(CopyStr(ShopCode, 1, MaxStrLen(Shop.Code))) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, ShopCode), 'shopCode', ShopCode, '', FindNextLbl);
            exit;
        end;
        if not Shop.Enabled then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(DisabledErr, Shop.Code), 'shopCode', ShopCode, '', EnableNextLbl);
            exit;
        end;
        ImportSetting := Shop."Company Import From Shopify".Names().Get(Shop."Company Import From Shopify".Ordinals().IndexOf(Shop."Company Import From Shopify".AsInteger()));
        ExportSetting := Shop."Can Update Shopify Companies";
        Company.SetRange("Shop Code", Shop.Code);
        CompaniesBefore := Company.Count();
        Runner.SetShopCode(Shop.Code);
        Commit();
        ClearLastError();
        if not Runner.Run() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, StrSubstNo(ConnectorErr, Shop.Code, GetLastErrorText()), 'shopCode', ShopCode, '', RetryNextLbl);
            exit;
        end;
        Response.Add('status', 'Success');
        Response.Add('shopCode', Shop.Code);
        Response.Add('companyImportFromShopify', ImportSetting);
        Response.Add('canUpdateShopifyCompanies', ExportSetting);
        Response.Add('companiesBefore', CompaniesBefore);
        Response.Add('companiesAfter', Company.Count());
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure InvalidShopCode(var Argument: Record "Message Argument ori"; ErrorText: Text; NextStep: Text)
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, ErrorText, 'shopCode', '', '', NextStep);
    end;
}
