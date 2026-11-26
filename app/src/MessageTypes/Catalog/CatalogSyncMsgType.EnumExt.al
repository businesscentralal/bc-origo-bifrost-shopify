namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

/// <summary>Registers catalog import as a write operation.</summary>
enumextension 73732080 "Catalog Sync MsgType ori" extends "Message Type ori"
{
    /// <summary>Imports company and market catalogs for one shop.</summary>
    value(73732080; "Shopify.Catalog.Sync")
    {
        Caption = 'Shopify.Catalog.Sync', Locked = true;
        Implementation = "Msg Interface ori" = "Catalog Sync Impl ori", "Msg Discovery ori" = "Catalog Sync Impl ori", "Msg Contract ori" = "Catalog Sync Impl ori";
    }
}
