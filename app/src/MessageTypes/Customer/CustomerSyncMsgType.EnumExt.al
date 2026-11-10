namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

enumextension 70013450 "Customer Sync MsgType ori" extends "Message Type ori"
{
    value(70013450; "Shopify.Customer.Sync")
    {
        Caption = 'Shopify.Customer.Sync', Locked = true;
        Implementation = "Msg Interface ori" = "Customer Sync Impl ori", "Msg Discovery ori" = "Customer Sync Impl ori", "Msg Contract ori" = "Customer Sync Impl ori";
    }
}
