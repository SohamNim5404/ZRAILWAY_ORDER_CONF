@Metadata.allowExtensions: true
@EndUserText.label: 'Order Scrap Materials'
define view entity ZI_railwy_SCp
  as select from ztb_railwy_scp

  association to parent ZI_railway_ord
    as _OrderConfirmation
    on $projection.ConfirmId =
       _OrderConfirmation.ConfirmId
{
  key scrap_item_id    as ScrapItemId,

      confirm_id       as ConfirmId,
      scrap_material   as ScrapMaterial,
      scrap_desc       as Scrapdesc,
      storage_location as StorageLocation,
      scrap_qty        as ScrapQty,
      scrap_unit       as Scrapunit,
      displayscrap_unit as DISPLAYSCRAPUNIT,

      @Semantics.user.createdBy: true
      created_by       as CreatedBy,

      @Semantics.systemDateTime.createdAt: true
      created_at       as CreatedAt,

      @Semantics.user.lastChangedBy: true
      changed_by       as ChangedBy,

      @Semantics.systemDateTime.lastChangedAt: true
      changed_at       as ChangedAt,

      _OrderConfirmation
}
