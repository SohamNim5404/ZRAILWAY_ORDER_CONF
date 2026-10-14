@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Production Activity'
@Metadata.allowExtensions: true


define view entity ZC_railway_ACT
  as projection on ZI_Railwy_ACT
{
  key ActivityId,

      ConfirmId,
      Operation,
      ActivitySlot,
      ActivityLabel,
      ActivityParam,
      ActivityName,

//      @Semantics.quantity.unitOfMeasure: 'ActivityUnit'
      ActivityQty,

      ActivityUnit,
      DisplayActivityUnit,

      _OrderConfirmation :
        redirected to parent ZC_railway_ord
}
