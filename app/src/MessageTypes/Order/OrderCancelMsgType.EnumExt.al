namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

/// <summary>Registers the explicitly confirmed Shopify order cancellation operation.</summary>
enumextension 73732042 "Order Cancel MsgType ori" extends "Message Type ori"
{
    /// <summary>Cancels one imported order in Shopify with explicit side-effect choices.</summary>
    value(73732042; "Shopify.Order.Cancel")
    {
        Caption = 'Shopify.Order.Cancel', Locked = true;
        Implementation = "Msg Interface ori" = "Order Cancel Impl ori", "Msg Discovery ori" = "Order Cancel Impl ori", "Msg Contract ori" = "Order Cancel Impl ori";
    }
}
