@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Order Confirmation'
define root view entity ZI_railway_ord
  as select from ztb_railway_ord

 
  composition [0..*] of ZI_railwy_SCp        as _ScrapItems
  composition [0..*] of ZI_railwy_ACT     as _Activities
  composition [0..*] of ZI_RAIL_REJ     as _REJECTION
{
  key confirm_id          as ConfirmId,

      order_no            as OrderNo,
      fetched_order_no    as FetchedOrderNo,
      material            as Material,
      mat_desc            as mat_desc,
      plant               as Plant,
      batch_number,
      postingdate,
      start_end_date,
      unit,
      display_unit        as DISPLAYUNIT,

      @Consumption.valueHelpDefinition: [{
        entity: {
          name: 'ZSHIFT_DD',
          element: 'Shift'
        }
      }]
      group_defn,

      order_type          as order_type,
      order_qty           as OrderQty,
      confirmed_qty       as ConfirmedQty,
      confirmed_scrap_qty as confirmedscrapqty,
      remaining_qty       as RemainingQty,
      operation           as Operation,

      @Consumption.valueHelpDefinition: [{
        entity: {
          name: 'ZWORK_CEN_VH',
          element: 'work_center'
        }
      }]
      work_center         as WorkCenter,

      qty_to_confirm      as QtyToConfirm,
      scrap_qty           as ScrapQty,
      weight_qty          as weightqty,

      confirmation_group  as ConfirmationGroup,
      confirmation_count  as ConfirmationCount,
      material_document   as MaterialDocument,
      material_document_year as MaterialDocumentYear,
      material_document_item as MaterialDocumentItem,
      serials_posted      as SerialsPosted,

      @ObjectModel.text.element: ['StatusText']
      @UI.textArrangement: #TEXT_ONLY
      status              as Status,

      cast(
  case status
    when 'PART_POST' then 'PART POSTED'
    else status
  end
  as abap.char(20)
) as StatusText,

      case status
        when 'POSTED'    then 3
        when 'PART_POST' then 5
        when 'CREATED'   then 2
        when 'CANCELLED' then 1
        else 0
      end                 as statuscriticality,

      created_by             as CreatedBy,
      created_at           as CreatedAt,
      local_last_changed_at     as locallastchanged_at,
      last_changed_at     as lastchangedat,

      _ScrapItems,
   
      _Activities,
      _REJECTION
}
