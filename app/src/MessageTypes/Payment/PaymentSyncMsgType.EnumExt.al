namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

enumextension 73732110 "Payment Sync MsgType ori" extends "Message Type ori"
{
    value(73732110; "Shopify.Payment.Sync")
    {
        Caption = 'Shopify.Payment.Sync', Locked = true;
        Implementation = "Msg Interface ori" = "Payment Sync Impl ori", "Msg Discovery ori" = "Payment Sync Impl ori", "Msg Contract ori" = "Payment Sync Impl ori";
    }
}
