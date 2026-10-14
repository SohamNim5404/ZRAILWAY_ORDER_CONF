@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Item CDS Rejection'
@Metadata.allowExtensions: true

define view entity ZI_RAIL_REJ
  as select from ztb_rail_reject

  association to parent ZI_railway_ord as _OrderConfirmation
    on $projection.ConfirmId = _OrderConfirmation.ConfirmId
{
  key rejection_id          as RejectionId,

      confirm_id            as ConfirmId,
      order_id              as OrderId,
      order_type            as OrderType,
     @Consumption.valueHelpDefinition: [{
  entity: {
    name: 'ZREJECTION_REASON_VH',
    element: 'rejection_reason'
  },
  additionalBinding: [{
    localElement: 'OrderType',
    element: 'Order_Type',
    usage: #FILTER
  }],
  presentationVariantQualifier: 'ReasonCodeAscending'
}]
rejection_reason as rejectionreason,

    
      quantity              as Quantity,


     unit as Unit,

case
  when unit = 'ST' then 'PC'
  else unit
end as DisplayREJUnit,

      remark                as Remark,
      rejection_date        as RejectionDate,

      @Semantics.user.createdBy: true
      created_by            as CreatedBy,

      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,

      _OrderConfirmation
}
