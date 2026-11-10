namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.Customer;
using Origo.Bifrost;

/// <summary>
/// Implementation of <c>Shopify.Customer.Sync</c>. Imports Shopify customers and updates Shopify customers from Business Central for one
/// shop, as the shop is set up, through the Shopify connector codeunit Shpfy Sync Customers (30123), the code behind the
/// report Shpfy Sync Customers (30100).
/// </summary>
codeunit 70013450 "Customer Sync Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Reports whether the caller holds the table permissions this message type needs.</summary>
    /// <returns>True when the permissions are held.</returns>
    procedure IsEnabled(): Boolean
    var
        Customer: Record Customer;
        Shop: Record "Shpfy Shop";
    begin
        exit(Customer.WritePermission() and Shop.ReadPermission());
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
        DescriptionLbl: Label 'Imports Shopify customers and updates Shopify customers from Business Central for a Shopify shop, as the shop is set up.', Comment = 'is-IS=Flytur inn Shopify viðskiptamenn og uppfærir Shopify viðskiptamenn úr Business Central fyrir Shopify verslun, eins og verslunin er uppsett.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search terms users say for this type, English with the Icelandic translation.</summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'shopify sync customers, import shopify customers, update shopify customers, synchronize webshop customers, shopify customer sync', Comment = 'is-IS=shopify samstilla viðskiptamenn, flytja inn shopify viðskiptamenn, uppfæra shopify viðskiptamenn, samstilla vefverslunarviðskiptamenn, shopify samstilling viðskiptamanna';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Use to synchronize the customers of one Shopify shop in both directions as the shop is set up (import from Shopify and update in Shopify). It does not change the shop setup (use Data.Records.Set on table 30102) and does not read customers (use Data.Records.Get on table 30105 or table 18).', Comment = 'is-IS=Notað til að samstilla viðskiptamenn einnar Shopify verslunar í báðar áttir eins og verslunin er uppsett (inn frá Shopify og uppfærsla í Shopify). Breytir ekki uppsetningu verslunarinnar (notaðu Data.Records.Set á töflu 30102) og les ekki viðskiptamenn (notaðu Data.Records.Get á töflu 30105 eða töflu 18).';
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
        Parameters.Add(ContractMgt.Parameter('shopCode', 'string', true, 'The code of an enabled Shopify shop, e.g. from Data.Records.Get on table 30102. What is imported and updated follows the customer settings of the shop.'));
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
        Fields.Add(ContractMgt.ResponseField('shopCode', 'string', 'The shop that was synchronized.'));
        Fields.Add(ContractMgt.ResponseField('customerImportFromShopify', 'string', 'The shop setting Customer Import From Shopify that applied: None, AllCustomers or WithOrderImport.'));
        Fields.Add(ContractMgt.ResponseField('canUpdateShopifyCustomer', 'boolean', 'The shop setting Can Update Shopify Customer that applied.'));
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
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'Parameter "shopCode" is required.', 'The request has no shopCode. Nothing was changed.', 'Send data.shopCode with the code of the Shopify shop.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'Parameter "shopCode" must be a shop code of at most 20 characters.', 'The value is empty or too long to be a shop code. Nothing was changed.', 'Send the code of the Shopify shop.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'Shopify shop {code} was not found.', 'No shop has this code. Nothing was changed.', 'Read table 30102 with Data.Records.Get to find the shop code.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Shop {code} is not enabled.', 'The shop is not enabled. Nothing was changed.', 'Enable the shop on the Shopify Shop Card.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Can not synchronize customers for shop {code}.', 'Business Central or the Shopify connector refused: for example the shop has no valid connection to Shopify or a customer template or mapping is invalid. The text names the cause. Changes of this call are rolled back.', 'Fix the cause named in the text, for example the Shopify connection of the shop, then call again.'));
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
        Preconditions.Add('When customers are imported or updated, the shop has a working connection to Shopify (access token and URL) and the customer settings the connector needs.');
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Runs codeunit Shpfy Sync Customers (30123) for the shop, the code behind the Sync action. As the shop is set up, it imports Shopify customers into the Shopify customer tables and, as the shop mapping requires, creates or updates the mapped Business Central customers (Customer Import From Shopify), and, when the shop has Can Update Shopify Customer, writes the changes of mapped Business Central customers to the customers in the Shopify store through its API. If the shop neither imports nor updates customers, nothing changes. This call commits (Commit()) once before it starts the Shopify code; the Shopify code itself may also commit while it talks to Shopify, so work done before a failure can stay.');
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
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', 'You need to find the shop, table 30102 Shpfy Shop, or read the synchronized customers, table 30105 Shpfy Customer.'));
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
        Examples.Add(ContractMgt.Example('Synchronize the customers of a Shopify shop',
            '{"type":"Shopify.Customer.Sync","data":{"shopCode":"WEBSHOP"}}',
            '{"status":"Success","shopCode":"WEBSHOP","customerImportFromShopify":"AllCustomers","canUpdateShopifyCustomer":true}'));
        exit(true);
    end;

    /// <summary>Summarizes the operation.</summary>
    /// <param name="Overview">Out: the overview.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Imports Shopify customers and updates Shopify customers from Business Central for one shop, as the shop is set up, by running the Shopify connector codeunit Shpfy Sync Customers (30123), the code behind the Sync action on Shopify Customers and the Shopify Shop Card, so the connector''s own validation and checks run.';
        exit(true);
    end;

    /// <summary>Explains the rules and limits of the operation.</summary>
    /// <param name="Notes">Out: the notes.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'What is imported and updated follows the shop settings Customer Import From Shopify and Can Update Shopify Customer; the request only names the shop. Repeating the call is safe: customers already mapped are matched, not created again. The call contacts Shopify when the shop imports or updates customers. The Shopify codeunit is internal to the connector, so it is started by its object ID; a future connector version that changes it may need an update of this type. Business Central and connector refusals are returned as a refusal; the Shopify code may commit while it talks to Shopify, so partial progress can remain after a failure. Permissions: SHOPIFY Full ori, plus the Microsoft Shopify permissions and the right to create and change customers.';
        exit(true);
    end;

    /// <summary>Classifies the message direction for Foundation.</summary>
    /// <returns>The direction of the operation.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Validates the request and synchronizes the customers through the Shopify connector.</summary>
    /// <param name="Argument">The licensed request; receives the response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Shop: Record "Shpfy Shop";
        SyncRun: Codeunit "Customer Sync Run ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        ShopCodeText: Text;
        NoPermissionErr: Label 'You do not have the permissions to synchronize Shopify customers.', Comment = 'is-IS=Þú hefur ekki heimildir til að samstilla Shopify viðskiptamenn.';
        PermissionExpectedLbl: Label 'a user with the permission set SHOPIFY Full ori and the right to create and change customers', Comment = 'is-IS=notandi með heimildasettið SHOPIFY Full ori og heimild til að búa til og breyta viðskiptamönnum';
        AskAdminLbl: Label 'Ask an administrator to assign the permission set SHOPIFY Full ori.', Comment = 'is-IS=Biddu kerfisstjóra um að úthluta heimildasettinu SHOPIFY Full ori.';
        MissingErr: Label 'Parameter "shopCode" is required.', Comment = 'is-IS=Færibreytan "shopCode" er nauðsynleg.';
        MissingNextLbl: Label 'Send data.shopCode with the code of the Shopify shop.', Comment = 'is-IS=Sendu data.shopCode með kóða Shopify verslunarinnar.';
        ShopCodeExpectedLbl: Label 'the code of an enabled Shopify shop (at most 20 characters)', Comment = 'is-IS=kóði virkrar Shopify verslunar (að hámarki 20 stafir)';
        InvalidErr: Label 'Parameter "shopCode" must be a shop code of at most 20 characters.', Comment = 'is-IS=Færibreytan "shopCode" verður að vera verslunarkóði með í mesta lagi 20 stöfum.';
        InvalidNextLbl: Label 'Send the code of the Shopify shop.', Comment = 'is-IS=Sendu kóða Shopify verslunarinnar.';
        NotFoundErr: Label 'Shopify shop %1 was not found.', Comment = '%1 = Shop code||is-IS=Shopify verslun %1 fannst ekki.';
        ExistingShopExpectedLbl: Label 'the code of an existing Shopify shop', Comment = 'is-IS=kóði núverandi Shopify verslunar';
        FindShopLbl: Label 'Read table 30102 with Data.Records.Get to find the shop code.', Comment = 'is-IS=Lestu töflu 30102 með Data.Records.Get til að finna verslunarkóðann.';
        NotEnabledErr: Label 'Shop %1 is not enabled.', Comment = '%1 = Shop code||is-IS=Verslun %1 er ekki virk.';
        EnabledExpectedLbl: Label 'an enabled shop', Comment = 'is-IS=virk verslun';
        EnableShopLbl: Label 'Enable the shop on the Shopify Shop Card.', Comment = 'is-IS=Virkjaðu verslunina á Shopify Shop Card.';
        SyncedExpectedLbl: Label 'a shop that can synchronize customers with Shopify', Comment = 'is-IS=verslun sem getur samstillt viðskiptamenn við Shopify';
        RefusedErr: Label 'Can not synchronize customers for shop %1. %2', Comment = '%1 = Shop code, %2 = detailed text||is-IS=Ekki er hægt að samstilla viðskiptamenn fyrir verslun %1. %2';
        FixCauseLbl: Label 'Fix the cause named in the text, for example the Shopify connection of the shop, then call again.', Comment = 'is-IS=Lagaðu orsökina sem textinn nefnir, til dæmis tenginguna við Shopify í versluninni, og kallaðu aftur.';
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if not IsEnabled() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, NoPermissionErr, 'shopCode', '', PermissionExpectedLbl, AskAdminLbl);
            exit;
        end;
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('shopCode', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, 'shopCode', '', ShopCodeExpectedLbl, MissingNextLbl);
            exit;
        end;
        ShopCodeText := Argument.TokenAsText(Token);
        if (ShopCodeText = '') or (StrLen(ShopCodeText) > MaxStrLen(Shop.Code)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidErr, 'shopCode', ShopCodeText, ShopCodeExpectedLbl, InvalidNextLbl);
            exit;
        end;
        if not Shop.Get(CopyStr(ShopCodeText, 1, MaxStrLen(Shop.Code))) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, ShopCodeText), 'shopCode', ShopCodeText, ExistingShopExpectedLbl, FindShopLbl);
            exit;
        end;
        if not Shop.Enabled then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NotEnabledErr, Shop.Code), 'shopCode', ShopCodeText, EnabledExpectedLbl, EnableShopLbl);
            exit;
        end;

        // Commit first, as the connector does before its background syncs, so that a failure of the Shopify code in the
        // if statement below rolls back only what that code changed.
        Commit();
        SyncRun.SetShopCode(Shop.Code);
        ClearLastError();
        if not SyncRun.Run() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, StrSubstNo(RefusedErr, Shop.Code, GetLastErrorText()), 'shopCode', ShopCodeText, SyncedExpectedLbl, FixCauseLbl);
            exit;
        end;

        Shop.Get(Shop.Code);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('shopCode', Shop.Code);
        ResponseJson.Add('customerImportFromShopify', ImportRangeName(Shop));
        ResponseJson.Add('canUpdateShopifyCustomer', Shop."Can Update Shopify Customer");
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure ImportRangeName(Shop: Record "Shpfy Shop"): Text
    var
        Names: List of [Text];
        Ordinals: List of [Integer];
    begin
        Names := Shop."Customer Import From Shopify".Names();
        Ordinals := Shop."Customer Import From Shopify".Ordinals();
        exit(Names.Get(Ordinals.IndexOf(Shop."Customer Import From Shopify".AsInteger())));
    end;
}
