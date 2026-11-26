namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using Origo.Bifrost;

/// <summary>Synchronizes one Shopify owner's metafield definitions or values using the public connector API.</summary>
codeunit 73732060 "Metafield Sync Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Reports whether the caller holds the table permissions this message type needs.</summary>
    /// <returns>True when the permissions are held.</returns>
    procedure IsEnabled(): Boolean
    var
        Metafield: Record "Shpfy Metafield";
    begin
        exit(Metafield.WritePermission());
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
        DescriptionLbl: Label 'Loads metafield definitions from Shopify or sends one owner''s changed metafield values to Shopify.', Comment = 'is-IS=Sækir skilgreiningar viðbótarreita úr Shopify eða sendir breytt gildi viðbótarreita eins eiganda til Shopify.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search terms users say for this type, English with the Icelandic translation.</summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'shopify metafields, load metafield definitions, send metafield values, sync custom fields', Comment = 'is-IS=shopify viðbótarreitir, sækja skilgreiningar viðbótarreita, senda gildi viðbótarreita, samstilla sérreiti';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Use for one product, variant, customer or company. GetDefinitions writes definitions in BC; SendValues writes changed values in Shopify. Edit values separately with Data.Records.Set.', Comment = 'is-IS=Notað fyrir eina vöru, afbrigði, viðskiptavin eða fyrirtæki. GetDefinitions skráir skilgreiningar í BC; SendValues skráir breytt gildi í Shopify. Breyttu gildum sérstaklega með Data.Records.Set.';
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
        Target.Add(ContractMgt.TargetEntry('Shpfy Metafield', 'data.ownerId', 'One owner in the enabled shop, identified by ownerType and Shopify ID.'));
        exit(true);
    end;

    /// <summary>Declares accepted request parameters.</summary>
    /// <param name="Parameters">Receives the parameter declarations.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('shopCode', 'string', true, 'Enabled Shopify shop code, 1 to 20 characters.'));
        Parameters.Add(ContractMgt.Parameter('direction', 'string', true, 'GetDefinitions or SendValues (case sensitive).'));
        Parameters.Add(ContractMgt.Parameter('ownerType', 'string', true, 'Product, Variant, Customer or Company (case sensitive).'));
        Parameters.Add(ContractMgt.Parameter('ownerId', 'integer', true, 'Positive Shopify owner ID belonging to this shop.'));
        Parameters.Add(ContractMgt.Parameter('expectedCount', 'integer', false, 'Required for SendValues: exact nonnegative count of ALL local metafield rows of this owner.'));
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
        Fields.Add(ContractMgt.ResponseField('shopCode', 'string', 'The shop code.'));
        Fields.Add(ContractMgt.ResponseField('direction', 'string', 'GetDefinitions or SendValues.'));
        Fields.Add(ContractMgt.ResponseField('ownerType', 'string', 'Product, Variant, Customer or Company.'));
        Fields.Add(ContractMgt.ResponseField('ownerId', 'integer', 'Shopify owner ID.'));
        Fields.Add(ContractMgt.ResponseField('metafieldsBefore', 'integer', 'Local owner row count before the run, including unsent rows.'));
        Fields.Add(ContractMgt.ResponseField('metafieldsAfter', 'integer', 'Local owner row count after the run; this is not a sent count.'));
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
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A required parameter is missing.', 'No connector call.', 'Supply the documented required keys.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'An unknown parameter was supplied.', 'Foundation rejects undeclared keys before dispatch.', 'Remove unknown keys.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'Invalid or unknown parameter.', 'No connector call.', 'Use the documented keys and JSON types.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'Shop or owner not found in this shop.', 'No connector call.', 'Read the shop and owner with Data.Records.Get.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Shop disabled or expectedCount mismatch.', 'No connector call.', 'Enable the shop or refresh the local row count.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Write permission required.', 'No connector call.', 'Ask for SHOPIFY Full ori and Microsoft Shopify permissions.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Connector refused the operation.', 'Local runner writes roll back; Shopify requests cannot be rolled back.', 'Correct the reported cause before retrying.'));
        exit(true);
    end;

    /// <summary>Supplies the effect chapter for this message type.</summary>
    /// <param name="Effect">Out: effect, changes, idempotency and preconditions.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'GetDefinitions loads definitions into BC. SendValues sends changed values through Shpfy Metafields (30418). Local runner writes roll back on error; completed Shopify requests cannot be rolled back.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'SHOPIFY Full ori');
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
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', 'Read shops, owners and metafield rows.'));
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Set', 'Edit metafield values before sending them.'));
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
        Examples.Add(ContractMgt.Example('Load product definitions',
            '{"type":"Shopify.Metafield.Sync","data":{"shopCode":"WEBSHOP","direction":"GetDefinitions","ownerType":"Product","ownerId":123}}',
            '{"status":"Success","shopCode":"WEBSHOP","direction":"GetDefinitions","ownerType":"Product","ownerId":123,"metafieldsBefore":0,"metafieldsAfter":2}'));
        Examples.Add(ContractMgt.Example('Send customer values',
            '{"type":"Shopify.Metafield.Sync","data":{"shopCode":"WEBSHOP","direction":"SendValues","ownerType":"Customer","ownerId":456,"expectedCount":2}}',
            '{"status":"Success","shopCode":"WEBSHOP","direction":"SendValues","ownerType":"Customer","ownerId":456,"metafieldsBefore":2,"metafieldsAfter":2}'));
        exit(true);
    end;

    /// <summary>Summarizes the operation.</summary>
    /// <param name="Overview">Out: the overview.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'GetDefinitions loads metafield definitions for one Product (30127), Variant (30129), Customer (30105) or Company (30150). SendValues sends that owner''s changed values using the public Shpfy Metafields API (30418). Both directions require write permission.';
        exit(true);
    end;

    /// <summary>Explains the rules and limits of the operation.</summary>
    /// <param name="Notes">Out: the notes.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Both directions are idempotent for unchanged definitions or values. SendValues requires expectedCount to match ALL local metafield rows for the owner. Counts are local rows, not a sent count. Connector 28 excludes legacy string/integer types and empty values from bulk sending, and sends up to 25 values per request. Money values must use the shop currency. Definitions are limited to the connector''s supported types and first 50 definitions. A local error rolls back the runner; completed remote requests cannot be rolled back. No values or definitions are deleted by this message type. Editing values uses Data.Records.Set. Permissions: SHOPIFY Full ori and Microsoft Shopify permissions.';
        exit(true);
    end;

    /// <summary>Classifies the message direction for Foundation.</summary>
    /// <returns>The direction of the operation.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;
    /// <summary>Validates the entire request before invoking the connector transaction.</summary>
    /// <param name="Argument">Licensed request and response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Shop: Record "Shpfy Shop";
        Metafield: Record "Shpfy Metafield";
        Runner: Codeunit "Metafield Sync Run ori";
        Request: JsonObject;
        Response: JsonObject;
        ShopText: Text;
        Direction: Text;
        OwnerType: Text;
        KeyName: Text;
        OwnerId: BigInteger;
        ExpectedCount: BigInteger;
        ParentTableNo: Integer;
        BeforeCount: Integer;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if not IsEnabled() then begin
            Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, PermissionErr, '');
            exit;
        end;
        Request := Argument.GetRequestJson();
        foreach KeyName in Request.Keys() do
            if not (KeyName in ['shopCode', 'direction', 'ownerType', 'ownerId', 'expectedCount']) then begin
                Refuse(Argument, "Bifrost Error Code ori"::UnknownParameter, StrSubstNo(UnknownErr, KeyName), KeyName);
                exit;
            end;
        if not ReadText(Argument, Request, 'shopCode', ShopText) then
            exit;
        if (StrLen(ShopText) > MaxStrLen(Shop.Code)) then begin
            Invalid(Argument, 'shopCode');
            exit;
        end;
        if not ReadText(Argument, Request, 'direction', Direction) then
            exit;
        if not (Direction in ['GetDefinitions', 'SendValues']) then begin
            Invalid(Argument, 'direction');
            exit;
        end;
        if not ReadText(Argument, Request, 'ownerType', OwnerType) then
            exit;
        case OwnerType of
            'Product':
                ParentTableNo := Database::"Shpfy Product";
            'Variant':
                ParentTableNo := Database::"Shpfy Variant";
            'Customer':
                ParentTableNo := Database::"Shpfy Customer";
            'Company':
                ParentTableNo := Database::"Shpfy Company";
            else begin
                Invalid(Argument, 'ownerType');
                exit;
            end;
        end;
        if not ReadInteger(Argument, Request, 'ownerId', 1, OwnerId) then
            exit;
        if (Direction = 'SendValues') or Request.Contains('expectedCount') then
            if not ReadInteger(Argument, Request, 'expectedCount', 0, ExpectedCount) then
                exit;
        Shop.SetLoadFields(Code, Enabled, "Shop Id");
        if not Shop.Get(CopyStr(ShopText, 1, MaxStrLen(Shop.Code))) then begin
            Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, ShopMissingErr, 'shopCode');
            exit;
        end;
        if not Shop.Enabled then begin
            Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, DisabledErr, 'shopCode');
            exit;
        end;
        if not OwnerExists(ParentTableNo, OwnerId, Shop) then begin
            Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, OwnerMissingErr, 'ownerId');
            exit;
        end;
        Metafield.SetRange("Parent Table No.", ParentTableNo);
        Metafield.SetRange("Owner Id", OwnerId);
        BeforeCount := Metafield.Count();
        if (Direction = 'SendValues') and (ExpectedCount <> BeforeCount) then begin
            Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, CountErr, 'expectedCount');
            exit;
        end;
        Runner.SetRequest(ParentTableNo, OwnerId, Shop.Code, Direction);
        // Boolean Codeunit.Run starts the connector rollback boundary after request validation.
        Commit();
        ClearLastError();
        if not Runner.Run() then begin
            Refuse(Argument, "Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), 'ownerId');
            exit;
        end;
        Response.Add('status', 'Success');
        Response.Add('shopCode', Shop.Code);
        Response.Add('direction', Direction);
        Response.Add('ownerType', OwnerType);
        Response.Add('ownerId', OwnerId);
        Response.Add('metafieldsBefore', BeforeCount);
        Response.Add('metafieldsAfter', Metafield.Count());
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure OwnerExists(ParentTableNo: Integer; OwnerId: BigInteger; Shop: Record "Shpfy Shop"): Boolean
    var
        Product: Record "Shpfy Product";
        Variant: Record "Shpfy Variant";
        Customer: Record "Shpfy Customer";
        Company: Record "Shpfy Company";
    begin
        case ParentTableNo of
            Database::"Shpfy Product":
                begin
                    Product.SetLoadFields("Shop Code");
                    if Product.Get(OwnerId) then
                        exit(Product."Shop Code" = Shop.Code);
                end;
            Database::"Shpfy Variant":
                begin
                    Variant.SetLoadFields("Shop Code", "Product Id");
                    if Variant.Get(OwnerId) then begin
                        Product.SetLoadFields("Shop Code");
                        if Product.Get(Variant."Product Id") then
                            exit((Product."Shop Code" = Shop.Code) and (Variant."Shop Code" = Shop.Code));
                    end;
                end;
            Database::"Shpfy Customer":
                begin
                    Customer.SetLoadFields("Shop Id");
                    if Customer.Get(OwnerId) then
                        exit(Customer."Shop Id" = Shop."Shop Id");
                end;
            Database::"Shpfy Company":
                begin
                    Company.SetLoadFields("Shop Id", "Shop Code");
                    if Company.Get(OwnerId) then
                        exit((Company."Shop Id" = Shop."Shop Id") and (Company."Shop Code" = Shop.Code));
                end;
        end;
        exit(false);
    end;

    local procedure ReadText(var Argument: Record "Message Argument ori"; Request: JsonObject; KeyName: Text; var Value: Text): Boolean
    var
        Token: JsonToken;
        Serialized: Text;
    begin
        if not Request.Get(KeyName, Token) then begin
            Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingErr, KeyName), KeyName);
            exit(false);
        end;
        Token.WriteTo(Serialized);
        if not Token.IsValue() or (CopyStr(Serialized, 1, 1) <> '"') then begin
            Invalid(Argument, KeyName);
            exit(false);
        end;
        Value := Token.AsValue().AsText();
        if Value.Trim() = '' then begin
            Invalid(Argument, KeyName);
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadInteger(var Argument: Record "Message Argument ori"; Request: JsonObject; KeyName: Text; Minimum: Integer; var Value: BigInteger): Boolean
    var
        Token: JsonToken;
        Serialized: Text;
    begin
        if not Request.Get(KeyName, Token) then begin
            Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingErr, KeyName), KeyName);
            exit(false);
        end;
        Token.WriteTo(Serialized);
        if (DelChr(Serialized, '=', '0123456789') <> '') or not Evaluate(Value, Serialized, 9) or (Value < Minimum) then begin
            Invalid(Argument, KeyName);
            exit(false);
        end;
        exit(true);
    end;

    local procedure Invalid(var Argument: Record "Message Argument ori"; KeyName: Text)
    begin
        Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidErr, KeyName), KeyName);
    end;

    local procedure Refuse(var Argument: Record "Message Argument ori"; ErrorCode: Enum "Bifrost Error Code ori"; Message: Text; KeyName: Text)
    begin
        Argument.RespondWithError(ErrorCode, Message, KeyName, '', ExpectedLbl, NextLbl);
    end;

    var
        PermissionErr: Label 'You do not have permission to synchronize Shopify metafields.', Comment = 'is-IS=Þú hefur ekki heimild til að samstilla viðbótarreiti Shopify.';
        MissingErr: Label 'Parameter "%1" is required.', Comment = '%1 = parameter name||is-IS=Færibreytan "%1" er nauðsynleg.';
        InvalidErr: Label 'Parameter "%1" has an invalid value or JSON type.', Comment = '%1 = parameter name||is-IS=Færibreytan "%1" hefur ógilt gildi eða JSON gerð.';
        UnknownErr: Label 'Parameter "%1" is not supported.', Comment = '%1 = parameter name||is-IS=Færibreytan "%1" er ekki studd.';
        ShopMissingErr: Label 'The Shopify shop was not found.', Comment = 'is-IS=Shopify verslunin fannst ekki.';
        OwnerMissingErr: Label 'The Shopify owner was not found in this shop.', Comment = 'is-IS=Shopify eigandinn fannst ekki í þessari verslun.';
        DisabledErr: Label 'The Shopify shop is disabled.', Comment = 'is-IS=Shopify verslunin er óvirk.';
        CountErr: Label 'expectedCount does not match the owner''s local metafield row count.', Comment = 'is-IS=expectedCount samsvarar ekki fjölda staðbundinna viðbótarreita eigandans.';
        ExpectedLbl: Label 'An enabled shop, an existing owner, documented parameter types and SHOPIFY Full ori permission.', Comment = 'is-IS=Virk verslun, fyrirliggjandi eigandi, skráðar gerðir færibreyta og heimildin SHOPIFY Full ori.';
        NextLbl: Label 'Check the parameter and connector error, read the shop and owner with Data.Records.Get, and ask an administrator for SHOPIFY Full ori if needed.', Comment = 'is-IS=Athugaðu færibreytuna og villu tengilsins, lestu verslun og eiganda með Data.Records.Get og biddu kerfisstjóra um SHOPIFY Full ori ef þörf krefur.';
}
