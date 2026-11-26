namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

/// <summary>Registers the dispute import write operation.</summary>
enumextension 73732046 "Payment Disputes MsgType ori" extends "Message Type ori"
{
    /// <summary>Imports and refreshes Shopify Payments disputes.</summary>
    value(73732046; "Shopify.Payment.SyncDisputes")
    {
        Caption = 'Sync Shopify payment disputes', Comment = 'is-IS=Samstilla Shopify greiðsluágreining';
        Implementation = "Msg Interface ori" = "Payment Disputes Impl ori", "Msg Discovery ori" = "Payment Disputes Impl ori", "Msg Contract ori" = "Payment Disputes Impl ori";
    }
}
