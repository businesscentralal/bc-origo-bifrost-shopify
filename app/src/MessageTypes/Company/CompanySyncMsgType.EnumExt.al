namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

/// <summary>Registers the company synchronization write operation.</summary>
enumextension 73732044 "Company Sync MsgType ori" extends "Message Type ori"
{
    /// <summary>Synchronizes Shopify companies according to the selected shop settings.</summary>
    value(73732044; "Shopify.Company.Sync")
    {
        Caption = 'Shopify.Company.Sync', Comment = 'is-IS=Shopify.Company.Sync';
        Implementation = "Msg Interface ori" = "Company Sync Impl ori",
                         "Msg Discovery ori" = "Company Sync Impl ori",
                         "Msg Contract ori" = "Company Sync Impl ori";
    }
}
