@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption Item CDS Rejection'
@Metadata.allowExtensions: true

define view entity ZC_RAIL_REJ
  as projection on ZI_RAIL_REJ
{
  key RejectionId,

      ConfirmId,
      OrderId,
      OrderType,
      rejectionreason,
      Quantity,
      Unit,
      displayrejunit,
      Remark,
      RejectionDate,

      CreatedBy,
      CreatedAt,
      LocalLastChangedAt,
      LastChangedAt,

      _OrderConfirmation : redirected to parent ZC_railway_ord
}
