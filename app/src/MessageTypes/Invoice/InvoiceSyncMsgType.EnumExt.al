namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

/// <summary>Registers the posted invoice export write message type.</summary>
enumextension 73731955 "Invoice Sync MsgType ori" extends "Message Type ori"
{
    /// <summary>Exports posted invoices as fulfilled Shopify orders.</summary>
    value(73731956; "Shopify.Invoice.Sync")
    {
        Caption = 'Shopify.Invoice.Sync', Locked = true;
        Implementation = "Msg Interface ori" = "Invoice Sync Impl ori", "Msg Discovery ori" = "Invoice Sync Impl ori", "Msg Contract ori" = "Invoice Sync Impl ori";
    }
}
