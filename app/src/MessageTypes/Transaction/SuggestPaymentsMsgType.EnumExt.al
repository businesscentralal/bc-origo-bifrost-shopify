namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

/// <summary>Registers the write-only Shopify payment suggestion contract.</summary>
enumextension 73732060 "Suggest Payments MsgType ori" extends "Message Type ori"
{
    /// <summary>Suggests journal lines without posting.</summary>
    value(73732060; "Shopify.Transaction.SuggestPayments")
    {
        Caption = 'Shopify.Transaction.SuggestPayments', Locked = true;
        Implementation = "Msg Interface ori" = "Suggest Payments Impl ori", "Msg Discovery ori" = "Suggest Payments Impl ori", "Msg Contract ori" = "Suggest Payments Impl ori";
    }
}
