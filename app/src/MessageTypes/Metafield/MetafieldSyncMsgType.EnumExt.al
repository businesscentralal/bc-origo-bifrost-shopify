namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

/// <summary>Registers the Shopify metafield write operation.</summary>
enumextension 73732060 "Metafield Sync MsgType ori" extends "Message Type ori"
{
    value(73732060; "Shopify.Metafield.Sync")
    {
        Caption = 'Shopify.Metafield.Sync', Locked = true;
        Implementation = "Msg Interface ori" = "Metafield Sync Impl ori", "Msg Discovery ori" = "Metafield Sync Impl ori", "Msg Contract ori" = "Metafield Sync Impl ori";
    }
}
