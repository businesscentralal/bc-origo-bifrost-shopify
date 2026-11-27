namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

/// <summary>Registers the write operation for adding items as Shopify variants.</summary>
enumextension 73732050 "Product AddVariants Msg ori" extends "Message Type ori"
{
    value(73732050; "Shopify.Product.AddItemsAsVariants")
    {
        Caption = 'Shopify.Product.AddItemsAsVariants', Locked = true;
        Implementation = "Msg Interface ori" = "Product AddVariants Impl ori", "Msg Discovery ori" = "Product AddVariants Impl ori", "Msg Contract ori" = "Product AddVariants Impl ori";
    }
}
