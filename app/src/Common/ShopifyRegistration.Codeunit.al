namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

/// <summary>Registers Shopify metadata, including under the restricted licence administrator role.</summary>
codeunit 70013400 "Shopify Registration ori"
{
    Access = Internal;
    InherentPermissions = X;
    InherentEntitlements = X;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"App Registry ori", OnRegisterApps, '', false, false)]
    local procedure RegisterApp(var Apps: Record "Registered App ori" temporary)
    var
        Registry: Codeunit "App Registry ori";
        AppInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(AppInfo);
        Registry.AddApp(Apps, AppInfo.Id(), CopyStr(AppInfo.Name(), 1, 250), 0);
    end;
}