namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Origo.Bifrost.Shopify;

/// <summary>Automatic mock restricted to the token-free company MCP fixture shops.</summary>
codeunit 97515 "Shopify Company MCP Stub ori"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Company Sync Run ori", 'OnBeforeRunConnector', '', false, false)]
    local procedure RunConnectorMock(Shop: Record "Shpfy Shop"; var Handled: Boolean)
    var
        Company: Record "Shpfy Company";
    begin
        if not (Shop.Code in ['XMCPC18', 'XMCPC18FAIL', 'XMCPC18OFF']) then
            exit;
        Handled := true;
        if Shop."Company Import From Shopify" = Shop."Company Import From Shopify"::AllCompanies then
            if not Company.Get(975160018) then begin
                Company.Init();
                Company.Id := 975160018;
                Company."Shop Code" := Shop.Code;
                Company.Name := 'XCompany MCP fixture';
                Company.Insert();
            end;
        if Shop.Code = 'XMCPC18FAIL' then begin
            Company.Init();
            Company.Id := 975160019;
            Company."Shop Code" := Shop.Code;
            Company.Insert();
            Commit();
            Error('XCompany MCP connector failure');
        end;
    end;
}
