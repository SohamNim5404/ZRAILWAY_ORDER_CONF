@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Order Confirmation'
@Metadata.allowExtensions: true

define root view entity ZC_railway_ord
  provider contract transactional_query
  as projection on ZI_railway_ord
{
  key ConfirmId,

      @ObjectModel.text.element: [ 'mat_desc' ]
      @UI.textArrangement: #TEXT_LAST
      OrderNo,
      FetchedOrderNo,
      Material,
      mat_desc,
      Plant,
      batch_number,
      postingdate,
      start_end_date,
      unit,
          DISPLAYUNIT,
      group_defn,
//      displaygroupdefn,
      order_type,
      OrderQty,
      ConfirmedQty,
      confirmedscrapqty,
      RemainingQty,
      Operation,
      WorkCenter,
      QtyToConfirm,
      ScrapQty,
      weightqty,
      ConfirmationGroup,
      ConfirmationCount,
      MaterialDocument,
      MaterialDocumentItem,
      MaterialDocumentYear,
    SerialsPosted,

@ObjectModel.text.element: ['StatusText']
@UI.textArrangement: #TEXT_ONLY
Status,

StatusText,
statuscriticality,
      CreatedBy,
      CreatedAt,
      locallastchanged_at,
      lastchangedat,

     
      _ScrapItems : redirected to composition child ZC_railway_SCP,
      _Activities : redirected to composition child ZC_railway_ACT,
      _REJECTION : redirected to composition child ZC_RAIL_REJ

}
