namespace Origo.Bifrost.Shopify;

/// <summary>Grants Execute on this adapter; Microsoft Shopify permissions are assigned separately.</summary>
permissionset 70013400 "SHOPIFY Base ori"
{
    Assignable = false;
    Caption = 'Bifrost Shopify Base', Comment = 'is-IS=Bifröst Shopify grunnur';
    Permissions = codeunit "Shopify Registration ori" = X;
}