@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@EndUserText.label: 'Order Scrap Items'

define view entity ZC_railway_SCP
  as projection on ZI_railwy_SCP
{
  key ScrapItemId,

      ConfirmId,
      ScrapMaterial,
      Scrapdesc,
      StorageLocation,
      ScrapQty,
      Scrapunit,
      DISPLAYSCRAPUNIT,
      CreatedBy,
      CreatedAt,
      ChangedBy,
      ChangedAt,

      _OrderConfirmation : redirected to parent ZC_railway_ord
}
