namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

enumextension 73731980 "Fulfillment Sync MsgType ori" extends "Message Type ori"
{
    value(73731980; "Shopify.Fulfillment.Sync")
    {
        Caption = 'Shopify.Fulfillment.Sync', Locked = true;
        Implementation = "Msg Interface ori" = "Fulfillment Sync Impl ori", "Msg Discovery ori" = "Fulfillment Sync Impl ori", "Msg Contract ori" = "Fulfillment Sync Impl ori";
    }
}
