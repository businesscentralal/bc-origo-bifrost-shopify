namespace Origo.Bifrost.Shopify;

/// <summary>Remembers successful payment writes while the imported Shopify order remains stale.</summary>
table 73732090 "Order Paid Marker ori"
{
    Access = Internal;
    DataClassification = CustomerContent;
    Caption = 'Shopify paid order request', Comment = 'is-IS=Beiðni um greidda Shopify pöntun';
    fields
    {
        field(1; "Shop Code"; Code[20])
        {
            Caption = 'Shop Code', Comment = 'is-IS=Verslunarkóði';
        }
        field(2; "Order Id"; BigInteger)
        {
            Caption = 'Order Id', Comment = 'is-IS=Pöntunarauðkenni';
        }
    }
    keys
    {
        key(PK; "Shop Code", "Order Id") { Clustered = true; }
    }
}
