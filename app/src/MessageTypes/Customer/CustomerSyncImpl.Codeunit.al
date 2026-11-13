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
        TargetLbl: Label 'The code of an enabled Shopify shop (table 30102).', Comment = 'is-IS=Kóði virkrar Shopify verslunar (tafla 30102).';
    begin
        Target.Add(ContractMgt.TargetEntry('Shpfy Shop', 'data.shopCode', TargetLbl));
        exit(true);
    end;

    /// <summary>Declares accepted request parameters.</summary>
    /// <param name="Parameters">Receives the parameter declarations.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ShopCodeParamLbl: Label 'The code of an enabled Shopify shop, e.g. from Data.Records.Get on table 30102. What is imported and updated follows the customer settings of the shop.', Comment = 'is-IS=Kóði virkrar Shopify verslunar, t.d. úr Data.Records.Get á töflu 30102. Það sem er flutt inn og uppfært ræðst af viðskiptamannastillingum verslunarinnar.';
    begin
        Parameters.Add(ContractMgt.Parameter('shopCode', 'string', true, ShopCodeParamLbl));
        exit(true);
    end;

    /// <summary>Supplies the response chapter for this message type.</summary>
    /// <param name="Response">Out: the response fields.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        StatusLbl: Label 'Success. It is returned only when the connector ran and no Shopify customer is left without a Business Central customer although the shop creates unknown customers.', Comment = 'is-IS=Success. Það er aðeins skilað þegar tengillinn keyrði og enginn Shopify viðskiptamaður er eftir án viðskiptamanns í Business Central þótt verslunin stofni óþekkta viðskiptamenn.';
        ShopLbl: Label 'The shop that was synchronized.', Comment = 'is-IS=Verslunin sem var samstillt.';
        ImportLbl: Label 'The shop setting Customer Import From Shopify that applied: None, AllCustomers or WithOrderImport.', Comment = 'is-IS=Stillingin Customer Import From Shopify í versluninni sem gilti: None, AllCustomers eða WithOrderImport.';
        UpdateLbl: Label 'The shop setting Can Update Shopify Customer that applied.', Comment = 'is-IS=Stillingin Can Update Shopify Customer í versluninni sem gilti.';
    begin
        Fields.Add(ContractMgt.ResponseField('status', 'string', StatusLbl));
        Fields.Add(ContractMgt.ResponseField('shopCode', 'string', ShopLbl));
        Fields.Add(ContractMgt.ResponseField('customerImportFromShopify', 'string', ImportLbl));
        Fields.Add(ContractMgt.ResponseField('canUpdateShopifyCustomer', 'boolean', UpdateLbl));
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
        MissingTextLbl: Label 'Parameter "shopCode" is required.', Comment = 'is-IS=Færibreytan "shopCode" er nauðsynleg.';
        MissingWhenLbl: Label 'The request has no shopCode. Nothing was changed.', Comment = 'is-IS=Beiðnin hefur ekkert shopCode. Engu var breytt.';
        MissingFixLbl: Label 'Send data.shopCode with the code of the Shopify shop.', Comment = 'is-IS=Sendu data.shopCode með kóða Shopify verslunarinnar.';
        InvalidTextLbl: Label 'Parameter "shopCode" must be a shop code of at most 20 characters.', Comment = 'is-IS=Færibreytan "shopCode" verður að vera verslunarkóði með í mesta lagi 20 stöfum.';
        InvalidWhenLbl: Label 'The value is empty or too long to be a shop code. Nothing was changed.', Comment = 'is-IS=Gildið er tómt eða of langt til að vera verslunarkóði. Engu var breytt.';
        InvalidFixLbl: Label 'Send the code of the Shopify shop.', Comment = 'is-IS=Sendu kóða Shopify verslunarinnar.';
        NotFoundTextLbl: Label 'Shopify shop {code} was not found.', Comment = 'is-IS=Shopify verslun {code} fannst ekki.';
        NotFoundWhenLbl: Label 'No shop has this code. Nothing was changed.', Comment = 'is-IS=Engin verslun hefur þennan kóða. Engu var breytt.';
        NotFoundFixLbl: Label 'Read table 30102 with Data.Records.Get to find the shop code.', Comment = 'is-IS=Lestu töflu 30102 með Data.Records.Get til að finna verslunarkóðann.';
        NotEnabledTextLbl: Label 'Shop {code} is not enabled.', Comment = 'is-IS=Verslun {code} er ekki virk.';
        NotEnabledWhenLbl: Label 'The shop is not enabled. Nothing was changed.', Comment = 'is-IS=Verslunin er ekki virk. Engu var breytt.';
        NotEnabledFixLbl: Label 'Enable the shop on the Shopify Shop Card.', Comment = 'is-IS=Virkjaðu verslunina á Shopify Shop Card.';
        RefusedTextLbl: Label 'Can not synchronize customers for shop {code}.', Comment = 'is-IS=Ekki er hægt að samstilla viðskiptamenn fyrir verslun {code}.';
        RefusedWhenLbl: Label 'Business Central or the Shopify connector refused, for example because the shop has no valid connection to Shopify. The text names the cause. The Shopify connector commits while it works, so changes made before the refusal can stay.', Comment = 'is-IS=Business Central eða Shopify tengillinn hafnaði, til dæmis vegna þess að verslunin hefur enga gilda tengingu við Shopify. Textinn nefnir orsökina. Shopify tengillinn framkvæmir Commit á meðan hann vinnur, svo breytingar sem voru gerðar áður en honum var hafnað geta staðið eftir.';
        RefusedFixLbl: Label 'Fix the cause named in the text, for example the Shopify connection of the shop, then call again.', Comment = 'is-IS=Lagaðu orsökina sem textinn nefnir, til dæmis tenginguna við Shopify í versluninni, og kallaðu aftur.';
        UnmappedTextLbl: Label 'Shop {code} was synchronized, but {count} Shopify customers have no Business Central customer.', Comment = 'is-IS=Verslun {code} var samstillt, en {count} Shopify viðskiptamenn eru án viðskiptamanns í Business Central.';
        UnmappedWhenLbl: Label 'The connector ran, but after it at least one Shopify customer of the shop is still not linked to a Business Central customer although the shop has Auto Create Unknown Customers and imports customers. The connector hides the error of a customer it could not import (for example an invalid customer template or mapping), so this check reports the result instead of the cause. The customers imported before stay.', Comment = 'is-IS=Tengillinn keyrði, en eftir hann er að minnsta kosti einn Shopify viðskiptamaður verslunarinnar enn ótengdur viðskiptamanni í Business Central þótt verslunin sé með Auto Create Unknown Customers og flytji inn viðskiptamenn. Tengillinn felur villu viðskiptamanns sem hann gat ekki flutt inn (til dæmis ógilt sniðmát eða varpanir), svo þessi athugun tilkynnir niðurstöðuna en ekki orsökina. Viðskiptamennirnir sem voru fluttir inn áður standa eftir.';
        UnmappedFixLbl: Label 'Check the customer template and the customer mapping of the shop, then call again. Customers already imported are matched, not created again.', Comment = 'is-IS=Athugaðu viðskiptamannasniðmátið og varpanir viðskiptamanna í versluninni og kallaðu aftur. Viðskiptamenn sem þegar eru fluttir inn eru paraðir, ekki stofnaðir aftur.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingTextLbl, MissingWhenLbl, MissingFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, InvalidTextLbl, InvalidWhenLbl, InvalidFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundTextLbl, NotFoundWhenLbl, NotFoundFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, NotEnabledTextLbl, NotEnabledWhenLbl, NotEnabledFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, RefusedTextLbl, RefusedWhenLbl, RefusedFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, UnmappedTextLbl, UnmappedWhenLbl, UnmappedFixLbl));
        exit(true);
    end;

    /// <summary>Supplies the effect chapter for this message type.</summary>
    /// <param name="Effect">Out: effect, changes, idempotency and preconditions.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
        ShopPreLbl: Label 'The shop exists and is enabled.', Comment = 'is-IS=Verslunin er til og er virk.';
        ConnectionPreLbl: Label 'When customers are imported or updated, the shop has a working connection to Shopify (access token and URL) and the customer settings the connector needs.', Comment = 'is-IS=Þegar viðskiptamenn eru fluttir inn eða uppfærðir hefur verslunin virka tengingu við Shopify (aðgangslykill og slóð) og viðskiptamannastillingarnar sem tengillinn þarf.';
        ChangesLbl: Label 'Runs codeunit Shpfy Sync Customers (30123) for the shop, the code behind the Sync action. As the shop is set up, it imports Shopify customers into the Shopify customer tables and, as the shop mapping requires, creates or updates the mapped Business Central customers (Customer Import From Shopify), and, when the shop has Can Update Shopify Customer, writes the changes of mapped Business Central customers to the customers in the Shopify store through its API. If the shop neither imports nor updates customers, nothing changes. This call commits (Commit()) once before it starts the Shopify code, and the Shopify code commits between customers while it works. It is not one transaction: when a customer fails or the call is refused part way, the customers handled before stay, and this call does not roll them back.', Comment = 'is-IS=Keyrir codeunit Shpfy Sync Customers (30123) fyrir verslunina, kóðann á bak við aðgerðina Sync. Eins og verslunin er uppsett flytur hún inn Shopify viðskiptamenn í Shopify viðskiptamannatöflurnar og, eins og varpanir verslunarinnar krefjast, stofnar eða uppfærir tengda viðskiptamenn í Business Central (Customer Import From Shopify) og, þegar verslunin er með Can Update Shopify Customer, skrifar breytingar tengdra viðskiptamanna í Business Central í viðskiptamenn Shopify verslunarinnar í gegnum API hennar. Ef verslunin flytur hvorki inn né uppfærir viðskiptamenn breytist ekkert. Þetta kall framkvæmir Commit() einu sinni áður en Shopify kóðinn byrjar og Shopify kóðinn framkvæmir Commit á milli viðskiptamanna á meðan hann vinnur. Þetta er ekki ein færsla: þegar viðskiptamaður mistekst eða kallinu er hafnað á miðri leið standa viðskiptamennirnir sem voru afgreiddir áður eftir og þetta kall afturkallar þá ekki.';
    begin
        Preconditions.Add(ShopPreLbl);
        Preconditions.Add(ConnectionPreLbl);
        Effect.Add('effect', 'write');
        Effect.Add('changes', ChangesLbl);
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
        RelatedLbl: Label 'You need to find the shop, table 30102 Shpfy Shop, or read the synchronized customers, table 30105 Shpfy Customer.', Comment = 'is-IS=Þú þarft að finna verslunina, töflu 30102 Shpfy Shop, eða lesa samstillta viðskiptamenn, töflu 30105 Shpfy Customer.';
    begin
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', RelatedLbl));
        exit(true);
    end;

    /// <summary>Declares that this implementation supplies no workflow chapter.</summary>
    /// <param name="Workflow">Unchanged.</param>
    /// <returns>False.</returns>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Returns the examples for this message type; the request and answer JSON keeps its stable keys.</summary>
    /// <param name="Examples">Out: request and answer pairs.</param>
    /// <returns>True; examples are supplied.</returns>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ExampleLbl: Label 'Synchronize the customers of a Shopify shop', Comment = 'is-IS=Samstilla viðskiptamenn Shopify verslunar';
    begin
        Examples.Add(ContractMgt.Example(ExampleLbl,
            '{"type":"Shopify.Customer.Sync","data":{"shopCode":"WEBSHOP"}}',
            '{"status":"Success","shopCode":"WEBSHOP","customerImportFromShopify":"AllCustomers","canUpdateShopifyCustomer":true}'));
        exit(true);
    end;

    /// <summary>Summarizes the operation.</summary>
    /// <param name="Overview">Out: the overview.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Imports Shopify customers and updates Shopify customers from Business Central for one shop, as the shop is set up, by running the Shopify connector codeunit Shpfy Sync Customers (30123), the code behind the Sync action on Shopify Customers and the Shopify Shop Card, so the connector''s own validation and checks run.', Comment = 'is-IS=Flytur inn Shopify viðskiptamenn og uppfærir Shopify viðskiptamenn úr Business Central fyrir eina verslun, eins og verslunin er uppsett, með því að keyra codeunit Shpfy Sync Customers (30123) í Shopify tenglinum, kóðann á bak við aðgerðina Sync á Shopify Customers og Shopify Shop Card, svo eigin sannprófanir og athuganir tengilsins keyra.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Explains the rules and limits of the operation.</summary>
    /// <param name="Notes">Out: the notes.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'What is imported and updated follows the shop settings Customer Import From Shopify and Can Update Shopify Customer; the request only names the shop. Repeating the call is safe: customers already mapped are matched, not created again. The call contacts Shopify when the shop imports or updates customers. The Shopify codeunit is internal to the connector, so it is started by its object ID; a future connector version that changes it may need an update of this type. The connector commits between customers and does not report the error of a customer it could not import, so this type checks the result: when the shop has Auto Create Unknown Customers and imports customers and a Shopify customer of the shop is still without a Business Central customer afterwards, the answer is an error, not Success. Customers handled before stay. Business Central and connector refusals are returned as a refusal. Permissions: SHOPIFY Full ori, plus the Microsoft Shopify permissions and the right to create and change customers.', Comment = 'is-IS=Það sem er flutt inn og uppfært ræðst af verslunarstillingunum Customer Import From Shopify og Can Update Shopify Customer; beiðnin nefnir aðeins verslunina. Það er óhætt að endurtaka kallið: viðskiptamenn sem þegar eru tengdir eru paraðir, ekki stofnaðir aftur. Kallið hefur samband við Shopify þegar verslunin flytur inn eða uppfærir viðskiptamenn. Shopify codeunit er innri í tenglinum og er því ræst með hlutarnúmeri sínu; framtíðarútgáfa tengilsins sem breytir henni gæti þurft uppfærslu á þessari tegund. Tengillinn framkvæmir Commit á milli viðskiptamanna og skilar ekki villu viðskiptamanns sem hann gat ekki flutt inn, svo þessi tegund athugar niðurstöðuna: þegar verslunin er með Auto Create Unknown Customers og flytur inn viðskiptamenn og Shopify viðskiptamaður verslunarinnar er eftir það enn án viðskiptamanns í Business Central er svarið villa, ekki Success. Viðskiptamenn sem voru afgreiddir áður standa eftir. Business Central og tengillinn geta hafnað og þá er skilað synjun. Heimildir: SHOPIFY Full ori, ásamt Microsoft Shopify heimildum og heimild til að stofna og breyta viðskiptamönnum.';
    begin
        Notes := NotesLbl;
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
        UnmappedErr: Label 'Shop %1 was synchronized, but %2 Shopify customers have no Business Central customer. The connector does not report why; check the customer template and the customer mapping of the shop.', Comment = '%1 = Shop code, %2 = number of customers||is-IS=Verslun %1 var samstillt, en %2 Shopify viðskiptamenn eru án viðskiptamanns í Business Central. Tengillinn tilkynnir ekki hvers vegna; athugaðu viðskiptamannasniðmátið og varpanir viðskiptamanna í versluninni.';
        UnmappedExpectedLbl: Label 'a shop whose Shopify customers all got a Business Central customer', Comment = 'is-IS=verslun þar sem allir Shopify viðskiptamenn fengu viðskiptamann í Business Central';
        UnmappedCount: Integer;
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
        // The connector hides the error of a customer it could not import, so judge the result: a Shopify customer without a
        // Business Central customer although the shop creates unknown customers means the import failed for it.
        UnmappedCount := CountUnmappedImports(Shop);
        if UnmappedCount > 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, StrSubstNo(UnmappedErr, Shop.Code, UnmappedCount), 'shopCode', ShopCodeText, UnmappedExpectedLbl, FixCauseLbl);
            exit;
        end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('shopCode', Shop.Code);
        ResponseJson.Add('customerImportFromShopify', ImportRangeName(Shop));
        ResponseJson.Add('canUpdateShopifyCustomer', Shop."Can Update Shopify Customer");
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    /// <summary>
    /// Counts the Shopify customers of the shop that are still without a Business Central customer although the shop imports
    /// customers and creates unknown customers. The connector codeunit Shpfy Sync Customers catches the error of a customer it
    /// could not import and raises nothing, so this is how a failed import of a customer becomes visible.
    /// </summary>
    /// <param name="Shop">The synchronized shop.</param>
    /// <returns>The number of customers that should have been created and were not; 0 when the shop does not create customers.</returns>
    internal procedure CountUnmappedImports(Shop: Record "Shpfy Shop"): Integer
    var
        ShopifyCustomer: Record "Shpfy Customer";
        NoCustomer: Guid;
    begin
        if (Shop."Customer Import From Shopify" = Shop."Customer Import From Shopify"::None) or not Shop."Auto Create Unknown Customers" then
            exit(0);
        ShopifyCustomer.SetRange("Shop Id", Shop."Shop Id");
        ShopifyCustomer.SetRange("Customer SystemId", NoCustomer);
        exit(ShopifyCustomer.Count());
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
