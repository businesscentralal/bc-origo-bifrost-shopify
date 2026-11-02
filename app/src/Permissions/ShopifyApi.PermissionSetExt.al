namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

/// <summary>Makes the adapter callable from Foundation API roles without granting Microsoft business-data writes.</summary>
permissionsetextension 70013400 "Shopify API ori" extends "BIFROST API ori"
{
    IncludedPermissionSets = "SHOPIFY Full ori";
}