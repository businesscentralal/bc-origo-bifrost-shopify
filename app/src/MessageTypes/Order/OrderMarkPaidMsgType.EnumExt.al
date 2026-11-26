namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

/// <summary>Registers the confirmed Shopify payment write.</summary>
enumextension 73732090 "Order MarkPaid MsgType ori" extends "Message Type ori"
{
    value(73732090; "Shopify.Order.MarkAsPaid")
    {
        Caption = 'Shopify.Order.MarkAsPaid', Locked = true;
        Implementation = "Msg Interface ori" = "Order MarkPaid Impl ori", "Msg Discovery ori" = "Order MarkPaid Impl ori", "Msg Contract ori" = "Order MarkPaid Impl ori";
    }
}
