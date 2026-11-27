namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

/// <summary>Registers the confirmed local order overwrite operation.</summary>
enumextension 73731951 "Order ForceSync MsgType ori" extends "Message Type ori"
{
    /// <summary>Re-imports a known order without writing to Shopify.</summary>
    value(73731951; "Shopify.Order.ForceSync")
    {
        Caption = 'Shopify.Order.ForceSync', Locked = true;
        Implementation = "Msg Interface ori" = "Order ForceSync Impl ori", "Msg Discovery ori" = "Order ForceSync Impl ori", "Msg Contract ori" = "Order ForceSync Impl ori";
    }
}
