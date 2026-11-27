namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Inventory.Item;
using Origo.Bifrost.Shopify;
using System.TestLibraries.Utilities;

/// <summary>Mock-only connector stand-in, restricted to the reserved issue 10 fixture product and shop.</summary>
codeunit 97501 "Shpfy AddVariants Stub ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Product AddVariants Run ori", OnBeforeRunConnector, '', false, false)]
    local procedure StandInForConnector(ParentProductId: BigInteger; RequestedItemNo: Code[20]; Parameters: Text; var Handled: Boolean)
    var
        Product: Record "Shpfy Product";
        Item: Record Item;
        FilteredItem: Record Item;
        Variant: Record "Shpfy Variant";
        Assert: Codeunit "Library Assert";
        Document: XmlDocument;
        Node: XmlNode;
        NextId: BigInteger;
    begin
        if ParentProductId <> 8910000010L then
            exit;
        Product.Get(ParentProductId);
        Assert.AreEqual('BIFT10', Product."Shop Code", 'Mock is restricted to the fixture shop.');
        Handled := true;
        XmlDocument.ReadFrom(Parameters, Document);
        Assert.IsTrue(Document.SelectSingleNode('//Field[@name="ParentItemNo"]', Node), 'Report parent parameter.');
        Assert.AreEqual(Format(ParentProductId, 0, 9), Node.AsXmlElement().InnerText(), 'Report parent value.');
        Assert.IsTrue(Document.SelectSingleNode('//DataItem[@name="Item"]', Node), 'Report Item filter.');
        FilteredItem.SetView(Node.AsXmlElement().InnerText());
        Assert.AreEqual(1, FilteredItem.Count(), 'Report is limited to exactly one item.');
        FilteredItem.FindFirst();
        Assert.AreEqual(RequestedItemNo, FilteredItem."No.", 'Report item is literal, including filter characters.');
        Item.Get(RequestedItemNo);
        if Item.Description = 'NOOP' then
            exit;
        Variant.SetRange("Product Id", ParentProductId);
        NextId := 8910000100L;
        if Variant.FindLast() then
            NextId := Variant.Id + 1;
        Variant.Init();
        Variant.Id := NextId;
        Variant."Product Id" := ParentProductId;
        Variant."Item SystemId" := Item.SystemId;
        Variant.Insert();
        // Simulate a connector that wrote before refusing: the runner must roll this row back.
        if Item.Blocked then
            Error('Mock connector: item is blocked.');
    end;
}
