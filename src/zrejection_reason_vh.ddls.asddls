@AbapCatalog.sqlViewName: 'ZREJECTION_VH'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Rejection Reason Value Help'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true

@UI.presentationVariant: [{
  qualifier: 'ReasonCodeAscending',
  sortOrder: [{
    by: 'RejectionCode',
    direction: #ASC
  }]
}]

define view ZREJECTION_REASON_VH
  as select from ZR_TMG_REJECT_CODE
{
      @EndUserText.label: 'Order Type'
  key Order_Type,

      @EndUserText.label: 'Rejection Code'
      @Search.defaultSearchElement: true
  key RejectionCode,

      @EndUserText.label: 'Rejection Description'
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.7
      RejectionText as rejection_reason
}
