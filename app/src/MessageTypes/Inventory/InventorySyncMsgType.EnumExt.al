namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

enumextension 73732030 "Inventory Sync MsgType ori" extends "Message Type ori"
{
    value(73732030; "Shopify.Inventory.Sync")
    {
        Caption = 'Shopify.Inventory.Sync', Locked = true;
        Implementation = "Msg Interface ori" = "Inventory Sync Impl ori", "Msg Discovery ori" = "Inventory Sync Impl ori", "Msg Contract ori" = "Inventory Sync Impl ori";
    }
}
