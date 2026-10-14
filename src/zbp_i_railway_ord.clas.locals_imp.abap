CLASS lcl_confirmation_buffer DEFINITION.
  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_entry,
        confirm_id TYPE sysuuid_x16,
        pid        TYPE abp_behv_pid,
      END OF ty_entry.

    CLASS-DATA entries TYPE STANDARD TABLE OF ty_entry
      WITH EMPTY KEY.

ENDCLASS.

CLASS lcl_confirmation_buffer IMPLEMENTATION.
ENDCLASS.

CLASS lcl_rejection_material_buffer DEFINITION.
  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_entry,
        confirm_id TYPE sysuuid_x16,
        pid        TYPE abp_behv_pid,
      END OF ty_entry.

    CLASS-DATA entries
      TYPE STANDARD TABLE OF ty_entry WITH EMPTY KEY.

ENDCLASS.

CLASS lcl_rejection_material_buffer IMPLEMENTATION.
ENDCLASS.

CLASS lhc_railway_ord DEFINITION
  INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS get_instance_authorizations
      FOR INSTANCE AUTHORIZATION
      IMPORTING keys
        REQUEST requested_authorizations
        FOR railway_ord
      RESULT result.

   METHODS get_instance_features
  FOR INSTANCE FEATURES
  IMPORTING keys REQUEST requested_features
    FOR railway_ord
  RESULT result.

    METHODS setinitialstatus
      FOR DETERMINE ON MODIFY
      IMPORTING keys
        FOR railway_ord~setinitialstatus.

    METHODS invalidateorderfetch
      FOR DETERMINE ON MODIFY
      IMPORTING keys
        FOR railway_ord~invalidateorderfetch.

    METHODS validateorderfetched
      FOR VALIDATE ON SAVE
      IMPORTING keys
        FOR railway_ord~validateorderfetched.

    METHODS validatetotalquantity
      FOR VALIDATE ON SAVE
      IMPORTING keys
        FOR railway_ord~validatetotalquantity.

        METHODS ValidateRejectionReason
  FOR VALIDATE ON SAVE
  IMPORTING keys
    FOR railway_ord~ValidateRejectionReason.

    METHODS validateserialcount
      FOR VALIDATE ON SAVE
      IMPORTING keys
        FOR railway_ord~validateserialcount.

    METHODS fetchorderdata
      FOR MODIFY
      IMPORTING keys
        FOR ACTION railway_ord~fetchorderdata
      RESULT result.

    METHODS submitandpost
      FOR MODIFY
      IMPORTING keys
        FOR ACTION railway_ord~submitandpost
      RESULT result.

    METHODS cancelconfirmation
      FOR MODIFY
      IMPORTING keys
        FOR ACTION railway_ord~cancelconfirmation
      RESULT result.

      METHODS postrejection
  FOR MODIFY
  IMPORTING keys FOR ACTION railway_ord~PostRejection
  RESULT result.

  METHODS cancelrejection
  FOR MODIFY
  IMPORTING keys FOR ACTION railway_ord~CancelRejection
  RESULT result.

ENDCLASS.


CLASS lhc_railway_ord IMPLEMENTATION.

  METHOD get_instance_authorizations.

  READ ENTITIES OF zi_railway_ord IN LOCAL MODE
    ENTITY railway_ord
      FIELDS ( orderno status )
      WITH CORRESPONDING #( keys )
    RESULT DATA(lt_orders).

  result = VALUE #(
    FOR ls_order IN lt_orders
    (
      %tky = ls_order-%tky

      %update = COND #(
        WHEN requested_authorizations-%update =
             if_abap_behv=>mk-on
        THEN COND #(
          WHEN ls_order-orderno IS INITIAL
            OR ls_order-status = 'CREATED'
          THEN if_abap_behv=>auth-allowed
          ELSE if_abap_behv=>auth-unauthorized
        )
      )

      %delete = COND #(
        WHEN requested_authorizations-%delete =
             if_abap_behv=>mk-on
        THEN COND #(
          WHEN ls_order-orderno IS INITIAL
            OR ls_order-status = 'CREATED'
          THEN if_abap_behv=>auth-allowed
          ELSE if_abap_behv=>auth-unauthorized
        )
      )
      %action-PostRejection = COND #(
  WHEN requested_authorizations-%action-PostRejection =
       if_abap_behv=>mk-on
  THEN COND #(
    WHEN ls_order-%is_draft = if_abap_behv=>mk-off
      AND ( ls_order-status = 'POSTED'
         OR ls_order-status = 'PART_POST' )
    THEN if_abap_behv=>auth-allowed
    ELSE if_abap_behv=>auth-unauthorized
  )
)
    )
  ).

ENDMETHOD.

  METHOD get_instance_features.

  READ ENTITIES OF zi_railway_ord IN LOCAL MODE
    ENTITY railway_ord
      FIELDS (
        orderno
        status
        confirmationgroup
        confirmationcount
        materialdocument
        materialdocumentyear
      )
      WITH CORRESPONDING #( keys )
    RESULT DATA(lt_orders).

  result = VALUE #(
    FOR ls_order IN lt_orders
    (
      %tky = ls_order-%tky

      %features-%delete = COND #(
        WHEN ls_order-orderno IS INITIAL
          OR ls_order-status = 'CREATED'
        THEN if_abap_behv=>fc-o-enabled
        ELSE if_abap_behv=>fc-o-disabled
      )

      %features-%action-Edit = COND #(
        WHEN ls_order-%is_draft = if_abap_behv=>mk-off
         AND ( ls_order-orderno IS INITIAL
            OR ls_order-status = 'CREATED' )
        THEN if_abap_behv=>fc-o-enabled
        ELSE if_abap_behv=>fc-o-disabled
      )

      " Post the production confirmation
      %features-%action-SubmitAndPost = COND #(
        WHEN ls_order-%is_draft = if_abap_behv=>mk-off
         AND ls_order-status = 'CREATED'
        THEN if_abap_behv=>fc-o-enabled
        ELSE if_abap_behv=>fc-o-disabled
      )

      " Post batch goods receipt after confirmation
      %features-%action-postrejection = COND #(
        WHEN ls_order-%is_draft = if_abap_behv=>mk-off
         AND ( ls_order-status = 'POSTED'
            OR ls_order-status = 'PART_POST' )
         AND ls_order-materialdocument IS INITIAL
        THEN if_abap_behv=>fc-o-enabled
        ELSE if_abap_behv=>fc-o-disabled
      )

      " Cancel the production confirmation
      %features-%action-CancelConfirmation = COND #(
        WHEN ls_order-%is_draft = if_abap_behv=>mk-off
         AND ls_order-status = 'POSTED'
         AND ls_order-confirmationgroup IS NOT INITIAL
         AND ls_order-confirmationcount IS NOT INITIAL
        THEN if_abap_behv=>fc-o-enabled
        ELSE if_abap_behv=>fc-o-disabled
      )

      " Cancel the assigned goods receipt material document
      %features-%action-CancelRejection = COND #(
        WHEN ls_order-%is_draft = if_abap_behv=>mk-off
         AND ls_order-materialdocument IS NOT INITIAL
         AND ls_order-materialdocumentyear IS NOT INITIAL
        THEN if_abap_behv=>fc-o-enabled
        ELSE if_abap_behv=>fc-o-disabled
      )
    )
  ).

ENDMETHOD.

 METHOD setinitialstatus.

  MODIFY ENTITIES OF zi_railway_ord IN LOCAL MODE
    ENTITY railway_ord
      UPDATE FIELDS ( status )
      WITH VALUE #(
        FOR key IN keys
        (
          %tky = key-%tky
          status = 'CREATED'
        )
      ).

ENDMETHOD.

  METHOD invalidateorderfetch.

    READ ENTITIES OF zi_railway_ord IN LOCAL MODE
      ENTITY railway_ord
        FIELDS ( fetchedorderno )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    MODIFY ENTITIES OF zi_railway_ord IN LOCAL MODE
      ENTITY railway_ord
        UPDATE FIELDS ( fetchedorderno )
        WITH VALUE #(
          FOR ls_header IN lt_headers
          WHERE (
            %is_draft = if_abap_behv=>mk-on
            AND fetchedorderno IS NOT INITIAL
          )
          (
            %tky           = ls_header-%tky
            fetchedorderno = ''
          )
        ).

  ENDMETHOD.

  METHOD validateorderfetched.

    READ ENTITIES OF zi_railway_ord IN LOCAL MODE
      ENTITY railway_ord
        FIELDS ( orderno fetchedorderno status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers INTO DATA(ls_header).

      "Clear previous validation messages
      APPEND VALUE #(
        %tky = ls_header-%tky
        %state_area = 'ORDER_FETCH'
      ) TO reported-railway_ord.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %state_area = 'REMAINING_QUANTITY'
      ) TO reported-railway_ord.

      "Apply only to new confirmations
      IF ls_header-status IS NOT INITIAL
         AND ls_header-status <> 'CREATED'.
        CONTINUE.
      ENDIF.

      DATA(lv_order_no) = ls_header-orderno.
      DATA(lv_fetched_order_no) = ls_header-fetchedorderno.

      lv_order_no = |{ lv_order_no ALPHA = IN }|.
      lv_fetched_order_no = |{ lv_fetched_order_no ALPHA = IN }|.

      IF ls_header-orderno IS INITIAL
         OR ls_header-fetchedorderno IS INITIAL
         OR lv_order_no <> lv_fetched_order_no.

        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-railway_ord.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %state_area = 'ORDER_FETCH'
          %element-orderno = if_abap_behv=>mk-on
          %msg = new_message(
            id       = 'ZRAILWAY_MSG'
            number   = '045'
            severity = if_abap_behv_message=>severity-error
          )
        ) TO reported-railway_ord.

        CONTINUE.
      ENDIF.

      "Read current quantities; avoid DCL checks in save validation
      SELECT SINGLE
        FROM i_manufacturingorder WITH PRIVILEGED ACCESS
        FIELDS mfgorderplannedtotalqty,
               mfgorderconfirmedyieldqty,
               mfgorderconfirmedscrapqty
        WHERE manufacturingorder = @lv_order_no
        INTO @DATA(ls_current_order).

      DATA(lv_msg_number) = CONV symsgno( '' ).

      IF sy-subrc <> 0.
        lv_msg_number = '001'.
      ELSE.

        DATA(lv_remaining_qty) =
            ls_current_order-mfgorderplannedtotalqty
          - ls_current_order-mfgorderconfirmedyieldqty
          - ls_current_order-mfgorderconfirmedscrapqty.

        IF lv_remaining_qty <= 0.
          lv_msg_number = '002'.
        ENDIF.

      ENDIF.

      IF lv_msg_number IS NOT INITIAL.

        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-railway_ord.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %state_area = 'REMAINING_QUANTITY'
          %element-orderno = if_abap_behv=>mk-on
          %msg = new_message(
            id       = 'ZRAILWAY_MSG'
            number   = lv_msg_number
            severity = if_abap_behv_message=>severity-error
          )
        ) TO reported-railway_ord.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD validatetotalquantity.

    READ ENTITIES OF zi_railway_ord IN LOCAL MODE
      ENTITY railway_ord
        FIELDS ( qtytoconfirm scrapqty remainingqty )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers INTO DATA(ls_header).

      "Clear the previous validation message
      APPEND VALUE #(
        %tky        = ls_header-%tky
        %state_area = 'TOTAL_QUANTITY'
      ) TO reported-railway_ord.

      DATA(lv_total) =
        CONV decfloat34( ls_header-qtytoconfirm )
        + CONV decfloat34( ls_header-scrapqty ).

      DATA(lv_msg_number) = CONV symsgno( '' ).

      IF ls_header-qtytoconfirm < 0
         OR ls_header-scrapqty < 0.

        lv_msg_number = '003'.

      ELSEIF lv_total > ls_header-remainingqty.

        lv_msg_number = '004'.

      ENDIF.

      IF lv_msg_number IS NOT INITIAL.

        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-railway_ord.

        APPEND VALUE #(
          %tky                  = ls_header-%tky
          %state_area           = 'TOTAL_QUANTITY'
          %element-qtytoconfirm = if_abap_behv=>mk-on
          %element-scrapqty     = if_abap_behv=>mk-on
          %msg = new_message(
            id       = 'ZRAILWAY_MSG'
            number   = lv_msg_number
            severity = if_abap_behv_message=>severity-error
          )
        ) TO reported-railway_ord.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

 METHOD ValidateRejectionReason.

  READ ENTITIES OF zi_railway_ord IN LOCAL MODE
    ENTITY railway_ord
      FIELDS ( ScrapQty Unit )
      WITH CORRESPONDING #( keys )
    RESULT DATA(lt_headers).

  DATA:
    lv_total      TYPE decfloat34,
    lv_msg_number TYPE symsgno.

  LOOP AT lt_headers INTO DATA(ls_header).

    CLEAR: lv_total, lv_msg_number.

    APPEND VALUE #(
      %tky        = ls_header-%tky
      %state_area = 'REJECTION_CHECK'
    ) TO reported-railway_ord.

    READ ENTITIES OF zi_railway_ord IN LOCAL MODE
      ENTITY railway_ord BY \_REJECTION
        ALL FIELDS
        WITH VALUE #( ( %tky = ls_header-%tky ) )
      RESULT DATA(lt_rejections)
      FAILED DATA(ls_read_failed).

    IF ls_read_failed IS NOT INITIAL.
      lv_msg_number = '069'.
    ELSE.
      LOOP AT lt_rejections INTO DATA(ls_rejection).

        IF ls_rejection-RejectionReason IS INITIAL.
          lv_msg_number = '046'.
          EXIT.
        ENDIF.

        IF ls_rejection-Quantity < 0.
          lv_msg_number = '067'.
          EXIT.
        ENDIF.

        IF ls_rejection-Unit <> ls_header-Unit.
          lv_msg_number = '068'.
          EXIT.
        ENDIF.

        lv_total = lv_total
          + CONV decfloat34( ls_rejection-Quantity ).

      ENDLOOP.

      IF lv_msg_number IS INITIAL
         AND lv_total <> CONV decfloat34( ls_header-ScrapQty ).
        lv_msg_number = '066'.
      ENDIF.
    ENDIF.

    IF lv_msg_number IS NOT INITIAL.

      APPEND VALUE #( %tky = ls_header-%tky )
        TO failed-railway_ord.

      APPEND VALUE #(
        %tky              = ls_header-%tky
        %state_area       = 'REJECTION_CHECK'
        %element-ScrapQty = if_abap_behv=>mk-on
        %msg = new_message(
          id       = 'ZRAILWAY_MSG'
          number   = lv_msg_number
          severity = if_abap_behv_message=>severity-error
          v1       = |{ lv_total }|
          v2       = |{ ls_header-ScrapQty }|
        )
      ) TO reported-railway_ord.

    ENDIF.
  ENDLOOP.

ENDMETHOD.




  METHOD validateserialcount.
ENDMETHOD.

 METHOD fetchorderdata.

  READ ENTITIES OF zi_railway_ord IN LOCAL MODE
    ENTITY railway_ord
      FIELDS ( orderno scrapqty qtytoconfirm )
      WITH CORRESPONDING #( keys )
    RESULT DATA(lt_headers)
    FAILED failed.

  LOOP AT lt_headers INTO DATA(ls_header).

    DATA(lv_msg_number) = CONV symsgno( '' ).

    IF ls_header-orderno IS INITIAL.

      APPEND VALUE #(
        %tky = ls_header-%tky
      ) TO failed-railway_ord.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %element-orderno = if_abap_behv=>mk-on
        %msg = new_message(
          id       = 'ZRAILWAY_MSG'
          number   = '047'
          severity = if_abap_behv_message=>severity-error
        )
      ) TO reported-railway_ord.

      CONTINUE.
    ENDIF.

    DATA(lv_order_no) = ls_header-orderno.
    lv_order_no = |{ lv_order_no ALPHA = IN }|.

    "Read manufacturing order
    SELECT SINGLE
      FROM i_manufacturingorder
      FIELDS material,
             batch,
             mfgorderscheduledstartdate,
             mfgorderscheduledenddate,
             productionplant,
             manufacturingordertype,
             mfgorderplannedtotalqty,
             mfgorderconfirmedyieldqty,
             mfgorderconfirmedscrapqty
      WHERE manufacturingorder = @lv_order_no
      INTO @DATA(ls_order).

    IF sy-subrc <> 0.

      APPEND VALUE #(
        %tky = ls_header-%tky
      ) TO failed-railway_ord.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %element-orderno = if_abap_behv=>mk-on
        %msg = new_message(
          id       = 'ZRAILWAY_MSG'
          number   = '048'
          severity = if_abap_behv_message=>severity-error
          v1       = ls_header-orderno
        )
      ) TO reported-railway_ord.

      CONTINUE.
    ENDIF.

          "Railway and Disc product group validation
      DATA lv_product_group TYPE i_product-productgroup.
      CLEAR lv_product_group.

      SELECT SINGLE
        FROM i_product
        FIELDS productgroup
        WHERE product = @ls_order-material
        INTO @lv_product_group.

      IF sy-subrc <> 0
         OR lv_product_group IS INITIAL
         OR ( lv_product_group <> 'H151'
          AND lv_product_group <> 'H140'
          AND lv_product_group <> 'H138'
          AND lv_product_group <> 'H149' ).

        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-railway_ord.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %element-orderno = if_abap_behv=>mk-on
          %msg = new_message(
            id       = 'ZRAILWAY_MSG'
            number   = '049'
            severity = if_abap_behv_message=>severity-error
          )
        ) TO reported-railway_ord.

        CONTINUE.
      ENDIF.

      "Check remaining goods issue: 261 minus 262.
      SELECT
        FROM i_materialdocumentitem_2
        FIELDS material,
               plant,
               materialbaseunit,
               SUM(
                 CASE
                   WHEN goodsmovementtype = '261'
                     THEN quantityinbaseunit
                   ELSE - quantityinbaseunit
                 END
               ) AS net_issue_qty
        WHERE manufacturingorder = @lv_order_no
          AND ( goodsmovementtype = '261'
             OR goodsmovementtype = '262' )
        GROUP BY material,
                 plant,
                 materialbaseunit
        INTO TABLE @DATA(lt_goods_issue).

      DATA lv_goods_issue_exists TYPE abap_bool.
      CLEAR lv_goods_issue_exists.

      LOOP AT lt_goods_issue INTO DATA(ls_goods_issue).

        IF ls_goods_issue-net_issue_qty > 0.
          lv_goods_issue_exists = abap_true.
          EXIT.
        ENDIF.

      ENDLOOP.

      IF lv_goods_issue_exists = abap_false.

        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-railway_ord.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %element-orderno = if_abap_behv=>mk-on
          %msg = new_message(
            id       = 'ZRAILWAY_MSG'
            number   = '050'
            severity = if_abap_behv_message=>severity-error
          )
        ) TO reported-railway_ord.

        CONTINUE.
      ENDIF.


    "Check released status
    SELECT SINGLE
      FROM i_manufacturingorderstatus
      FIELDS statuscode,
             statusisactive
      WHERE manufacturingorder = @lv_order_no
        AND statuscode = 'I0002'
      INTO @DATA(ls_release_status).

    IF sy-subrc <> 0
       OR ls_release_status-statusisactive IS INITIAL.

      APPEND VALUE #(
        %tky = ls_header-%tky
      ) TO failed-railway_ord.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %element-orderno = if_abap_behv=>mk-on
        %msg = new_message(
          id       = 'ZRAILWAY_MSG'
          number   = '051'
          severity = if_abap_behv_message=>severity-error
          v1       = ls_header-orderno
        )
      ) TO reported-railway_ord.

      CONTINUE.
    ENDIF.

    IF ls_order-batch IS INITIAL.

      APPEND VALUE #(
        %tky = ls_header-%tky
      ) TO failed-railway_ord.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %element-batch_number = if_abap_behv=>mk-on
        %msg = new_message(
          id       = 'ZRAILWAY_MSG'
          number   = '052'
          severity = if_abap_behv_message=>severity-error
          v1       = ls_header-orderno
        )
      ) TO reported-railway_ord.

      CONTINUE.
    ENDIF.

    DATA(lv_remaining_qty) =
        ls_order-mfgorderplannedtotalqty
      - ls_order-mfgorderconfirmedyieldqty
      - ls_order-mfgorderconfirmedscrapqty.

    IF lv_remaining_qty <= 0.

      APPEND VALUE #(
        %tky = ls_header-%tky
      ) TO failed-railway_ord.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %element-orderno = if_abap_behv=>mk-on
        %msg = new_message(
          id       = 'ZRAILWAY_MSG'
          number   = '053'
          severity = if_abap_behv_message=>severity-error
          v1       = ls_header-orderno
        )
      ) TO reported-railway_ord.

      CONTINUE.
    ENDIF.

    "Material description
    DATA lv_mat_desc TYPE
      i_productdescription-productdescription.

    CLEAR lv_mat_desc.

    SELECT SINGLE
      FROM i_productdescription
      FIELDS productdescription
      WHERE product = @ls_order-material
        AND language = @sy-langu
      INTO @lv_mat_desc.

    "Keep the operation-selection logic from the original method
    SELECT SINGLE
      FROM i_manufacturingorderoperation
      FIELDS manufacturingorderoperation_2,
             workcenterinternalid,
             productionunit,
             opqtytobaseqtydnmntr,
             opqtytobaseqtynmrtr
      WHERE manufacturingorder = @lv_order_no
      INTO @DATA(lv_operation).

    IF sy-subrc <> 0
       OR lv_operation-opqtytobaseqtynmrtr = 0.

      APPEND VALUE #(
        %tky = ls_header-%tky
      ) TO failed-railway_ord.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %msg = new_message(
          id       = 'ZRAILWAY_MSG'
          number   = '054'
          severity = if_abap_behv_message=>severity-error
        )
      ) TO reported-railway_ord.

      CONTINUE.
    ENDIF.

    DATA lv_workcenter TYPE i_workcenter-workcenter.
    CLEAR lv_workcenter.

    SELECT SINGLE
      FROM i_workcenter
      FIELDS workcenter
      WHERE workcenterinternalid =
              @lv_operation-workcenterinternalid
      INTO @lv_workcenter.

    DATA(lv_confirmed_qty_wt) =
      ( CONV decfloat34( ls_header-qtytoconfirm )
        + CONV decfloat34( ls_header-scrapqty ) )
      * ( CONV decfloat34(
            lv_operation-opqtytobaseqtydnmntr )
          / CONV decfloat34(
            lv_operation-opqtytobaseqtynmrtr ) ).

    "Update railway header
    MODIFY ENTITIES OF zi_railway_ord IN LOCAL MODE
      ENTITY railway_ord
        UPDATE FIELDS (
          material
          mat_desc
          plant
          batch_number
          postingdate
          start_end_date
          unit
          displayunit
          order_type
          orderqty
          confirmedqty
          confirmedscrapqty
          remainingqty
          operation
          workcenter
          weightqty
        )
        WITH VALUE #(
          (
            %tky = ls_header-%tky
            material = ls_order-material
            mat_desc = lv_mat_desc
            plant = ls_order-productionplant
            batch_number = ls_order-batch
            postingdate =
              ls_order-mfgorderscheduledstartdate
            start_end_date =
              ls_order-mfgorderscheduledenddate
            unit = lv_operation-productionunit
            displayunit = COND #(
              WHEN lv_operation-productionunit = 'ST'
              THEN 'PC'
              ELSE lv_operation-productionunit
            )
            order_type = ls_order-manufacturingordertype
            orderqty = ls_order-mfgorderplannedtotalqty
            confirmedqty =
              ls_order-mfgorderconfirmedyieldqty
            confirmedscrapqty =
              ls_order-mfgorderconfirmedscrapqty
            remainingqty = lv_remaining_qty
            operation =
              lv_operation-manufacturingorderoperation_2
            workcenter = lv_workcenter
            weightqty = lv_confirmed_qty_wt
          )
        )
      FAILED DATA(ls_header_update_failed)
      REPORTED DATA(ls_header_update_reported).

    APPEND LINES OF
      ls_header_update_failed-railway_ord
      TO failed-railway_ord.

    APPEND LINES OF
      ls_header_update_reported-railway_ord
      TO reported-railway_ord.

    IF ls_header_update_failed IS NOT INITIAL.
      CONTINUE.
    ENDIF.

    "Read scrap components
    SELECT FROM i_productionordercomponent AS comp
      LEFT OUTER JOIN i_productdescription AS txt
        ON txt~product = comp~material
       AND txt~language = @sy-langu
      FIELDS
        comp~material,
        txt~productdescription,
        comp~storagelocation,
        comp~requiredquantity,
        comp~baseunit
      WHERE comp~productionorder = @lv_order_no
        AND comp~goodsmovementtype = '531'
      INTO TABLE @DATA(lt_scrap_components).

    DELETE lt_scrap_components WHERE material IS INITIAL.

    "Read activity source before replacing child rows
    SELECT FROM i_manufacturingorderoperation AS op
      LEFT OUTER JOIN i_standardworkfmlaparamgroup AS grp
        ON grp~standardworkformulaparamgroup =
             op~standardworkformulaparamgroup
      FIELDS
        op~manufacturingorderoperation_2 AS operation,
        op~operationreferencequantity,
        op~workcenterstandardworkqty1,
        op~workcenterstandardworkqty2,
        op~workcenterstandardworkqty3,
        op~workcenterstandardworkqty4,
        op~workcenterstandardworkqty5,
        op~workcenterstandardworkqty6,
        op~workcenterstandardworkqtyunit1,
        op~workcenterstandardworkqtyunit2,
        op~workcenterstandardworkqtyunit3,
        op~workcenterstandardworkqtyunit4,
        op~workcenterstandardworkqtyunit5,
        op~workcenterstandardworkqtyunit6,
        grp~standardworkformulaparam1,
        grp~standardworkformulaparam2,
        grp~standardworkformulaparam3,
        grp~standardworkformulaparam4,
        grp~standardworkformulaparam5,
        grp~standardworkformulaparam6
      WHERE op~manufacturingorder = @lv_order_no
        AND op~manufacturingorderoperation_2 =
              @lv_operation-manufacturingorderoperation_2
      INTO TABLE @DATA(lt_activity_source).

    CLEAR lv_msg_number.

    IF lines( lt_activity_source ) > 1.
      lv_msg_number = '005'.

    ELSEIF lt_activity_source IS INITIAL.
      lv_msg_number = '006'.
    ENDIF.

    DATA ls_activity_source LIKE LINE OF lt_activity_source.
    CLEAR ls_activity_source.

    IF lv_msg_number IS INITIAL.

      READ TABLE lt_activity_source INDEX 1
        INTO ls_activity_source.

      IF ls_activity_source-operationreferencequantity <= 0.
        lv_msg_number = '007'.
      ENDIF.

    ENDIF.

    IF lv_msg_number IS NOT INITIAL.

      APPEND VALUE #(
        %tky = ls_header-%tky
      ) TO failed-railway_ord.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %msg = new_message(
          id       = 'ZRAILWAY_MSG'
          number   = lv_msg_number
          severity = if_abap_behv_message=>severity-error
        )
      ) TO reported-railway_ord.

      CONTINUE.
    ENDIF.

    "Build railway activity rows
    DATA:
      lv_activity_slot  TYPE n LENGTH 1,
      lv_activity_param TYPE ztb_railwy_act-activity_param,
      lv_activity_name  TYPE ztb_railwy_act-activity_name,
      lv_activity_qty   TYPE ztb_railwy_act-activity_qty,
      lv_activity_unit  TYPE ztb_railwy_act-activity_unit.

    DATA lt_activity_create TYPE TABLE FOR CREATE
      zi_railway_ord\_activities.

    CLEAR lt_activity_create.

    APPEND INITIAL LINE TO lt_activity_create
      ASSIGNING FIELD-SYMBOL(<activity_request>).

    <activity_request>-%tky = ls_header-%tky.
    <activity_request>-%is_draft = ls_header-%is_draft.

    DO 6 TIMES.

      lv_activity_slot = sy-index.

      CLEAR:
        lv_activity_param,
        lv_activity_name,
        lv_activity_qty,
        lv_activity_unit.

      DATA(lv_param_field) =
        |STANDARDWORKFORMULAPARAM{ lv_activity_slot }|.

      DATA(lv_qty_field) =
        |WORKCENTERSTANDARDWORKQTY{ lv_activity_slot }|.

      DATA(lv_unit_field) =
        |WORKCENTERSTANDARDWORKQTYUNIT{ lv_activity_slot }|.

      ASSIGN COMPONENT lv_param_field
        OF STRUCTURE ls_activity_source
        TO FIELD-SYMBOL(<activity_param>).

      IF sy-subrc = 0.
        lv_activity_param = <activity_param>.
      ENDIF.

      ASSIGN COMPONENT lv_qty_field
        OF STRUCTURE ls_activity_source
        TO FIELD-SYMBOL(<activity_qty>).

      IF sy-subrc = 0.

        lv_activity_qty =
          ( CONV decfloat34( <activity_qty> )
            / CONV decfloat34(
                ls_activity_source-operationreferencequantity ) )
          * lv_confirmed_qty_wt.

      ENDIF.

      ASSIGN COMPONENT lv_unit_field
        OF STRUCTURE ls_activity_source
        TO FIELD-SYMBOL(<activity_unit>).

      IF sy-subrc = 0.
        lv_activity_unit = <activity_unit>.
      ENDIF.

      IF lv_activity_param IS NOT INITIAL.

        SELECT SINGLE
          FROM i_standardworkformulaparamtext
          FIELDS standardworkformulaparamname
          WHERE standardworkformulaparameter =
                  @lv_activity_param
            AND language = @sy-langu
          INTO @lv_activity_name.

      ENDIF.

      IF lv_activity_param IS INITIAL
         AND lv_activity_name IS INITIAL
         AND lv_activity_qty IS INITIAL
         AND lv_activity_unit IS INITIAL.
        CONTINUE.
      ENDIF.

      APPEND VALUE #(
        %is_draft = ls_header-%is_draft
        operation =
          lv_operation-manufacturingorderoperation_2
        activityslot = lv_activity_slot
        activitylabel = |Activity { lv_activity_slot }|
        activityparam = lv_activity_param
        activityname = lv_activity_name
        activityqty = lv_activity_qty
        activityunit = lv_activity_unit
        displayactivityunit = COND #(
          WHEN lv_activity_unit = 'STD'
          THEN 'HRS'
          WHEN lv_activity_unit = 'ST'
          THEN 'PC'
          ELSE lv_activity_unit
        )
      ) TO <activity_request>-%target.

    ENDDO.

    "Read existing child rows
    READ ENTITIES OF zi_railway_ord IN LOCAL MODE
      ENTITY railway_ord BY \_scrapitems
        FIELDS ( scrapitemid )
        WITH VALUE #( ( %tky = ls_header-%tky ) )
      RESULT DATA(lt_existing_scrap)

      ENTITY railway_ord BY \_activities
        ALL FIELDS
        WITH VALUE #( ( %tky = ls_header-%tky ) )
      RESULT DATA(lt_existing_activities)

      FAILED DATA(ls_child_read_failed)
      REPORTED DATA(ls_child_read_reported).

    APPEND LINES OF ls_child_read_failed-railway_ord
      TO failed-railway_ord.
    APPEND LINES OF ls_child_read_failed-scrapitem
      TO failed-scrapitem.
    APPEND LINES OF ls_child_read_failed-activity
      TO failed-activity.

    APPEND LINES OF ls_child_read_reported-railway_ord
      TO reported-railway_ord.
    APPEND LINES OF ls_child_read_reported-scrapitem
      TO reported-scrapitem.
    APPEND LINES OF ls_child_read_reported-activity
      TO reported-activity.

    IF ls_child_read_failed IS NOT INITIAL.

      IF NOT line_exists(
        failed-railway_ord[ %tky = ls_header-%tky ]
      ).
        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-railway_ord.
      ENDIF.

      CONTINUE.
    ENDIF.

    "Delete previous scrap rows
    IF lt_existing_scrap IS NOT INITIAL.

      MODIFY ENTITIES OF zi_railway_ord IN LOCAL MODE
        ENTITY scrapitem
          DELETE FROM VALUE #(
            FOR ls_existing_scrap IN lt_existing_scrap
            ( %tky = ls_existing_scrap-%tky )
          )
        FAILED DATA(ls_scrap_delete_failed)
        REPORTED DATA(ls_scrap_delete_reported).

      APPEND LINES OF ls_scrap_delete_failed-scrapitem
        TO failed-scrapitem.

      APPEND LINES OF ls_scrap_delete_reported-scrapitem
        TO reported-scrapitem.

      IF ls_scrap_delete_failed IS NOT INITIAL.

        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-railway_ord.

        CONTINUE.
      ENDIF.

    ENDIF.

    "Create railway scrap rows
    IF lt_scrap_components IS NOT INITIAL.

      MODIFY ENTITIES OF zi_railway_ord IN LOCAL MODE
        ENTITY railway_ord
          CREATE BY \_scrapitems AUTO FILL CID
            FIELDS (
              scrapmaterial
              scrapdesc
              storagelocation
              scrapqty
              scrapunit
              displayscrapunit
            )
            WITH VALUE #(
              (
                %tky = ls_header-%tky
                %is_draft = ls_header-%is_draft

                %target = VALUE #(
                  FOR ls_component IN lt_scrap_components
                  (
                    %is_draft = ls_header-%is_draft
                    scrapmaterial = ls_component-material
                    scrapdesc = ls_component-productdescription
                    storagelocation =
                      ls_component-storagelocation
                   scrapqty = COND #(
                      WHEN ls_component-requiredquantity = 0
                      THEN ls_header-ScrapQty

                      WHEN ls_component-requiredquantity < 0
                      THEN ls_component-requiredquantity * -1

                      ELSE ls_component-requiredquantity
                    )
                    scrapunit = ls_component-baseunit
                    displayscrapunit = COND #(
                      WHEN ls_component-baseunit = 'ST'
                      THEN 'PC'
                      ELSE ls_component-baseunit
                    )
                  )
                )
              )
            )
        FAILED DATA(ls_scrap_create_failed)
        REPORTED DATA(ls_scrap_create_reported).

      APPEND LINES OF ls_scrap_create_failed-railway_ord
        TO failed-railway_ord.
      APPEND LINES OF ls_scrap_create_failed-scrapitem
        TO failed-scrapitem.

      APPEND LINES OF ls_scrap_create_reported-railway_ord
        TO reported-railway_ord.
      APPEND LINES OF ls_scrap_create_reported-scrapitem
        TO reported-scrapitem.

      IF ls_scrap_create_failed IS NOT INITIAL.

        IF NOT line_exists(
          failed-railway_ord[ %tky = ls_header-%tky ]
        ).
          APPEND VALUE #(
            %tky = ls_header-%tky
          ) TO failed-railway_ord.
        ENDIF.

        CONTINUE.
      ENDIF.

    ENDIF.

    "Delete previous activity rows
    IF lt_existing_activities IS NOT INITIAL.

      MODIFY ENTITIES OF zi_railway_ord IN LOCAL MODE
        ENTITY activity
          DELETE FROM VALUE #(
            FOR ls_existing_activity IN lt_existing_activities
            ( %tky = ls_existing_activity-%tky )
          )
        FAILED DATA(ls_activity_delete_failed)
        REPORTED DATA(ls_activity_delete_reported).

      APPEND LINES OF ls_activity_delete_failed-activity
        TO failed-activity.

      APPEND LINES OF ls_activity_delete_reported-activity
        TO reported-activity.

      IF ls_activity_delete_failed IS NOT INITIAL.

        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-railway_ord.

        CONTINUE.
      ENDIF.

    ENDIF.

    "Create refreshed railway activity rows
    IF <activity_request>-%target IS NOT INITIAL.

      MODIFY ENTITIES OF zi_railway_ord IN LOCAL MODE
        ENTITY railway_ord
          CREATE BY \_activities AUTO FILL CID
            FIELDS (
              operation
              activityslot
              activitylabel
              activityparam
              activityname
              activityqty
              activityunit
              displayactivityunit
            )
            WITH lt_activity_create
        FAILED DATA(ls_activity_create_failed)
        REPORTED DATA(ls_activity_create_reported).

      APPEND LINES OF ls_activity_create_failed-railway_ord
        TO failed-railway_ord.
      APPEND LINES OF ls_activity_create_failed-activity
        TO failed-activity.

      APPEND LINES OF ls_activity_create_reported-railway_ord
        TO reported-railway_ord.
      APPEND LINES OF ls_activity_create_reported-activity
        TO reported-activity.

      IF ls_activity_create_failed IS NOT INITIAL.

        IF NOT line_exists(
          failed-railway_ord[ %tky = ls_header-%tky ]
        ).
          APPEND VALUE #(
            %tky = ls_header-%tky
          ) TO failed-railway_ord.
        ENDIF.

        CONTINUE.
      ENDIF.

    ENDIF.

    "Mark order as successfully fetched
    MODIFY ENTITIES OF zi_railway_ord IN LOCAL MODE
      ENTITY railway_ord
        UPDATE FIELDS ( fetchedorderno )
        WITH VALUE #(
          (
            %tky = ls_header-%tky
            fetchedorderno = lv_order_no
          )
        )
      FAILED DATA(ls_fetch_mark_failed)
      REPORTED DATA(ls_fetch_mark_reported).

    APPEND LINES OF ls_fetch_mark_failed-railway_ord
      TO failed-railway_ord.

    APPEND LINES OF ls_fetch_mark_reported-railway_ord
      TO reported-railway_ord.

    IF ls_fetch_mark_failed IS NOT INITIAL.
      CONTINUE.
    ENDIF.

    APPEND VALUE #(
      %tky = ls_header-%tky
      %msg = new_message(
        id       = 'ZRAILWAY_MSG'
        number   = '055'
        severity = if_abap_behv_message=>severity-success
        v1       = ls_header-orderno
      )
    ) TO reported-railway_ord.

  ENDLOOP.

  "Return updated header
  READ ENTITIES OF zi_railway_ord IN LOCAL MODE
    ENTITY railway_ord
      ALL FIELDS
      WITH CORRESPONDING #( keys )
    RESULT DATA(lt_updated_headers)
    FAILED DATA(ls_final_read_failed)
    REPORTED DATA(ls_final_read_reported).

  APPEND LINES OF ls_final_read_failed-railway_ord
    TO failed-railway_ord.

  APPEND LINES OF ls_final_read_reported-railway_ord
    TO reported-railway_ord.

  result = VALUE #(
    FOR ls_updated_header IN lt_updated_headers
    (
      %tky = ls_updated_header-%tky
      %param = ls_updated_header
    )
  ).

ENDMETHOD.


 METHOD submitandpost.

  DATA(lv_posting_date) =
    cl_abap_context_info=>get_system_date( ).

  DATA(lv_current_time) =
    cl_abap_context_info=>get_system_time( ).

  "Read railway headers
  READ ENTITIES OF zi_railway_ord IN LOCAL MODE
    ENTITY railway_ord
      ALL FIELDS
      WITH CORRESPONDING #( keys )
    RESULT DATA(lt_headers)
    FAILED DATA(ls_read_failed)
    REPORTED DATA(ls_read_reported).

  APPEND LINES OF ls_read_failed-railway_ord
    TO failed-railway_ord.

  APPEND LINES OF ls_read_reported-railway_ord
    TO reported-railway_ord.

  LOOP AT lt_headers INTO DATA(ls_header).

    DATA(lv_msg_number) = CONV symsgno( '' ).

    "Validate header before posting
    IF ls_header-%is_draft = if_abap_behv=>mk-on.
      lv_msg_number = '008'.

    ELSEIF ls_header-status <> 'CREATED'.
      lv_msg_number = '009'.

    ELSEIF ls_header-orderno IS INITIAL.
      lv_msg_number = '010'.

    ELSEIF ls_header-operation IS INITIAL.
      lv_msg_number = '011'.

    ELSEIF ls_header-postingdate IS INITIAL.
      lv_msg_number = '012'.

    ELSEIF ls_header-unit IS INITIAL.
      lv_msg_number = '013'.

    ELSEIF ls_header-qtytoconfirm < 0
        OR ls_header-scrapqty < 0.
      lv_msg_number = '014'.

    ELSEIF ls_header-qtytoconfirm = 0
       AND ls_header-scrapqty = 0.
      lv_msg_number = '015'.

    ELSEIF ls_header-remainingqty <= 0.
      lv_msg_number = '016'.

    ELSEIF ls_header-qtytoconfirm + ls_header-scrapqty >
           ls_header-remainingqty.
      lv_msg_number = '017'.

    ENDIF.

    IF lv_msg_number IS NOT INITIAL.

      APPEND VALUE #(
        %tky = ls_header-%tky
      ) TO failed-railway_ord.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %msg = new_message(
          id       = 'ZRAILWAY_MSG'
          number   = lv_msg_number
          severity = if_abap_behv_message=>severity-error
        )
      ) TO reported-railway_ord.

      CONTINUE.

    ENDIF.

    "Read saved scrap rows
    READ ENTITIES OF zi_railway_ord IN LOCAL MODE
      ENTITY railway_ord BY \_scrapitems
        ALL FIELDS
        WITH VALUE #( ( %tky = ls_header-%tky ) )
      RESULT DATA(lt_scrap_items)
      FAILED DATA(ls_scrap_read_failed)
      REPORTED DATA(ls_scrap_read_reported).

    APPEND LINES OF ls_scrap_read_failed-railway_ord
      TO failed-railway_ord.
    APPEND LINES OF ls_scrap_read_failed-scrapitem
      TO failed-scrapitem.

    APPEND LINES OF ls_scrap_read_reported-railway_ord
      TO reported-railway_ord.
    APPEND LINES OF ls_scrap_read_reported-scrapitem
      TO reported-scrapitem.

    IF ls_scrap_read_failed IS NOT INITIAL.

      IF NOT line_exists(
        failed-railway_ord[ %tky = ls_header-%tky ]
      ).
        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-railway_ord.
      ENDIF.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %msg = new_message(
          id       = 'ZRAILWAY_MSG'
          number   = '056'
          severity = if_abap_behv_message=>severity-error
        )
      ) TO reported-railway_ord.

      CONTINUE.

    ENDIF.

    "Validate scrap movements
    CLEAR lv_msg_number.

    LOOP AT lt_scrap_items INTO DATA(ls_scrap_check).

      IF ls_scrap_check-scrapqty < 0.
        lv_msg_number = '018'.
        EXIT.
      ENDIF.

      IF ls_scrap_check-scrapqty > 0
         AND ( ls_scrap_check-scrapmaterial IS INITIAL
            OR ls_scrap_check-storagelocation IS INITIAL
            OR ls_scrap_check-scrapunit IS INITIAL ).

        lv_msg_number = '019'.
        EXIT.

      ENDIF.

    ENDLOOP.

    IF lv_msg_number IS NOT INITIAL.

      APPEND VALUE #(
        %tky = ls_header-%tky
      ) TO failed-railway_ord.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %msg = new_message(
          id       = 'ZRAILWAY_MSG'
          number   = lv_msg_number
          severity = if_abap_behv_message=>severity-error
        )
      ) TO reported-railway_ord.

      CONTINUE.

    ENDIF.

    "Normalize order using the standard BO field type
    DATA ls_standard_header
      TYPE STRUCTURE FOR CREATE i_productionordconfirmationtp.

    CLEAR ls_standard_header.

    ls_standard_header-orderid = ls_header-orderno.
    ls_standard_header-orderid =
      |{ ls_standard_header-orderid ALPHA = IN }|.

    "Build positive-quantity scrap movements
    DATA lt_movements TYPE TABLE FOR CREATE
      i_productionordconfirmationtp\_prodnordconfmatldocitm.

    DATA ls_movement_request LIKE LINE OF lt_movements.

    CLEAR:
      lt_movements,
      ls_movement_request.

    ls_movement_request-%cid_ref = 'CONF_1'.

    LOOP AT lt_scrap_items INTO DATA(ls_scrap)
      WHERE scrapqty > 0.

      APPEND VALUE #(
        %cid = |MAT_{ sy-tabix }|

        orderid             = ls_standard_header-orderid
        material            = ls_scrap-scrapmaterial
        plant               = ls_header-plant
        storagelocation     = ls_scrap-storagelocation
        goodsmovementtype   = '531'
        entryunitsapcode    = ls_scrap-scrapunit
        quantityinentryunit = ls_scrap-scrapqty
      ) TO ls_movement_request-%target.

    ENDLOOP.

    IF ls_movement_request-%target IS NOT INITIAL.
      APPEND ls_movement_request TO lt_movements.
    ENDIF.

    "Read saved production activities
    READ ENTITIES OF zi_railway_ord IN LOCAL MODE
      ENTITY railway_ord BY \_activities
        ALL FIELDS
        WITH VALUE #( ( %tky = ls_header-%tky ) )
      RESULT DATA(lt_post_activities)
      FAILED DATA(ls_act_failed)
      REPORTED DATA(ls_act_reported).

    APPEND LINES OF ls_act_failed-railway_ord
      TO failed-railway_ord.
    APPEND LINES OF ls_act_failed-activity
      TO failed-activity.

    APPEND LINES OF ls_act_reported-railway_ord
      TO reported-railway_ord.
    APPEND LINES OF ls_act_reported-activity
      TO reported-activity.

    CLEAR lv_msg_number.

    IF ls_act_failed IS NOT INITIAL.
      lv_msg_number = '020'.
    ENDIF.

    DATA ls_act_values
      TYPE STRUCTURE FOR CREATE i_productionordconfirmationtp.

    CLEAR ls_act_values.

    IF lv_msg_number IS INITIAL.

      LOOP AT lt_post_activities INTO DATA(ls_act).

        IF ls_act-activityqty < 0.
          lv_msg_number = '021'.
          EXIT.
        ENDIF.

        IF ls_act-activityqty <> 0
           AND ls_act-activityunit IS INITIAL.
          lv_msg_number = '022'.
          EXIT.
        ENDIF.

        CASE ls_act-activityslot.

          WHEN '1'.
            ls_act_values-opconfirmedworkquantity1 =
              ls_act-activityqty.
            ls_act_values-workquantityunit1sapcode =
              ls_act-activityunit.

          WHEN '2'.
            ls_act_values-opconfirmedworkquantity2 =
              ls_act-activityqty.
            ls_act_values-workquantityunit2sapcode =
              ls_act-activityunit.

          WHEN '3'.
            ls_act_values-opconfirmedworkquantity3 =
              ls_act-activityqty.
            ls_act_values-workquantityunit3sapcode =
              ls_act-activityunit.

          WHEN '4'.
            ls_act_values-opconfirmedworkquantity4 =
              ls_act-activityqty.
            ls_act_values-workquantityunit4sapcode =
              ls_act-activityunit.

          WHEN '5'.
            ls_act_values-opconfirmedworkquantity5 =
              ls_act-activityqty.
            ls_act_values-workquantityunit5sapcode =
              ls_act-activityunit.

          WHEN '6'.
            ls_act_values-opconfirmedworkquantity6 =
              ls_act-activityqty.
            ls_act_values-workquantityunit6sapcode =
              ls_act-activityunit.

          WHEN OTHERS.
            lv_msg_number = '023'.
            EXIT.

        ENDCASE.

      ENDLOOP.

    ENDIF.

    IF lv_msg_number IS NOT INITIAL.

      IF NOT line_exists(
        failed-railway_ord[ %tky = ls_header-%tky ]
      ).
        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-railway_ord.
      ENDIF.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %msg = new_message(
          id       = 'ZRAILWAY_MSG'
          number   = lv_msg_number
          severity = if_abap_behv_message=>severity-error
        )
      ) TO reported-railway_ord.

      CONTINUE.

    ENDIF.

    "Create standard confirmation and scrap movements
    MODIFY ENTITIES OF i_productionordconfirmationtp
      ENTITY productionorderconfirmation

        CREATE FIELDS (
          orderid
          sequence
          orderoperation
          plant
          workcenter
          postingdate
          confirmedexecutionstartdate
          confirmedexecutionstarttime
          confirmedexecutionenddate
          confirmedexecutionendtime
          shiftgrouping
          shiftdefinition
          finalconfirmationtype
          confirmationyieldquantity
          confirmationscrapquantity
          confirmationunitsapcode
          opconfirmedworkquantity1
          workquantityunit1sapcode
          opconfirmedworkquantity2
          workquantityunit2sapcode
          opconfirmedworkquantity3
          workquantityunit3sapcode
          opconfirmedworkquantity4
          workquantityunit4sapcode
          opconfirmedworkquantity5
          workquantityunit5sapcode
          opconfirmedworkquantity6
          workquantityunit6sapcode
        )

        WITH VALUE #(
          (
            %cid = 'CONF_1'

            orderid        = ls_standard_header-orderid
            sequence       = '000000'
            orderoperation = ls_header-operation
            plant          = ls_header-plant
            workcenter     = ls_header-workcenter
            postingdate    = lv_posting_date

            confirmedexecutionstartdate = lv_posting_date
            confirmedexecutionenddate   = lv_posting_date
            confirmedexecutionstarttime = lv_current_time
            confirmedexecutionendtime   = lv_current_time

            shiftgrouping   = 'PP'
            shiftdefinition = ls_header-group_defn

            finalconfirmationtype = COND #(
              WHEN ls_header-remainingqty =
                   ls_header-qtytoconfirm + ls_header-scrapqty
              THEN 'X'
              ELSE space
            )

            confirmationyieldquantity = ls_header-qtytoconfirm
            confirmationscrapquantity = ls_header-scrapqty
            confirmationunitsapcode   = ls_header-unit

            opconfirmedworkquantity1 =
              ls_act_values-opconfirmedworkquantity1
            workquantityunit1sapcode =
              ls_act_values-workquantityunit1sapcode

            opconfirmedworkquantity2 =
              ls_act_values-opconfirmedworkquantity2
            workquantityunit2sapcode =
              ls_act_values-workquantityunit2sapcode

            opconfirmedworkquantity3 =
              ls_act_values-opconfirmedworkquantity3
            workquantityunit3sapcode =
              ls_act_values-workquantityunit3sapcode

            opconfirmedworkquantity4 =
              ls_act_values-opconfirmedworkquantity4
            workquantityunit4sapcode =
              ls_act_values-workquantityunit4sapcode

            opconfirmedworkquantity5 =
              ls_act_values-opconfirmedworkquantity5
            workquantityunit5sapcode =
              ls_act_values-workquantityunit5sapcode

            opconfirmedworkquantity6 =
              ls_act_values-opconfirmedworkquantity6
            workquantityunit6sapcode =
              ls_act_values-workquantityunit6sapcode
          )
        )

        CREATE BY \_prodnordconfmatldocitm
          FIELDS (
            orderid
            material
            plant
            storagelocation
            goodsmovementtype
            entryunitsapcode
            quantityinentryunit
          )
          WITH lt_movements

      MAPPED DATA(ls_post_mapped)
      FAILED DATA(ls_post_failed)
      REPORTED DATA(ls_post_reported).

    "Forward standard confirmation messages
    LOOP AT ls_post_reported-productionorderconfirmation
      INTO DATA(ls_conf_message).

      IF ls_conf_message-%msg IS BOUND.
        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = ls_conf_message-%msg
        ) TO reported-railway_ord.
      ENDIF.

    ENDLOOP.

    "Forward standard goods movement messages
    LOOP AT ls_post_reported-prodorderconfmatldocitem
      INTO DATA(ls_gm_message).

      IF ls_gm_message-%msg IS BOUND.
        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = ls_gm_message-%msg
        ) TO reported-railway_ord.
      ENDIF.

    ENDLOOP.

    IF ls_post_failed IS NOT INITIAL.

      APPEND VALUE #(
        %tky = ls_header-%tky
      ) TO failed-railway_ord.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %msg = new_message(
          id       = 'ZRAILWAY_MSG'
          number   = '057'
          severity = if_abap_behv_message=>severity-error
          v1       = ls_header-orderno
        )
      ) TO reported-railway_ord.

      CONTINUE.

    ENDIF.

    "Buffer standard confirmation PID for save_modified
    LOOP AT ls_post_mapped-productionorderconfirmation
      INTO DATA(ls_created_confirmation)
      WHERE %cid = 'CONF_1'.

      APPEND VALUE #(
        confirm_id = ls_header-confirmid
        pid        = ls_created_confirmation-%pid
      ) TO lcl_confirmation_buffer=>entries.

    ENDLOOP.

    "Mark railway confirmation as posted
    MODIFY ENTITIES OF zi_railway_ord IN LOCAL MODE
      ENTITY railway_ord
        UPDATE FIELDS ( status postingdate )
        WITH VALUE #(
          (
            %tky        = ls_header-%tky
            status = COND #(
              WHEN ls_header-ScrapQty > 0
              THEN 'PART_POST'
              ELSE 'POSTED'
            )
            postingdate = lv_posting_date
          )
        )
      FAILED DATA(ls_update_failed)
      REPORTED DATA(ls_update_reported).

    APPEND LINES OF ls_update_failed-railway_ord
      TO failed-railway_ord.

    APPEND LINES OF ls_update_reported-railway_ord
      TO reported-railway_ord.

    IF ls_update_failed IS NOT INITIAL.
      CONTINUE.
    ENDIF.

    ls_header-status = 'POSTED'.
    ls_header-postingdate = lv_posting_date.

    APPEND VALUE #(
      %tky = ls_header-%tky
      %msg = new_message(
        id       = 'ZRAILWAY_MSG'
        number   = '058'
        severity = if_abap_behv_message=>severity-success
        v1       = ls_header-orderno
      )
    ) TO reported-railway_ord.

    APPEND VALUE #(
      %tky   = ls_header-%tky
      %param = ls_header
    ) TO result.

  ENDLOOP.

ENDMETHOD.

  METHOD cancelconfirmation.

  READ ENTITIES OF zi_railway_ord IN LOCAL MODE
    ENTITY railway_ord
      ALL FIELDS
      WITH CORRESPONDING #( keys )
    RESULT DATA(lt_headers)
    FAILED DATA(ls_read_failed)
    REPORTED DATA(ls_read_reported).

  APPEND LINES OF ls_read_failed-railway_ord
    TO failed-railway_ord.

  APPEND LINES OF ls_read_reported-railway_ord
    TO reported-railway_ord.

  LOOP AT lt_headers INTO DATA(ls_header).

    DATA(lv_msg_number) = CONV symsgno( '' ).

    "Validate before cancellation
    IF ls_header-%is_draft = if_abap_behv=>mk-on.
      lv_msg_number = '024'.

    ELSEIF ls_header-status <> 'POSTED'.
      lv_msg_number = '025'.

    ELSEIF ls_header-confirmationgroup IS INITIAL
        OR ls_header-confirmationcount IS INITIAL.
      lv_msg_number = '026'.

    ENDIF.

    IF lv_msg_number IS NOT INITIAL.

      APPEND VALUE #(
        %tky = ls_header-%tky
      ) TO failed-railway_ord.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %msg = new_message(
          id       = 'ZRAILWAY_MSG'
          number   = lv_msg_number
          severity = if_abap_behv_message=>severity-error
        )
      ) TO reported-railway_ord.

      CONTINUE.

    ENDIF.

    "Cancel the exact original standard confirmation
    MODIFY ENTITIES OF i_productionordconfirmationtp
      ENTITY productionorderconfirmation
        EXECUTE cancelprodnordconf
        FROM VALUE #(
          (
            %tky-confirmationgroup =
              ls_header-confirmationgroup
            %tky-confirmationcount =
              ls_header-confirmationcount
          )
        )
      FAILED DATA(ls_cancel_failed)
      REPORTED DATA(ls_cancel_reported).

    "Forward standard confirmation messages
    LOOP AT ls_cancel_reported-productionorderconfirmation
      INTO DATA(ls_message).

      IF ls_message-%msg IS BOUND.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = ls_message-%msg
        ) TO reported-railway_ord.

      ENDIF.

    ENDLOOP.

    "Forward any standard goods movement messages
    LOOP AT ls_cancel_reported-prodorderconfmatldocitem
      INTO DATA(ls_movement_message).

      IF ls_movement_message-%msg IS BOUND.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = ls_movement_message-%msg
        ) TO reported-railway_ord.

      ENDIF.

    ENDLOOP.

    IF ls_cancel_failed IS NOT INITIAL.

      APPEND VALUE #(
        %tky = ls_header-%tky
      ) TO failed-railway_ord.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %msg = new_message(
          id       = 'ZRAILWAY_MSG'
          number   = '059'
          severity = if_abap_behv_message=>severity-error
        )
      ) TO reported-railway_ord.

      CONTINUE.

    ENDIF.

    "Update railway status in the same RAP transaction
    MODIFY ENTITIES OF zi_railway_ord IN LOCAL MODE
      ENTITY railway_ord
        UPDATE FIELDS ( status )
        WITH VALUE #(
          (
            %tky   = ls_header-%tky
            status = 'CANCELLED'
          )
        )
      FAILED DATA(ls_update_failed)
      REPORTED DATA(ls_update_reported).

    APPEND LINES OF ls_update_failed-railway_ord
      TO failed-railway_ord.

    APPEND LINES OF ls_update_reported-railway_ord
      TO reported-railway_ord.

    IF ls_update_failed IS NOT INITIAL.
      CONTINUE.
    ENDIF.

    "Read the updated railway header
    READ ENTITIES OF zi_railway_ord IN LOCAL MODE
      ENTITY railway_ord
        ALL FIELDS
        WITH VALUE #( ( %tky = ls_header-%tky ) )
      RESULT DATA(lt_updated)
      FAILED DATA(ls_final_read_failed)
      REPORTED DATA(ls_final_read_reported).

    APPEND LINES OF ls_final_read_failed-railway_ord
      TO failed-railway_ord.

    APPEND LINES OF ls_final_read_reported-railway_ord
      TO reported-railway_ord.

    IF ls_final_read_failed IS NOT INITIAL.
      CONTINUE.
    ENDIF.

    LOOP AT lt_updated INTO DATA(ls_updated).

      APPEND VALUE #(
        %tky   = ls_updated-%tky
        %param = ls_updated
      ) TO result.

    ENDLOOP.

    APPEND VALUE #(
      %tky = ls_header-%tky
      %msg = new_message(
        id       = 'ZRAILWAY_MSG'
        number   = '060'
        severity = if_abap_behv_message=>severity-success
        v1       = ls_header-orderno
      )
    ) TO reported-railway_ord.

  ENDLOOP.

ENDMETHOD.

*METHOD postrejection.
*
*  DATA:
*    lv_error            TYPE string,
*    lv_storage_location TYPE
*      i_materialdocumentitem_2-storagelocation,
*    lv_order            TYPE
*      i_manufacturingorder-manufacturingorder,
*    lv_total_quantity   TYPE ztb_rail_reject-quantity.
*
*  READ ENTITIES OF zi_railway_ord IN LOCAL MODE
*    ENTITY railway_ord
*      ALL FIELDS
*      WITH CORRESPONDING #( keys )
*    RESULT DATA(lt_headers)
*    FAILED DATA(ls_read_failed)
*    REPORTED DATA(ls_read_reported).
*
*  APPEND LINES OF ls_read_failed-railway_ord
*    TO failed-railway_ord.
*
*  APPEND LINES OF ls_read_reported-railway_ord
*    TO reported-railway_ord.
*
*  LOOP AT lt_headers INTO DATA(ls_header).
*
*    CLEAR:
*      lv_error,
*      lv_storage_location,
*      lv_order,
*      lv_total_quantity.
*
*    "Validate the saved header
*    IF ls_header-%is_draft = if_abap_behv=>mk-on.
*      lv_error = 'Save the record before posting rejection items'.
*
*    ELSEIF ls_header-materialdocument IS NOT INITIAL.
*      lv_error =
*        'A material document is already assigned. Posting is blocked'.
*
*    ELSEIF ls_header-status <> 'POSTED'
*       AND ls_header-status <> 'PART_POST'.
*      lv_error = 'Complete Post Confirmation before posting rejection'.
*
*    ELSEIF ls_header-orderno IS INITIAL.
*      lv_error = 'Order number is required'.
*
*    ELSEIF ls_header-material IS INITIAL.
*      lv_error = 'Material is required'.
*
*    ELSEIF ls_header-plant IS INITIAL.
*      lv_error = 'Plant is required'.
*
*    ELSEIF ls_header-batch_number IS INITIAL.
*      lv_error = 'Batch number is required'.
*
*    ELSEIF ls_header-postingdate IS INITIAL.
*      lv_error = 'Posting date is required'.
*
*    ELSEIF ls_header-unit IS INITIAL.
*      lv_error = 'Confirmation unit is required'.
*    ENDIF.
*
*    IF lv_error IS NOT INITIAL.
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*      ) TO failed-railway_ord.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*        %msg = new_message_with_text(
*          severity = if_abap_behv_message=>severity-error
*          text     = lv_error
*        )
*      ) TO reported-railway_ord.
*
*      CONTINUE.
*    ENDIF.
*
*    "Read saved rejection rows
*    READ ENTITIES OF zi_railway_ord IN LOCAL MODE
*      ENTITY railway_ord BY \_REJECTION
*        ALL FIELDS
*        WITH VALUE #( ( %tky = ls_header-%tky ) )
*      RESULT DATA(lt_rejections)
*      FAILED DATA(ls_child_failed)
*      REPORTED DATA(ls_child_reported).
*
*    APPEND LINES OF ls_child_failed-railway_ord
*      TO failed-railway_ord.
*    APPEND LINES OF ls_child_failed-rejection
*      TO failed-rejection.
*
*    APPEND LINES OF ls_child_reported-railway_ord
*      TO reported-railway_ord.
*    APPEND LINES OF ls_child_reported-rejection
*      TO reported-rejection.
*
*    IF ls_child_failed IS NOT INITIAL.
*      lv_error = 'Unable to read rejection items'.
*
*    ELSEIF lt_rejections IS INITIAL.
*      lv_error = 'No rejection items available for posting'.
*
*    ELSE.
*      LOOP AT lt_rejections INTO DATA(ls_rejection).
*
*        IF ls_rejection-rejectionreason IS INITIAL.
*          lv_error = 'Enter a rejection reason on every row'.
*          EXIT.
*        ENDIF.
*
*        IF ls_rejection-quantity <= 0.
*          lv_error =
*            'Every rejection row must have a quantity greater than zero'.
*          EXIT.
*        ENDIF.
*
*        IF ls_rejection-unit <> ls_header-unit.
*          lv_error =
*            'Rejection units must match the header confirmation unit'.
*          EXIT.
*        ENDIF.
*
*        lv_total_quantity =
*          lv_total_quantity + ls_rejection-quantity.
*
*      ENDLOOP.
*    ENDIF.
*
*    "Use the manufacturing order receiving storage location
*    IF lv_error IS INITIAL.
*
*      lv_order = ls_header-orderno.
*      lv_order = |{ lv_order ALPHA = IN }|.
*
*      SELECT SINGLE
*        FROM i_manufacturingorderitem
*        FIELDS storagelocation
*        WHERE manufacturingorder = @lv_order
*          AND manufacturingorderitem = '0001'
*        INTO @lv_storage_location.
*
*      IF sy-subrc <> 0 OR lv_storage_location IS INITIAL.
*        lv_error =
*          'Storage location not found in manufacturing order item'.
*      ENDIF.
*
*    ENDIF.
*
*    IF lv_error IS NOT INITIAL.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*      ) TO failed-railway_ord.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*        %msg = new_message_with_text(
*          severity = if_abap_behv_message=>severity-error
*          text     = lv_error
*        )
*      ) TO reported-railway_ord.
*
*      CONTINUE.
*    ENDIF.
*
*    DATA(lv_header_cid) = |RH_{ ls_header-confirmid }|.
*    DATA(lv_item_cid)   = |RI_{ ls_header-confirmid }|.
*
*    "One batch receipt for the total rejection quantity.
*    "No serial-number children are created.
*    MODIFY ENTITIES OF i_materialdocumenttp
*
*      ENTITY materialdocument
*        CREATE FIELDS (
*          documentdate
*          postingdate
*          goodsmovementcode
*        )
*        WITH VALUE #(
*          (
*            %cid              = lv_header_cid
*            documentdate      = ls_header-postingdate
*            postingdate       = ls_header-postingdate
*            goodsmovementcode = '02'
*          )
*        )
*
*        CREATE BY \_materialdocumentitem
*          FIELDS (
*            material
*            plant
*            storagelocation
*            batch
*            goodsmovementtype
*            manufacturingorder
*            manufacturingorderitem
*            goodsmovementrefdoctype
*            quantityinentryunit
*            entryunit
*          )
*          WITH VALUE #(
*            (
*              %cid_ref = lv_header_cid
*              %target = VALUE #(
*                (
*                  %cid                    = lv_item_cid
*                  material                = ls_header-material
*                  plant                   = ls_header-plant
*                  storagelocation         = lv_storage_location
*                  batch                   = ls_header-batch_number
*                  goodsmovementtype       = '101'
*                  manufacturingorder      = lv_order
*                  manufacturingorderitem  = '0001'
*                  goodsmovementrefdoctype = 'F'
*                  quantityinentryunit     = lv_total_quantity
*                  entryunit               = ls_header-unit
*                )
*              )
*            )
*          )
*
*      MAPPED DATA(ls_md_mapped)
*      FAILED DATA(ls_md_failed)
*      REPORTED DATA(ls_md_reported).
*
*    LOOP AT ls_md_reported-materialdocument
*      INTO DATA(ls_header_message).
*
*      IF ls_header_message-%msg IS BOUND.
*        APPEND VALUE #(
*          %tky = ls_header-%tky
*          %msg = ls_header_message-%msg
*        ) TO reported-railway_ord.
*      ENDIF.
*
*    ENDLOOP.
*
*    LOOP AT ls_md_reported-materialdocumentitem
*      INTO DATA(ls_item_message).
*
*      IF ls_item_message-%msg IS BOUND.
*        APPEND VALUE #(
*          %tky = ls_header-%tky
*          %msg = ls_item_message-%msg
*        ) TO reported-railway_ord.
*      ENDIF.
*
*    ENDLOOP.
*
*    IF ls_md_failed IS NOT INITIAL.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*      ) TO failed-railway_ord.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*        %msg = new_message_with_text(
*          severity = if_abap_behv_message=>severity-error
*          text     = 'Rejection material-document request failed'
*        )
*      ) TO reported-railway_ord.
*
*      CONTINUE.
*    ENDIF.
*
*    READ TABLE ls_md_mapped-materialdocument
*      INTO DATA(ls_created_document)
*      WITH KEY %cid = lv_header_cid.
*
*    IF sy-subrc <> 0.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*      ) TO failed-railway_ord.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*        %msg = new_message_with_text(
*          severity = if_abap_behv_message=>severity-error
*          text     = 'Material-document mapping was not returned'
*        )
*      ) TO reported-railway_ord.
*
*      CONTINUE.
*    ENDIF.
*
*    APPEND VALUE #(
*      confirm_id = ls_header-confirmid
*      pid        = ls_created_document-%pid
*    ) TO lcl_rejection_material_buffer=>entries.
*
*    "Ensure this header participates in the custom save sequence.
*    "Do not change confirmation status or SerialsPosted.
*       "Set POSTED after successful rejection processing.
*    MODIFY ENTITIES OF zi_railway_ord IN LOCAL MODE
*      ENTITY railway_ord
*        UPDATE FIELDS ( Status )
*        WITH VALUE #(
*          (
*            %tky   = ls_header-%tky
*            Status = 'POSTED'
*          )
*        )
*      FAILED DATA(ls_update_failed)
*      REPORTED DATA(ls_update_reported).
*
*    APPEND LINES OF ls_update_failed-railway_ord
*      TO failed-railway_ord.
*    APPEND LINES OF ls_update_reported-railway_ord
*      TO reported-railway_ord.
*
*    IF ls_update_failed IS NOT INITIAL.
*      CONTINUE.
*    ENDIF.
*
*      READ ENTITIES OF zi_railway_ord IN LOCAL MODE
*      ENTITY railway_ord
*        ALL FIELDS
*        WITH VALUE #( ( %tky = ls_header-%tky ) )
*      RESULT DATA(lt_updated_headers).
*
*    LOOP AT lt_updated_headers INTO DATA(ls_updated_header).
*
*      APPEND VALUE #(
*        %tky   = ls_updated_header-%tky
*        %param = ls_updated_header
*      ) TO result.
*
*    ENDLOOP.
*    APPEND VALUE #(
*      %tky = ls_header-%tky
*      %msg = new_message_with_text(
*        severity = if_abap_behv_message=>severity-information
*        text     = 'Batch rejection receipt accepted for saving'
*      )
*    ) TO reported-railway_ord.
*
*  ENDLOOP.
*
*ENDMETHOD.

METHOD postrejection.

  DATA:
    lv_msg_number            TYPE symsgno,
    lv_storage_location TYPE
      i_materialdocumentitem_2-storagelocation,
    lv_order            TYPE
      i_manufacturingorder-manufacturingorder,
    lv_total_quantity   TYPE ztb_rail_reject-quantity.

  READ ENTITIES OF zi_railway_ord IN LOCAL MODE
    ENTITY railway_ord
      ALL FIELDS
      WITH CORRESPONDING #( keys )
    RESULT DATA(lt_headers)
    FAILED DATA(ls_read_failed)
    REPORTED DATA(ls_read_reported).

  APPEND LINES OF ls_read_failed-railway_ord
    TO failed-railway_ord.

  APPEND LINES OF ls_read_reported-railway_ord
    TO reported-railway_ord.

  LOOP AT lt_headers INTO DATA(ls_header).

    CLEAR:
      lv_msg_number,
      lv_storage_location,
      lv_order,
      lv_total_quantity.

    "Validate the saved header
    IF ls_header-%is_draft = if_abap_behv=>mk-on.
      lv_msg_number = '027'.

    ELSEIF ls_header-materialdocument IS NOT INITIAL.
      lv_msg_number = '028'.

    ELSEIF ls_header-status <> 'POSTED'
       AND ls_header-status <> 'PART_POST'.
      lv_msg_number = '029'.

    ELSEIF ls_header-orderno IS INITIAL.
      lv_msg_number = '030'.

    ELSEIF ls_header-material IS INITIAL.
      lv_msg_number = '031'.

    ELSEIF ls_header-plant IS INITIAL.
      lv_msg_number = '032'.

    ELSEIF ls_header-batch_number IS INITIAL.
      lv_msg_number = '033'.

    ELSEIF ls_header-postingdate IS INITIAL.
      lv_msg_number = '034'.

    ELSEIF ls_header-unit IS INITIAL.
      lv_msg_number = '035'.
    ENDIF.

    IF lv_msg_number IS NOT INITIAL.
      APPEND VALUE #(
        %tky = ls_header-%tky
      ) TO failed-railway_ord.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %msg = new_message(
          id       = 'ZRAILWAY_MSG'
          number   = lv_msg_number
          severity = if_abap_behv_message=>severity-error
        )
      ) TO reported-railway_ord.

      CONTINUE.
    ENDIF.

    "Without scrap, post the header yield as a batch goods receipt.
    IF ls_header-scrapqty = 0.

      lv_total_quantity = ls_header-qtytoconfirm.

      IF lv_total_quantity <= 0.
        lv_msg_number = '036'.
      ENDIF.

    ELSEIF ls_header-scrapqty < 0.

      lv_msg_number = '037'.

    ELSE.

    "Read saved rejection rows
    READ ENTITIES OF zi_railway_ord IN LOCAL MODE
      ENTITY railway_ord BY \_REJECTION
        ALL FIELDS
        WITH VALUE #( ( %tky = ls_header-%tky ) )
      RESULT DATA(lt_rejections)
      FAILED DATA(ls_child_failed)
      REPORTED DATA(ls_child_reported).

      "Update Rejection Display Unit
*IF lt_rejections IS NOT INITIAL.
*
*  MODIFY ENTITIES OF zi_railway_ord IN LOCAL MODE
*    ENTITY rejection
*      UPDATE FIELDS ( DisplayREJUnit )
*      WITH VALUE #(
*        FOR ls_rejection IN lt_rejections
*        (
*          %tky = ls_rejection-%tky
*
*          DisplayREJUnit = COND #(
*            WHEN ls_rejection-Unit = 'ST'
*            THEN 'PC'
*            ELSE ls_rejection-Unit
*          )
*        )
*      )
*    FAILED DATA(ls_unit_failed)
*    REPORTED DATA(ls_unit_reported).
*
*ENDIF.

    APPEND LINES OF ls_child_failed-railway_ord
      TO failed-railway_ord.
    APPEND LINES OF ls_child_failed-rejection
      TO failed-rejection.

    APPEND LINES OF ls_child_reported-railway_ord
      TO reported-railway_ord.
    APPEND LINES OF ls_child_reported-rejection
      TO reported-rejection.

    IF ls_child_failed IS NOT INITIAL.
      lv_msg_number = '038'.

    ELSEIF lt_rejections IS INITIAL.
      lv_msg_number = '039'.

    ELSE.
      LOOP AT lt_rejections INTO DATA(ls_rejection).

        IF ls_rejection-rejectionreason IS INITIAL.
          lv_msg_number = '040'.
          EXIT.
        ENDIF.

*        IF ls_rejection-quantity <= 0.
*          lv_error =
*            'Every rejection row must have a quantity greater than zero'.
*          EXIT.
*        ENDIF.

        IF ls_rejection-unit <> ls_header-unit.
          lv_msg_number = '041'.
          EXIT.
        ENDIF.

        lv_total_quantity =
          lv_total_quantity + ls_rejection-quantity.

      ENDLOOP.
    ENDIF.

    ENDIF.

    "Use the manufacturing order receiving storage location
    IF lv_msg_number IS INITIAL.

      lv_order = ls_header-orderno.
      lv_order = |{ lv_order ALPHA = IN }|.

      SELECT SINGLE
        FROM i_manufacturingorderitem
        FIELDS storagelocation
        WHERE manufacturingorder = @lv_order
          AND manufacturingorderitem = '0001'
        INTO @lv_storage_location.

      IF sy-subrc <> 0 OR lv_storage_location IS INITIAL.
        lv_msg_number = '042'.
      ENDIF.

    ENDIF.

    IF lv_msg_number IS NOT INITIAL.

      APPEND VALUE #(
        %tky = ls_header-%tky
      ) TO failed-railway_ord.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %msg = new_message(
          id       = 'ZRAILWAY_MSG'
          number   = lv_msg_number
          severity = if_abap_behv_message=>severity-error
        )
      ) TO reported-railway_ord.

      CONTINUE.
    ENDIF.

    DATA(lv_header_cid) = |RH_{ ls_header-confirmid }|.
    DATA(lv_item_cid)   = |RI_{ ls_header-confirmid }|.

    "One batch receipt for the selected receipt quantity.
    "No serial-number children are created.
    MODIFY ENTITIES OF i_materialdocumenttp

      ENTITY materialdocument
        CREATE FIELDS (
          documentdate
          postingdate
          goodsmovementcode
        )
        WITH VALUE #(
          (
            %cid              = lv_header_cid
            documentdate      = ls_header-postingdate
            postingdate       = ls_header-postingdate
            goodsmovementcode = '02'
          )
        )

        CREATE BY \_materialdocumentitem
          FIELDS (
            material
            plant
            storagelocation
            batch
            goodsmovementtype
            manufacturingorder
            manufacturingorderitem
            goodsmovementrefdoctype
            quantityinentryunit
            entryunit
          )
          WITH VALUE #(
            (
              %cid_ref = lv_header_cid
              %target = VALUE #(
                (
                  %cid                    = lv_item_cid
                  material                = ls_header-material
                  plant                   = ls_header-plant
                  storagelocation         = lv_storage_location
                  batch                   = ls_header-batch_number
                  goodsmovementtype       = '101'
                  manufacturingorder      = lv_order
                  manufacturingorderitem  = '0001'
                  goodsmovementrefdoctype = 'F'
                  quantityinentryunit     = ls_header-QtyToConfirm
                  entryunit               = ls_header-unit
                )
              )
            )
          )

      MAPPED DATA(ls_md_mapped)
      FAILED DATA(ls_md_failed)
      REPORTED DATA(ls_md_reported).

    LOOP AT ls_md_reported-materialdocument
      INTO DATA(ls_header_message).

      IF ls_header_message-%msg IS BOUND.
        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = ls_header_message-%msg
        ) TO reported-railway_ord.
      ENDIF.

    ENDLOOP.

    LOOP AT ls_md_reported-materialdocumentitem
      INTO DATA(ls_item_message).

      IF ls_item_message-%msg IS BOUND.
        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = ls_item_message-%msg
        ) TO reported-railway_ord.
      ENDIF.

    ENDLOOP.

    IF ls_md_failed IS NOT INITIAL.

      APPEND VALUE #(
        %tky = ls_header-%tky
      ) TO failed-railway_ord.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %msg = new_message(
          id       = 'ZRAILWAY_MSG'
          number   = '061'
          severity = if_abap_behv_message=>severity-error
        )
      ) TO reported-railway_ord.

      CONTINUE.
    ENDIF.

    READ TABLE ls_md_mapped-materialdocument
      INTO DATA(ls_created_document)
      WITH KEY %cid = lv_header_cid.

    IF sy-subrc <> 0.

      APPEND VALUE #(
        %tky = ls_header-%tky
      ) TO failed-railway_ord.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %msg = new_message(
          id       = 'ZRAILWAY_MSG'
          number   = '062'
          severity = if_abap_behv_message=>severity-error
        )
      ) TO reported-railway_ord.

      CONTINUE.
    ENDIF.

    APPEND VALUE #(
      confirm_id = ls_header-confirmid
      pid        = ls_created_document-%pid
    ) TO lcl_rejection_material_buffer=>entries.

    "Ensure this header participates in the custom save sequence.
    "Keep SerialsPosted unchanged.
       "Set POSTED after successful rejection processing.
    MODIFY ENTITIES OF zi_railway_ord IN LOCAL MODE
      ENTITY railway_ord
        UPDATE FIELDS ( Status )
        WITH VALUE #(
          (
            %tky   = ls_header-%tky
            Status = 'POSTED'
          )
        )
      FAILED DATA(ls_update_failed)
      REPORTED DATA(ls_update_reported).

    APPEND LINES OF ls_update_failed-railway_ord
      TO failed-railway_ord.
    APPEND LINES OF ls_update_reported-railway_ord
      TO reported-railway_ord.

    IF ls_update_failed IS NOT INITIAL.
      CONTINUE.
    ENDIF.

      READ ENTITIES OF zi_railway_ord IN LOCAL MODE
      ENTITY railway_ord
        ALL FIELDS
        WITH VALUE #( ( %tky = ls_header-%tky ) )
      RESULT DATA(lt_updated_headers).

    LOOP AT lt_updated_headers INTO DATA(ls_updated_header).

      APPEND VALUE #(
        %tky   = ls_updated_header-%tky
        %param = ls_updated_header
      ) TO result.

    ENDLOOP.
    APPEND VALUE #(
      %tky = ls_header-%tky
      %msg = new_message(
        id       = 'ZRAILWAY_MSG'
        number   = '063'
        severity = if_abap_behv_message=>severity-information
      )
    ) TO reported-railway_ord.

  ENDLOOP.

ENDMETHOD.



METHOD cancelrejection.

  READ ENTITIES OF zi_railway_ord IN LOCAL MODE
    ENTITY railway_ord
      ALL FIELDS
      WITH CORRESPONDING #( keys )
    RESULT DATA(lt_headers)
    FAILED DATA(ls_read_failed)
    REPORTED DATA(ls_read_reported).

  APPEND LINES OF ls_read_failed-railway_ord
    TO failed-railway_ord.

  APPEND LINES OF ls_read_reported-railway_ord
    TO reported-railway_ord.

  DATA(lv_reversal_date) =
    cl_abap_context_info=>get_system_date( ).

  LOOP AT lt_headers INTO DATA(ls_header).

    DATA(lv_msg_number) = CONV symsgno( '' ).

    "Validate the saved rejection document.
    IF ls_header-%is_draft = if_abap_behv=>mk-on.

      lv_msg_number = '043'.

    ELSEIF ls_header-materialdocument IS INITIAL
        OR ls_header-materialdocumentyear IS INITIAL.

      lv_msg_number = '044'.

    ENDIF.

    IF lv_msg_number IS NOT INITIAL.

      APPEND VALUE #(
        %tky = ls_header-%tky
      ) TO failed-railway_ord.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %msg = new_message(
          id       = 'ZRAILWAY_MSG'
          number   = lv_msg_number
          severity = if_abap_behv_message=>severity-error
        )
      ) TO reported-railway_ord.

      CONTINUE.

    ENDIF.

    "Cancel the original document.
    "SAP reverses its original batch and quantity.
    MODIFY ENTITIES OF i_materialdocumenttp
      ENTITY materialdocument
        EXECUTE cancel
        FROM VALUE #(
          (
            %tky-materialdocument =
              ls_header-materialdocument

            %tky-materialdocumentyear =
              ls_header-materialdocumentyear

            %tky-%is_draft =
              if_abap_behv=>mk-off

            %param-postingdate =
              lv_reversal_date
          )
        )
      RESULT DATA(lt_cancel_result)
      FAILED DATA(ls_cancel_failed)
      REPORTED DATA(ls_cancel_reported).

    "Forward material document header messages.
    LOOP AT ls_cancel_reported-materialdocument
      INTO DATA(ls_header_message).

      IF ls_header_message-%msg IS BOUND.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = ls_header_message-%msg
        ) TO reported-railway_ord.

      ENDIF.

    ENDLOOP.

    "Forward material document item messages.
    LOOP AT ls_cancel_reported-materialdocumentitem
      INTO DATA(ls_item_message).

      IF ls_item_message-%msg IS BOUND.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = ls_item_message-%msg
        ) TO reported-railway_ord.

      ENDIF.

    ENDLOOP.

    IF ls_cancel_failed IS NOT INITIAL.

      APPEND VALUE #(
        %tky = ls_header-%tky
      ) TO failed-railway_ord.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %msg = new_message(
          id       = 'ZRAILWAY_MSG'
          number   = '064'
          severity = if_abap_behv_message=>severity-error
        )
      ) TO reported-railway_ord.

      CONTINUE.

    ENDIF.

    "Retain the original document reference for traceability.
    "The production confirmation status is unchanged.
    APPEND VALUE #(
      %tky   = ls_header-%tky
      %param = ls_header
    ) TO result.

    APPEND VALUE #(
      %tky = ls_header-%tky
      %msg = new_message(
        id       = 'ZRAILWAY_MSG'
        number   = '065'
        severity = if_abap_behv_message=>severity-success
        v1       = ls_header-materialdocument
        v2       = ls_header-materialdocumentyear
      )
    ) TO reported-railway_ord.

  ENDLOOP.

ENDMETHOD.

ENDCLASS.


CLASS lsc_zi_railway_ord DEFINITION
  INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.
    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.


CLASS lsc_zi_railway_ord IMPLEMENTATION.

  METHOD save_modified.

  LOOP AT lcl_confirmation_buffer=>entries
    INTO DATA(ls_entry).

    CONVERT KEY OF i_productionordconfirmationtp
      FROM ls_entry-pid
      TO DATA(ls_confirmation_key).

    UPDATE ztb_railway_ord
      SET confirmation_group =
            @ls_confirmation_key-confirmationgroup,
          confirmation_count =
            @ls_confirmation_key-confirmationcount
      WHERE confirm_id = @ls_entry-confirm_id.

  ENDLOOP.

  LOOP AT lcl_rejection_material_buffer=>entries
    INTO DATA(ls_rejection_entry).

    CONVERT KEY OF i_materialdocumenttp
      FROM ls_rejection_entry-pid
      TO DATA(ls_rejection_document_key).

    UPDATE ztb_railway_ord
      SET material_document =
            @ls_rejection_document_key-materialdocument,
          material_document_year =
            @ls_rejection_document_key-materialdocumentyear
      WHERE confirm_id = @ls_rejection_entry-confirm_id.

  ENDLOOP.

ENDMETHOD.


  METHOD cleanup_finalize.

       CLEAR:
    lcl_confirmation_buffer=>entries,
    lcl_rejection_material_buffer=>entries.

  ENDMETHOD.

ENDCLASS.





*CLASS lcl_confirmation_buffer DEFINITION.
*  PUBLIC SECTION.
*
*    TYPES:
*      BEGIN OF ty_entry,
*        confirm_id TYPE sysuuid_x16,
*        pid        TYPE abp_behv_pid,
*      END OF ty_entry.
*
*    CLASS-DATA entries TYPE STANDARD TABLE OF ty_entry
*      WITH EMPTY KEY.
*
*ENDCLASS.
*
*CLASS lcl_confirmation_buffer IMPLEMENTATION.
*ENDCLASS.
*
*CLASS lcl_rejection_material_buffer DEFINITION.
*  PUBLIC SECTION.
*
*    TYPES:
*      BEGIN OF ty_entry,
*        confirm_id TYPE sysuuid_x16,
*        pid        TYPE abp_behv_pid,
*      END OF ty_entry.
*
*    CLASS-DATA entries
*      TYPE STANDARD TABLE OF ty_entry WITH EMPTY KEY.
*
*ENDCLASS.
*
*CLASS lcl_rejection_material_buffer IMPLEMENTATION.
*ENDCLASS.
*
*CLASS lhc_railway_ord DEFINITION
*  INHERITING FROM cl_abap_behavior_handler.
*
*  PRIVATE SECTION.
*
*    METHODS get_instance_authorizations
*      FOR INSTANCE AUTHORIZATION
*      IMPORTING keys
*        REQUEST requested_authorizations
*        FOR railway_ord
*      RESULT result.
*
*   METHODS get_instance_features
*  FOR INSTANCE FEATURES
*  IMPORTING keys REQUEST requested_features
*    FOR railway_ord
*  RESULT result.
*
*    METHODS setinitialstatus
*      FOR DETERMINE ON MODIFY
*      IMPORTING keys
*        FOR railway_ord~setinitialstatus.
*
*    METHODS invalidateorderfetch
*      FOR DETERMINE ON MODIFY
*      IMPORTING keys
*        FOR railway_ord~invalidateorderfetch.
*
*    METHODS validateorderfetched
*      FOR VALIDATE ON SAVE
*      IMPORTING keys
*        FOR railway_ord~validateorderfetched.
*
*    METHODS validatetotalquantity
*      FOR VALIDATE ON SAVE
*      IMPORTING keys
*        FOR railway_ord~validatetotalquantity.
*
*        METHODS ValidateRejectionReason
*  FOR VALIDATE ON SAVE
*  IMPORTING keys
*    FOR railway_ord~ValidateRejectionReason.
*
*    METHODS validateserialcount
*      FOR VALIDATE ON SAVE
*      IMPORTING keys
*        FOR railway_ord~validateserialcount.
*
*    METHODS fetchorderdata
*      FOR MODIFY
*      IMPORTING keys
*        FOR ACTION railway_ord~fetchorderdata
*      RESULT result.
*
*    METHODS submitandpost
*      FOR MODIFY
*      IMPORTING keys
*        FOR ACTION railway_ord~submitandpost
*      RESULT result.
*
*    METHODS cancelconfirmation
*      FOR MODIFY
*      IMPORTING keys
*        FOR ACTION railway_ord~cancelconfirmation
*      RESULT result.
*
*      METHODS postrejection
*  FOR MODIFY
*  IMPORTING keys FOR ACTION railway_ord~PostRejection
*  RESULT result.
*
*  METHODS cancelrejection
*  FOR MODIFY
*  IMPORTING keys FOR ACTION railway_ord~CancelRejection
*  RESULT result.
*
*ENDCLASS.
*
*
*CLASS lhc_railway_ord IMPLEMENTATION.
*
*  METHOD get_instance_authorizations.
*
*  READ ENTITIES OF zi_railway_ord IN LOCAL MODE
*    ENTITY railway_ord
*      FIELDS ( orderno status )
*      WITH CORRESPONDING #( keys )
*    RESULT DATA(lt_orders).
*
*  result = VALUE #(
*    FOR ls_order IN lt_orders
*    (
*      %tky = ls_order-%tky
*
*      %update = COND #(
*        WHEN requested_authorizations-%update =
*             if_abap_behv=>mk-on
*        THEN COND #(
*          WHEN ls_order-orderno IS INITIAL
*            OR ls_order-status = 'CREATED'
*          THEN if_abap_behv=>auth-allowed
*          ELSE if_abap_behv=>auth-unauthorized
*        )
*      )
*
*      %delete = COND #(
*        WHEN requested_authorizations-%delete =
*             if_abap_behv=>mk-on
*        THEN COND #(
*          WHEN ls_order-orderno IS INITIAL
*            OR ls_order-status = 'CREATED'
*          THEN if_abap_behv=>auth-allowed
*          ELSE if_abap_behv=>auth-unauthorized
*        )
*      )
*      %action-PostRejection = COND #(
*  WHEN requested_authorizations-%action-PostRejection =
*       if_abap_behv=>mk-on
*  THEN COND #(
*    WHEN ls_order-%is_draft = if_abap_behv=>mk-off
*      AND ( ls_order-status = 'POSTED'
*         OR ls_order-status = 'PART_POST' )
*    THEN if_abap_behv=>auth-allowed
*    ELSE if_abap_behv=>auth-unauthorized
*  )
*)
*    )
*  ).
*
*ENDMETHOD.
*
*  METHOD get_instance_features.
*
*  READ ENTITIES OF zi_railway_ord IN LOCAL MODE
*    ENTITY railway_ord
*      FIELDS (
*        orderno
*        status
*        confirmationgroup
*        confirmationcount
*        materialdocument
*        materialdocumentyear
*      )
*      WITH CORRESPONDING #( keys )
*    RESULT DATA(lt_orders).
*
*  result = VALUE #(
*    FOR ls_order IN lt_orders
*    (
*      %tky = ls_order-%tky
*
*      %features-%delete = COND #(
*        WHEN ls_order-orderno IS INITIAL
*          OR ls_order-status = 'CREATED'
*        THEN if_abap_behv=>fc-o-enabled
*        ELSE if_abap_behv=>fc-o-disabled
*      )
*
*      %features-%action-Edit = COND #(
*        WHEN ls_order-%is_draft = if_abap_behv=>mk-off
*         AND ( ls_order-orderno IS INITIAL
*            OR ls_order-status = 'CREATED' )
*        THEN if_abap_behv=>fc-o-enabled
*        ELSE if_abap_behv=>fc-o-disabled
*      )
*
*      " Post the production confirmation
*      %features-%action-SubmitAndPost = COND #(
*        WHEN ls_order-%is_draft = if_abap_behv=>mk-off
*         AND ls_order-status = 'CREATED'
*        THEN if_abap_behv=>fc-o-enabled
*        ELSE if_abap_behv=>fc-o-disabled
*      )
*
*      " Post batch goods receipt after confirmation
*      %features-%action-postrejection = COND #(
*        WHEN ls_order-%is_draft = if_abap_behv=>mk-off
*         AND ( ls_order-status = 'POSTED'
*            OR ls_order-status = 'PART_POST' )
*         AND ls_order-materialdocument IS INITIAL
*        THEN if_abap_behv=>fc-o-enabled
*        ELSE if_abap_behv=>fc-o-disabled
*      )
*
*      " Cancel the production confirmation
*      %features-%action-CancelConfirmation = COND #(
*        WHEN ls_order-%is_draft = if_abap_behv=>mk-off
*         AND ls_order-status = 'POSTED'
*         AND ls_order-confirmationgroup IS NOT INITIAL
*         AND ls_order-confirmationcount IS NOT INITIAL
*        THEN if_abap_behv=>fc-o-enabled
*        ELSE if_abap_behv=>fc-o-disabled
*      )
*
*      " Cancel the assigned goods receipt material document
*      %features-%action-CancelRejection = COND #(
*        WHEN ls_order-%is_draft = if_abap_behv=>mk-off
*         AND ls_order-materialdocument IS NOT INITIAL
*         AND ls_order-materialdocumentyear IS NOT INITIAL
*        THEN if_abap_behv=>fc-o-enabled
*        ELSE if_abap_behv=>fc-o-disabled
*      )
*    )
*  ).
*
*ENDMETHOD.
*
* METHOD setinitialstatus.
*
*  MODIFY ENTITIES OF zi_railway_ord IN LOCAL MODE
*    ENTITY railway_ord
*      UPDATE FIELDS ( status )
*      WITH VALUE #(
*        FOR key IN keys
*        (
*          %tky = key-%tky
*          status = 'CREATED'
*        )
*      ).
*
*ENDMETHOD.
*
*  METHOD invalidateorderfetch.
*
*    READ ENTITIES OF zi_railway_ord IN LOCAL MODE
*      ENTITY railway_ord
*        FIELDS ( fetchedorderno )
*        WITH CORRESPONDING #( keys )
*      RESULT DATA(lt_headers).
*
*    MODIFY ENTITIES OF zi_railway_ord IN LOCAL MODE
*      ENTITY railway_ord
*        UPDATE FIELDS ( fetchedorderno )
*        WITH VALUE #(
*          FOR ls_header IN lt_headers
*          WHERE (
*            %is_draft = if_abap_behv=>mk-on
*            AND fetchedorderno IS NOT INITIAL
*          )
*          (
*            %tky           = ls_header-%tky
*            fetchedorderno = ''
*          )
*        ).
*
*  ENDMETHOD.
*
*  METHOD validateorderfetched.
*
*    READ ENTITIES OF zi_railway_ord IN LOCAL MODE
*      ENTITY railway_ord
*        FIELDS ( orderno fetchedorderno status )
*        WITH CORRESPONDING #( keys )
*      RESULT DATA(lt_headers).
*
*    LOOP AT lt_headers INTO DATA(ls_header).
*
*      "Clear previous validation messages
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*        %state_area = 'ORDER_FETCH'
*      ) TO reported-railway_ord.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*        %state_area = 'REMAINING_QUANTITY'
*      ) TO reported-railway_ord.
*
*      "Apply only to new confirmations
*      IF ls_header-status IS NOT INITIAL
*         AND ls_header-status <> 'CREATED'.
*        CONTINUE.
*      ENDIF.
*
*      DATA(lv_order_no) = ls_header-orderno.
*      DATA(lv_fetched_order_no) = ls_header-fetchedorderno.
*
*      lv_order_no = |{ lv_order_no ALPHA = IN }|.
*      lv_fetched_order_no = |{ lv_fetched_order_no ALPHA = IN }|.
*
*      IF ls_header-orderno IS INITIAL
*         OR ls_header-fetchedorderno IS INITIAL
*         OR lv_order_no <> lv_fetched_order_no.
*
*        APPEND VALUE #(
*          %tky = ls_header-%tky
*        ) TO failed-railway_ord.
*
*        APPEND VALUE #(
*          %tky = ls_header-%tky
*          %state_area = 'ORDER_FETCH'
*          %element-orderno = if_abap_behv=>mk-on
*          %msg = new_message_with_text(
*            severity = if_abap_behv_message=>severity-error
*            text = 'Click Fetch Order Data before saving'
*          )
*        ) TO reported-railway_ord.
*
*        CONTINUE.
*      ENDIF.
*
*      "Read current quantities; avoid DCL checks in save validation
*      SELECT SINGLE
*        FROM i_manufacturingorder WITH PRIVILEGED ACCESS
*        FIELDS mfgorderplannedtotalqty,
*               mfgorderconfirmedyieldqty,
*               mfgorderconfirmedscrapqty
*        WHERE manufacturingorder = @lv_order_no
*        INTO @DATA(ls_current_order).
*
*      DATA(lv_error) = CONV string( '' ).
*
*      IF sy-subrc <> 0.
*        lv_error = 'Production order not found'.
*      ELSE.
*
*        DATA(lv_remaining_qty) =
*            ls_current_order-mfgorderplannedtotalqty
*          - ls_current_order-mfgorderconfirmedyieldqty
*          - ls_current_order-mfgorderconfirmedscrapqty.
*
*        IF lv_remaining_qty <= 0.
*          lv_error =
*            'No remaining quantity,Cannot create order.'.
*        ENDIF.
*
*      ENDIF.
*
*      IF lv_error IS NOT INITIAL.
*
*        APPEND VALUE #(
*          %tky = ls_header-%tky
*        ) TO failed-railway_ord.
*
*        APPEND VALUE #(
*          %tky = ls_header-%tky
*          %state_area = 'REMAINING_QUANTITY'
*          %element-orderno = if_abap_behv=>mk-on
*          %msg = new_message_with_text(
*            severity = if_abap_behv_message=>severity-error
*            text = lv_error
*          )
*        ) TO reported-railway_ord.
*
*      ENDIF.
*
*    ENDLOOP.
*
*  ENDMETHOD.
*
*  METHOD validatetotalquantity.
*
*    READ ENTITIES OF zi_railway_ord IN LOCAL MODE
*      ENTITY railway_ord
*        FIELDS ( qtytoconfirm scrapqty remainingqty )
*        WITH CORRESPONDING #( keys )
*      RESULT DATA(lt_headers).
*
*    LOOP AT lt_headers INTO DATA(ls_header).
*
*      "Clear the previous validation message
*      APPEND VALUE #(
*        %tky        = ls_header-%tky
*        %state_area = 'TOTAL_QUANTITY'
*      ) TO reported-railway_ord.
*
*      DATA(lv_total) =
*        CONV decfloat34( ls_header-qtytoconfirm )
*        + CONV decfloat34( ls_header-scrapqty ).
*
*      DATA(lv_error) = CONV string( '' ).
*
*      IF ls_header-qtytoconfirm < 0
*         OR ls_header-scrapqty < 0.
*
*        lv_error = 'Quantities cannot be negative'.
*
*      ELSEIF lv_total > ls_header-remainingqty.
*
*        lv_error =
*          'Quantity to confirm plus scrap quantity cannot exceed remaining quantity'.
*
*      ENDIF.
*
*      IF lv_error IS NOT INITIAL.
*
*        APPEND VALUE #(
*          %tky = ls_header-%tky
*        ) TO failed-railway_ord.
*
*        APPEND VALUE #(
*          %tky                  = ls_header-%tky
*          %state_area           = 'TOTAL_QUANTITY'
*          %element-qtytoconfirm = if_abap_behv=>mk-on
*          %element-scrapqty     = if_abap_behv=>mk-on
*          %msg = new_message_with_text(
*            severity = if_abap_behv_message=>severity-error
*            text     = lv_error
*          )
*        ) TO reported-railway_ord.
*
*      ENDIF.
*
*    ENDLOOP.
*
*  ENDMETHOD.
*
*  METHOD ValidateRejectionReason.
*
*  READ ENTITIES OF zi_railway_ord IN LOCAL MODE
*    ENTITY railway_ord
*      FIELDS ( ScrapQty )
*      WITH CORRESPONDING #( keys )
*    RESULT DATA(lt_headers).
*
*  LOOP AT lt_headers INTO DATA(ls_header).
*
*      "Check during active save, not draft editing or preparation.
*    IF ls_header-%is_draft = if_abap_behv=>mk-on.
*      CONTINUE.
*    ENDIF.
*
*    "No rejection reason is required without scrap.
*    IF ls_header-ScrapQty <= 0.
*      CONTINUE.
*    ENDIF.
*
*    READ ENTITIES OF zi_railway_ord IN LOCAL MODE
*      ENTITY railway_ord BY \_REJECTION
*        ALL FIELDS
*        WITH VALUE #(
*          ( %tky = ls_header-%tky )
*        )
*      RESULT DATA(lt_rejections)
*      FAILED DATA(ls_item_read_failed).
*
*    IF ls_item_read_failed IS NOT INITIAL
*       OR lt_rejections IS INITIAL.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*      ) TO failed-railway_ord.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*        %element-ScrapQty = if_abap_behv=>mk-on
*        %msg = new_message_with_text(
*          severity = if_abap_behv_message=>severity-error
*          text = 'KINDLY SELECT REJECTION REASON'
*        )
*      ) TO reported-railway_ord.
*
*      CONTINUE.
*    ENDIF.
*
*    DATA(lv_reason_missing) = abap_false.
*
*    LOOP AT lt_rejections INTO DATA(ls_rejection).
*
*      IF ls_rejection-RejectionReason IS INITIAL.
*        lv_reason_missing = abap_true.
*        EXIT.
*      ENDIF.
*
*    ENDLOOP.
*
*    IF lv_reason_missing = abap_true.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*      ) TO failed-railway_ord.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*        %msg = new_message_with_text(
*          severity = if_abap_behv_message=>severity-error
*          text = 'KINDLY SELECT REJECTION REASON'
*        )
*      ) TO reported-railway_ord.
*
*    ENDIF.
*
*  ENDLOOP.
*
*ENDMETHOD.
*
*
*
*  METHOD validateserialcount.
*ENDMETHOD.
*
* METHOD fetchorderdata.
*
*  READ ENTITIES OF zi_railway_ord IN LOCAL MODE
*    ENTITY railway_ord
*      FIELDS ( orderno scrapqty qtytoconfirm )
*      WITH CORRESPONDING #( keys )
*    RESULT DATA(lt_headers)
*    FAILED failed.
*
*  LOOP AT lt_headers INTO DATA(ls_header).
*
*    DATA(lv_error) = CONV string( '' ).
*
*    IF ls_header-orderno IS INITIAL.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*      ) TO failed-railway_ord.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*        %element-orderno = if_abap_behv=>mk-on
*        %msg = new_message_with_text(
*          severity = if_abap_behv_message=>severity-error
*          text = 'Please enter Order Number'
*        )
*      ) TO reported-railway_ord.
*
*      CONTINUE.
*    ENDIF.
*
*    DATA(lv_order_no) = ls_header-orderno.
*    lv_order_no = |{ lv_order_no ALPHA = IN }|.
*
*    "Read manufacturing order
*    SELECT SINGLE
*      FROM i_manufacturingorder
*      FIELDS material,
*             batch,
*             mfgorderscheduledstartdate,
*             mfgorderscheduledenddate,
*             productionplant,
*             manufacturingordertype,
*             mfgorderplannedtotalqty,
*             mfgorderconfirmedyieldqty,
*             mfgorderconfirmedscrapqty
*      WHERE manufacturingorder = @lv_order_no
*      INTO @DATA(ls_order).
*
*    IF sy-subrc <> 0.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*      ) TO failed-railway_ord.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*        %element-orderno = if_abap_behv=>mk-on
*        %msg = new_message_with_text(
*          severity = if_abap_behv_message=>severity-error
*          text = |Order { ls_header-orderno } not found|
*        )
*      ) TO reported-railway_ord.
*
*      CONTINUE.
*    ENDIF.
*
*          "Railway and Disc product group validation
*      DATA lv_product_group TYPE i_product-productgroup.
*      CLEAR lv_product_group.
*
*      SELECT SINGLE
*        FROM i_product
*        FIELDS productgroup
*        WHERE product = @ls_order-material
*        INTO @lv_product_group.
*
*      IF sy-subrc <> 0
*         OR lv_product_group IS INITIAL
*         OR ( lv_product_group <> 'H151'
*          AND lv_product_group <> 'H140'
*          AND lv_product_group <> 'H138'
*          AND lv_product_group <> 'H149' ).
*
*        APPEND VALUE #(
*          %tky = ls_header-%tky
*        ) TO failed-railway_ord.
*
*        APPEND VALUE #(
*          %tky = ls_header-%tky
*          %element-orderno = if_abap_behv=>mk-on
*          %msg = new_message_with_text(
*            severity = if_abap_behv_message=>severity-error
*            text = 'This App only for Railway & Disc Confirmation'
*          )
*        ) TO reported-railway_ord.
*
*        CONTINUE.
*      ENDIF.
*
*      "Check remaining goods issue: 261 minus 262.
*      SELECT
*        FROM i_materialdocumentitem_2
*        FIELDS material,
*               plant,
*               materialbaseunit,
*               SUM(
*                 CASE
*                   WHEN goodsmovementtype = '261'
*                     THEN quantityinbaseunit
*                   ELSE - quantityinbaseunit
*                 END
*               ) AS net_issue_qty
*        WHERE manufacturingorder = @lv_order_no
*          AND ( goodsmovementtype = '261'
*             OR goodsmovementtype = '262' )
*        GROUP BY material,
*                 plant,
*                 materialbaseunit
*        INTO TABLE @DATA(lt_goods_issue).
*
*      DATA lv_goods_issue_exists TYPE abap_bool.
*      CLEAR lv_goods_issue_exists.
*
*      LOOP AT lt_goods_issue INTO DATA(ls_goods_issue).
*
*        IF ls_goods_issue-net_issue_qty > 0.
*          lv_goods_issue_exists = abap_true.
*          EXIT.
*        ENDIF.
*
*      ENDLOOP.
*
*      IF lv_goods_issue_exists = abap_false.
*
*        APPEND VALUE #(
*          %tky = ls_header-%tky
*        ) TO failed-railway_ord.
*
*        APPEND VALUE #(
*          %tky = ls_header-%tky
*          %element-orderno = if_abap_behv=>mk-on
*          %msg = new_message_with_text(
*            severity = if_abap_behv_message=>severity-error
*            text = 'GOODS ISSUE PENDING'
*          )
*        ) TO reported-railway_ord.
*
*        CONTINUE.
*      ENDIF.
*
*
*    "Check released status
*    SELECT SINGLE
*      FROM i_manufacturingorderstatus
*      FIELDS statuscode,
*             statusisactive
*      WHERE manufacturingorder = @lv_order_no
*        AND statuscode = 'I0002'
*      INTO @DATA(ls_release_status).
*
*    IF sy-subrc <> 0
*       OR ls_release_status-statusisactive IS INITIAL.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*      ) TO failed-railway_ord.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*        %element-orderno = if_abap_behv=>mk-on
*        %msg = new_message_with_text(
*          severity = if_abap_behv_message=>severity-error
*          text = |Release production order { ls_header-orderno }|
*        )
*      ) TO reported-railway_ord.
*
*      CONTINUE.
*    ENDIF.
*
*    IF ls_order-batch IS INITIAL.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*      ) TO failed-railway_ord.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*        %element-batch_number = if_abap_behv=>mk-on
*        %msg = new_message_with_text(
*          severity = if_abap_behv_message=>severity-error
*          text = |Kindly assign batch to production order { ls_header-orderno }|
*        )
*      ) TO reported-railway_ord.
*
*      CONTINUE.
*    ENDIF.
*
*    DATA(lv_remaining_qty) =
*        ls_order-mfgorderplannedtotalqty
*      - ls_order-mfgorderconfirmedyieldqty
*      - ls_order-mfgorderconfirmedscrapqty.
*
*    IF lv_remaining_qty <= 0.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*      ) TO failed-railway_ord.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*        %element-orderno = if_abap_behv=>mk-on
*        %msg = new_message_with_text(
*          severity = if_abap_behv_message=>severity-error
*          text = |Order { ls_header-orderno } has no remaining quantity. Cannot create another confirmation.|
*        )
*      ) TO reported-railway_ord.
*
*      CONTINUE.
*    ENDIF.
*
*    "Material description
*    DATA lv_mat_desc TYPE
*      i_productdescription-productdescription.
*
*    CLEAR lv_mat_desc.
*
*    SELECT SINGLE
*      FROM i_productdescription
*      FIELDS productdescription
*      WHERE product = @ls_order-material
*        AND language = @sy-langu
*      INTO @lv_mat_desc.
*
*    "Keep the operation-selection logic from the original method
*    SELECT SINGLE
*      FROM i_manufacturingorderoperation
*      FIELDS manufacturingorderoperation_2,
*             workcenterinternalid,
*             productionunit,
*             opqtytobaseqtydnmntr,
*             opqtytobaseqtynmrtr
*      WHERE manufacturingorder = @lv_order_no
*      INTO @DATA(lv_operation).
*
*    IF sy-subrc <> 0
*       OR lv_operation-opqtytobaseqtynmrtr = 0.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*      ) TO failed-railway_ord.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*        %msg = new_message_with_text(
*          severity = if_abap_behv_message=>severity-error
*          text = 'Operation missing or quantity conversion denominator is zero'
*        )
*      ) TO reported-railway_ord.
*
*      CONTINUE.
*    ENDIF.
*
*    DATA lv_workcenter TYPE i_workcenter-workcenter.
*    CLEAR lv_workcenter.
*
*    SELECT SINGLE
*      FROM i_workcenter
*      FIELDS workcenter
*      WHERE workcenterinternalid =
*              @lv_operation-workcenterinternalid
*      INTO @lv_workcenter.
*
*    DATA(lv_confirmed_qty_wt) =
*      ( CONV decfloat34( ls_header-qtytoconfirm )
*        + CONV decfloat34( ls_header-scrapqty ) )
*      * ( CONV decfloat34(
*            lv_operation-opqtytobaseqtydnmntr )
*          / CONV decfloat34(
*            lv_operation-opqtytobaseqtynmrtr ) ).
*
*    "Update railway header
*    MODIFY ENTITIES OF zi_railway_ord IN LOCAL MODE
*      ENTITY railway_ord
*        UPDATE FIELDS (
*          material
*          mat_desc
*          plant
*          batch_number
*          postingdate
*          start_end_date
*          unit
*          displayunit
*          order_type
*          orderqty
*          confirmedqty
*          confirmedscrapqty
*          remainingqty
*          operation
*          workcenter
*          weightqty
*        )
*        WITH VALUE #(
*          (
*            %tky = ls_header-%tky
*            material = ls_order-material
*            mat_desc = lv_mat_desc
*            plant = ls_order-productionplant
*            batch_number = ls_order-batch
*            postingdate =
*              ls_order-mfgorderscheduledstartdate
*            start_end_date =
*              ls_order-mfgorderscheduledenddate
*            unit = lv_operation-productionunit
*            displayunit = COND #(
*              WHEN lv_operation-productionunit = 'ST'
*              THEN 'PC'
*              ELSE lv_operation-productionunit
*            )
*            order_type = ls_order-manufacturingordertype
*            orderqty = ls_order-mfgorderplannedtotalqty
*            confirmedqty =
*              ls_order-mfgorderconfirmedyieldqty
*            confirmedscrapqty =
*              ls_order-mfgorderconfirmedscrapqty
*            remainingqty = lv_remaining_qty
*            operation =
*              lv_operation-manufacturingorderoperation_2
*            workcenter = lv_workcenter
*            weightqty = lv_confirmed_qty_wt
*          )
*        )
*      FAILED DATA(ls_header_update_failed)
*      REPORTED DATA(ls_header_update_reported).
*
*    APPEND LINES OF
*      ls_header_update_failed-railway_ord
*      TO failed-railway_ord.
*
*    APPEND LINES OF
*      ls_header_update_reported-railway_ord
*      TO reported-railway_ord.
*
*    IF ls_header_update_failed IS NOT INITIAL.
*      CONTINUE.
*    ENDIF.
*
*    "Read scrap components
*    SELECT FROM i_productionordercomponent AS comp
*      LEFT OUTER JOIN i_productdescription AS txt
*        ON txt~product = comp~material
*       AND txt~language = @sy-langu
*      FIELDS
*        comp~material,
*        txt~productdescription,
*        comp~storagelocation,
*        comp~requiredquantity,
*        comp~baseunit
*      WHERE comp~productionorder = @lv_order_no
*        AND comp~goodsmovementtype = '531'
*      INTO TABLE @DATA(lt_scrap_components).
*
*    DELETE lt_scrap_components WHERE material IS INITIAL.
*
*    "Read activity source before replacing child rows
*    SELECT FROM i_manufacturingorderoperation AS op
*      LEFT OUTER JOIN i_standardworkfmlaparamgroup AS grp
*        ON grp~standardworkformulaparamgroup =
*             op~standardworkformulaparamgroup
*      FIELDS
*        op~manufacturingorderoperation_2 AS operation,
*        op~operationreferencequantity,
*        op~workcenterstandardworkqty1,
*        op~workcenterstandardworkqty2,
*        op~workcenterstandardworkqty3,
*        op~workcenterstandardworkqty4,
*        op~workcenterstandardworkqty5,
*        op~workcenterstandardworkqty6,
*        op~workcenterstandardworkqtyunit1,
*        op~workcenterstandardworkqtyunit2,
*        op~workcenterstandardworkqtyunit3,
*        op~workcenterstandardworkqtyunit4,
*        op~workcenterstandardworkqtyunit5,
*        op~workcenterstandardworkqtyunit6,
*        grp~standardworkformulaparam1,
*        grp~standardworkformulaparam2,
*        grp~standardworkformulaparam3,
*        grp~standardworkformulaparam4,
*        grp~standardworkformulaparam5,
*        grp~standardworkformulaparam6
*      WHERE op~manufacturingorder = @lv_order_no
*        AND op~manufacturingorderoperation_2 =
*              @lv_operation-manufacturingorderoperation_2
*      INTO TABLE @DATA(lt_activity_source).
*
*    CLEAR lv_error.
*
*    IF lines( lt_activity_source ) > 1.
*      lv_error =
*        'Multiple operation records found; refine the operation selection'.
*
*    ELSEIF lt_activity_source IS INITIAL.
*      lv_error = 'No production activity source found'.
*    ENDIF.
*
*    DATA ls_activity_source LIKE LINE OF lt_activity_source.
*    CLEAR ls_activity_source.
*
*    IF lv_error IS INITIAL.
*
*      READ TABLE lt_activity_source INDEX 1
*        INTO ls_activity_source.
*
*      IF ls_activity_source-operationreferencequantity <= 0.
*        lv_error =
*          'Operation reference quantity must be greater than zero'.
*      ENDIF.
*
*    ENDIF.
*
*    IF lv_error IS NOT INITIAL.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*      ) TO failed-railway_ord.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*        %msg = new_message_with_text(
*          severity = if_abap_behv_message=>severity-error
*          text = lv_error
*        )
*      ) TO reported-railway_ord.
*
*      CONTINUE.
*    ENDIF.
*
*    "Build railway activity rows
*    DATA:
*      lv_activity_slot  TYPE n LENGTH 1,
*      lv_activity_param TYPE ztb_railwy_act-activity_param,
*      lv_activity_name  TYPE ztb_railwy_act-activity_name,
*      lv_activity_qty   TYPE ztb_railwy_act-activity_qty,
*      lv_activity_unit  TYPE ztb_railwy_act-activity_unit.
*
*    DATA lt_activity_create TYPE TABLE FOR CREATE
*      zi_railway_ord\_activities.
*
*    CLEAR lt_activity_create.
*
*    APPEND INITIAL LINE TO lt_activity_create
*      ASSIGNING FIELD-SYMBOL(<activity_request>).
*
*    <activity_request>-%tky = ls_header-%tky.
*    <activity_request>-%is_draft = ls_header-%is_draft.
*
*    DO 6 TIMES.
*
*      lv_activity_slot = sy-index.
*
*      CLEAR:
*        lv_activity_param,
*        lv_activity_name,
*        lv_activity_qty,
*        lv_activity_unit.
*
*      DATA(lv_param_field) =
*        |STANDARDWORKFORMULAPARAM{ lv_activity_slot }|.
*
*      DATA(lv_qty_field) =
*        |WORKCENTERSTANDARDWORKQTY{ lv_activity_slot }|.
*
*      DATA(lv_unit_field) =
*        |WORKCENTERSTANDARDWORKQTYUNIT{ lv_activity_slot }|.
*
*      ASSIGN COMPONENT lv_param_field
*        OF STRUCTURE ls_activity_source
*        TO FIELD-SYMBOL(<activity_param>).
*
*      IF sy-subrc = 0.
*        lv_activity_param = <activity_param>.
*      ENDIF.
*
*      ASSIGN COMPONENT lv_qty_field
*        OF STRUCTURE ls_activity_source
*        TO FIELD-SYMBOL(<activity_qty>).
*
*      IF sy-subrc = 0.
*
*        lv_activity_qty =
*          ( CONV decfloat34( <activity_qty> )
*            / CONV decfloat34(
*                ls_activity_source-operationreferencequantity ) )
*          * lv_confirmed_qty_wt.
*
*      ENDIF.
*
*      ASSIGN COMPONENT lv_unit_field
*        OF STRUCTURE ls_activity_source
*        TO FIELD-SYMBOL(<activity_unit>).
*
*      IF sy-subrc = 0.
*        lv_activity_unit = <activity_unit>.
*      ENDIF.
*
*      IF lv_activity_param IS NOT INITIAL.
*
*        SELECT SINGLE
*          FROM i_standardworkformulaparamtext
*          FIELDS standardworkformulaparamname
*          WHERE standardworkformulaparameter =
*                  @lv_activity_param
*            AND language = @sy-langu
*          INTO @lv_activity_name.
*
*      ENDIF.
*
*      IF lv_activity_param IS INITIAL
*         AND lv_activity_name IS INITIAL
*         AND lv_activity_qty IS INITIAL
*         AND lv_activity_unit IS INITIAL.
*        CONTINUE.
*      ENDIF.
*
*      APPEND VALUE #(
*        %is_draft = ls_header-%is_draft
*        operation =
*          lv_operation-manufacturingorderoperation_2
*        activityslot = lv_activity_slot
*        activitylabel = |Activity { lv_activity_slot }|
*        activityparam = lv_activity_param
*        activityname = lv_activity_name
*        activityqty = lv_activity_qty
*        activityunit = lv_activity_unit
*        displayactivityunit = COND #(
*          WHEN lv_activity_unit = 'STD'
*          THEN 'HRS'
*          WHEN lv_activity_unit = 'ST'
*          THEN 'PC'
*          ELSE lv_activity_unit
*        )
*      ) TO <activity_request>-%target.
*
*    ENDDO.
*
*    "Read existing child rows
*    READ ENTITIES OF zi_railway_ord IN LOCAL MODE
*      ENTITY railway_ord BY \_scrapitems
*        FIELDS ( scrapitemid )
*        WITH VALUE #( ( %tky = ls_header-%tky ) )
*      RESULT DATA(lt_existing_scrap)
*
*      ENTITY railway_ord BY \_activities
*        ALL FIELDS
*        WITH VALUE #( ( %tky = ls_header-%tky ) )
*      RESULT DATA(lt_existing_activities)
*
*      FAILED DATA(ls_child_read_failed)
*      REPORTED DATA(ls_child_read_reported).
*
*    APPEND LINES OF ls_child_read_failed-railway_ord
*      TO failed-railway_ord.
*    APPEND LINES OF ls_child_read_failed-scrapitem
*      TO failed-scrapitem.
*    APPEND LINES OF ls_child_read_failed-activity
*      TO failed-activity.
*
*    APPEND LINES OF ls_child_read_reported-railway_ord
*      TO reported-railway_ord.
*    APPEND LINES OF ls_child_read_reported-scrapitem
*      TO reported-scrapitem.
*    APPEND LINES OF ls_child_read_reported-activity
*      TO reported-activity.
*
*    IF ls_child_read_failed IS NOT INITIAL.
*
*      IF NOT line_exists(
*        failed-railway_ord[ %tky = ls_header-%tky ]
*      ).
*        APPEND VALUE #(
*          %tky = ls_header-%tky
*        ) TO failed-railway_ord.
*      ENDIF.
*
*      CONTINUE.
*    ENDIF.
*
*    "Delete previous scrap rows
*    IF lt_existing_scrap IS NOT INITIAL.
*
*      MODIFY ENTITIES OF zi_railway_ord IN LOCAL MODE
*        ENTITY scrapitem
*          DELETE FROM VALUE #(
*            FOR ls_existing_scrap IN lt_existing_scrap
*            ( %tky = ls_existing_scrap-%tky )
*          )
*        FAILED DATA(ls_scrap_delete_failed)
*        REPORTED DATA(ls_scrap_delete_reported).
*
*      APPEND LINES OF ls_scrap_delete_failed-scrapitem
*        TO failed-scrapitem.
*
*      APPEND LINES OF ls_scrap_delete_reported-scrapitem
*        TO reported-scrapitem.
*
*      IF ls_scrap_delete_failed IS NOT INITIAL.
*
*        APPEND VALUE #(
*          %tky = ls_header-%tky
*        ) TO failed-railway_ord.
*
*        CONTINUE.
*      ENDIF.
*
*    ENDIF.
*
*    "Create railway scrap rows
*    IF lt_scrap_components IS NOT INITIAL.
*
*      MODIFY ENTITIES OF zi_railway_ord IN LOCAL MODE
*        ENTITY railway_ord
*          CREATE BY \_scrapitems AUTO FILL CID
*            FIELDS (
*              scrapmaterial
*              scrapdesc
*              storagelocation
*              scrapqty
*              scrapunit
*              displayscrapunit
*            )
*            WITH VALUE #(
*              (
*                %tky = ls_header-%tky
*                %is_draft = ls_header-%is_draft
*
*                %target = VALUE #(
*                  FOR ls_component IN lt_scrap_components
*                  (
*                    %is_draft = ls_header-%is_draft
*                    scrapmaterial = ls_component-material
*                    scrapdesc = ls_component-productdescription
*                    storagelocation =
*                      ls_component-storagelocation
*                   scrapqty = COND #(
*                      WHEN ls_component-requiredquantity = 0
*                      THEN ls_header-ScrapQty
*
*                      WHEN ls_component-requiredquantity < 0
*                      THEN ls_component-requiredquantity * -1
*
*                      ELSE ls_component-requiredquantity
*                    )
*                    scrapunit = ls_component-baseunit
*                    displayscrapunit = COND #(
*                      WHEN ls_component-baseunit = 'ST'
*                      THEN 'PC'
*                      ELSE ls_component-baseunit
*                    )
*                  )
*                )
*              )
*            )
*        FAILED DATA(ls_scrap_create_failed)
*        REPORTED DATA(ls_scrap_create_reported).
*
*      APPEND LINES OF ls_scrap_create_failed-railway_ord
*        TO failed-railway_ord.
*      APPEND LINES OF ls_scrap_create_failed-scrapitem
*        TO failed-scrapitem.
*
*      APPEND LINES OF ls_scrap_create_reported-railway_ord
*        TO reported-railway_ord.
*      APPEND LINES OF ls_scrap_create_reported-scrapitem
*        TO reported-scrapitem.
*
*      IF ls_scrap_create_failed IS NOT INITIAL.
*
*        IF NOT line_exists(
*          failed-railway_ord[ %tky = ls_header-%tky ]
*        ).
*          APPEND VALUE #(
*            %tky = ls_header-%tky
*          ) TO failed-railway_ord.
*        ENDIF.
*
*        CONTINUE.
*      ENDIF.
*
*    ENDIF.
*
*    "Delete previous activity rows
*    IF lt_existing_activities IS NOT INITIAL.
*
*      MODIFY ENTITIES OF zi_railway_ord IN LOCAL MODE
*        ENTITY activity
*          DELETE FROM VALUE #(
*            FOR ls_existing_activity IN lt_existing_activities
*            ( %tky = ls_existing_activity-%tky )
*          )
*        FAILED DATA(ls_activity_delete_failed)
*        REPORTED DATA(ls_activity_delete_reported).
*
*      APPEND LINES OF ls_activity_delete_failed-activity
*        TO failed-activity.
*
*      APPEND LINES OF ls_activity_delete_reported-activity
*        TO reported-activity.
*
*      IF ls_activity_delete_failed IS NOT INITIAL.
*
*        APPEND VALUE #(
*          %tky = ls_header-%tky
*        ) TO failed-railway_ord.
*
*        CONTINUE.
*      ENDIF.
*
*    ENDIF.
*
*    "Create refreshed railway activity rows
*    IF <activity_request>-%target IS NOT INITIAL.
*
*      MODIFY ENTITIES OF zi_railway_ord IN LOCAL MODE
*        ENTITY railway_ord
*          CREATE BY \_activities AUTO FILL CID
*            FIELDS (
*              operation
*              activityslot
*              activitylabel
*              activityparam
*              activityname
*              activityqty
*              activityunit
*              displayactivityunit
*            )
*            WITH lt_activity_create
*        FAILED DATA(ls_activity_create_failed)
*        REPORTED DATA(ls_activity_create_reported).
*
*      APPEND LINES OF ls_activity_create_failed-railway_ord
*        TO failed-railway_ord.
*      APPEND LINES OF ls_activity_create_failed-activity
*        TO failed-activity.
*
*      APPEND LINES OF ls_activity_create_reported-railway_ord
*        TO reported-railway_ord.
*      APPEND LINES OF ls_activity_create_reported-activity
*        TO reported-activity.
*
*      IF ls_activity_create_failed IS NOT INITIAL.
*
*        IF NOT line_exists(
*          failed-railway_ord[ %tky = ls_header-%tky ]
*        ).
*          APPEND VALUE #(
*            %tky = ls_header-%tky
*          ) TO failed-railway_ord.
*        ENDIF.
*
*        CONTINUE.
*      ENDIF.
*
*    ENDIF.
*
*    "Mark order as successfully fetched
*    MODIFY ENTITIES OF zi_railway_ord IN LOCAL MODE
*      ENTITY railway_ord
*        UPDATE FIELDS ( fetchedorderno )
*        WITH VALUE #(
*          (
*            %tky = ls_header-%tky
*            fetchedorderno = lv_order_no
*          )
*        )
*      FAILED DATA(ls_fetch_mark_failed)
*      REPORTED DATA(ls_fetch_mark_reported).
*
*    APPEND LINES OF ls_fetch_mark_failed-railway_ord
*      TO failed-railway_ord.
*
*    APPEND LINES OF ls_fetch_mark_reported-railway_ord
*      TO reported-railway_ord.
*
*    IF ls_fetch_mark_failed IS NOT INITIAL.
*      CONTINUE.
*    ENDIF.
*
*    APPEND VALUE #(
*      %tky = ls_header-%tky
*      %msg = new_message_with_text(
*        severity = if_abap_behv_message=>severity-success
*        text = |Order { ls_header-orderno } details fetched successfully|
*      )
*    ) TO reported-railway_ord.
*
*  ENDLOOP.
*
*  "Return updated header
*  READ ENTITIES OF zi_railway_ord IN LOCAL MODE
*    ENTITY railway_ord
*      ALL FIELDS
*      WITH CORRESPONDING #( keys )
*    RESULT DATA(lt_updated_headers)
*    FAILED DATA(ls_final_read_failed)
*    REPORTED DATA(ls_final_read_reported).
*
*  APPEND LINES OF ls_final_read_failed-railway_ord
*    TO failed-railway_ord.
*
*  APPEND LINES OF ls_final_read_reported-railway_ord
*    TO reported-railway_ord.
*
*  result = VALUE #(
*    FOR ls_updated_header IN lt_updated_headers
*    (
*      %tky = ls_updated_header-%tky
*      %param = ls_updated_header
*    )
*  ).
*
*ENDMETHOD.
*
*
* METHOD submitandpost.
*
*  DATA(lv_posting_date) =
*    cl_abap_context_info=>get_system_date( ).
*
*  DATA(lv_current_time) =
*    cl_abap_context_info=>get_system_time( ).
*
*  "Read railway headers
*  READ ENTITIES OF zi_railway_ord IN LOCAL MODE
*    ENTITY railway_ord
*      ALL FIELDS
*      WITH CORRESPONDING #( keys )
*    RESULT DATA(lt_headers)
*    FAILED DATA(ls_read_failed)
*    REPORTED DATA(ls_read_reported).
*
*  APPEND LINES OF ls_read_failed-railway_ord
*    TO failed-railway_ord.
*
*  APPEND LINES OF ls_read_reported-railway_ord
*    TO reported-railway_ord.
*
*  LOOP AT lt_headers INTO DATA(ls_header).
*
*    DATA(lv_error) = CONV string( '' ).
*
*    "Validate header before posting
*    IF ls_header-%is_draft = if_abap_behv=>mk-on.
*      lv_error = 'Save the record before Submit and Post'.
*
*    ELSEIF ls_header-status <> 'CREATED'.
*      lv_error = 'Only a record with CREATED status can be posted'.
*
*    ELSEIF ls_header-orderno IS INITIAL.
*      lv_error = 'Enter the order number'.
*
*    ELSEIF ls_header-operation IS INITIAL.
*      lv_error = 'Enter the operation'.
*
*    ELSEIF ls_header-postingdate IS INITIAL.
*      lv_error = 'Enter the posting date'.
*
*    ELSEIF ls_header-unit IS INITIAL.
*      lv_error = 'Fetch the confirmation unit first'.
*
*    ELSEIF ls_header-qtytoconfirm < 0
*        OR ls_header-scrapqty < 0.
*      lv_error = 'Yield and scrap quantities cannot be negative'.
*
*    ELSEIF ls_header-qtytoconfirm = 0
*       AND ls_header-scrapqty = 0.
*      lv_error = 'Enter a yield or scrap quantity greater than zero'.
*
*    ELSEIF ls_header-remainingqty <= 0.
*      lv_error = 'Remaining quantity is zero. Order cannot be posted'.
*
*    ELSEIF ls_header-qtytoconfirm + ls_header-scrapqty >
*           ls_header-remainingqty.
*      lv_error = 'Yield plus scrap cannot exceed remaining quantity'.
*
*    ENDIF.
*
*    IF lv_error IS NOT INITIAL.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*      ) TO failed-railway_ord.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*        %msg = new_message_with_text(
*          severity = if_abap_behv_message=>severity-error
*          text     = lv_error
*        )
*      ) TO reported-railway_ord.
*
*      CONTINUE.
*
*    ENDIF.
*
*    "Read saved scrap rows
*    READ ENTITIES OF zi_railway_ord IN LOCAL MODE
*      ENTITY railway_ord BY \_scrapitems
*        ALL FIELDS
*        WITH VALUE #( ( %tky = ls_header-%tky ) )
*      RESULT DATA(lt_scrap_items)
*      FAILED DATA(ls_scrap_read_failed)
*      REPORTED DATA(ls_scrap_read_reported).
*
*    APPEND LINES OF ls_scrap_read_failed-railway_ord
*      TO failed-railway_ord.
*    APPEND LINES OF ls_scrap_read_failed-scrapitem
*      TO failed-scrapitem.
*
*    APPEND LINES OF ls_scrap_read_reported-railway_ord
*      TO reported-railway_ord.
*    APPEND LINES OF ls_scrap_read_reported-scrapitem
*      TO reported-scrapitem.
*
*    IF ls_scrap_read_failed IS NOT INITIAL.
*
*      IF NOT line_exists(
*        failed-railway_ord[ %tky = ls_header-%tky ]
*      ).
*        APPEND VALUE #(
*          %tky = ls_header-%tky
*        ) TO failed-railway_ord.
*      ENDIF.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*        %msg = new_message_with_text(
*          severity = if_abap_behv_message=>severity-error
*          text     = 'Unable to read scrap items'
*        )
*      ) TO reported-railway_ord.
*
*      CONTINUE.
*
*    ENDIF.
*
*    "Validate scrap movements
*    CLEAR lv_error.
*
*    LOOP AT lt_scrap_items INTO DATA(ls_scrap_check).
*
*      IF ls_scrap_check-scrapqty < 0.
*        lv_error = 'Scrap item quantities cannot be negative'.
*        EXIT.
*      ENDIF.
*
*      IF ls_scrap_check-scrapqty > 0
*         AND ( ls_scrap_check-scrapmaterial IS INITIAL
*            OR ls_scrap_check-storagelocation IS INITIAL
*            OR ls_scrap_check-scrapunit IS INITIAL ).
*
*        lv_error =
*          'Enter material, storage location and unit for scrap items'.
*        EXIT.
*
*      ENDIF.
*
*    ENDLOOP.
*
*    IF lv_error IS NOT INITIAL.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*      ) TO failed-railway_ord.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*        %msg = new_message_with_text(
*          severity = if_abap_behv_message=>severity-error
*          text     = lv_error
*        )
*      ) TO reported-railway_ord.
*
*      CONTINUE.
*
*    ENDIF.
*
*    "Normalize order using the standard BO field type
*    DATA ls_standard_header
*      TYPE STRUCTURE FOR CREATE i_productionordconfirmationtp.
*
*    CLEAR ls_standard_header.
*
*    ls_standard_header-orderid = ls_header-orderno.
*    ls_standard_header-orderid =
*      |{ ls_standard_header-orderid ALPHA = IN }|.
*
*    "Build positive-quantity scrap movements
*    DATA lt_movements TYPE TABLE FOR CREATE
*      i_productionordconfirmationtp\_prodnordconfmatldocitm.
*
*    DATA ls_movement_request LIKE LINE OF lt_movements.
*
*    CLEAR:
*      lt_movements,
*      ls_movement_request.
*
*    ls_movement_request-%cid_ref = 'CONF_1'.
*
*    LOOP AT lt_scrap_items INTO DATA(ls_scrap)
*      WHERE scrapqty > 0.
*
*      APPEND VALUE #(
*        %cid = |MAT_{ sy-tabix }|
*
*        orderid             = ls_standard_header-orderid
*        material            = ls_scrap-scrapmaterial
*        plant               = ls_header-plant
*        storagelocation     = ls_scrap-storagelocation
*        goodsmovementtype   = '531'
*        entryunitsapcode    = ls_scrap-scrapunit
*        quantityinentryunit = ls_scrap-scrapqty
*      ) TO ls_movement_request-%target.
*
*    ENDLOOP.
*
*    IF ls_movement_request-%target IS NOT INITIAL.
*      APPEND ls_movement_request TO lt_movements.
*    ENDIF.
*
*    "Read saved production activities
*    READ ENTITIES OF zi_railway_ord IN LOCAL MODE
*      ENTITY railway_ord BY \_activities
*        ALL FIELDS
*        WITH VALUE #( ( %tky = ls_header-%tky ) )
*      RESULT DATA(lt_post_activities)
*      FAILED DATA(ls_act_failed)
*      REPORTED DATA(ls_act_reported).
*
*    APPEND LINES OF ls_act_failed-railway_ord
*      TO failed-railway_ord.
*    APPEND LINES OF ls_act_failed-activity
*      TO failed-activity.
*
*    APPEND LINES OF ls_act_reported-railway_ord
*      TO reported-railway_ord.
*    APPEND LINES OF ls_act_reported-activity
*      TO reported-activity.
*
*    CLEAR lv_error.
*
*    IF ls_act_failed IS NOT INITIAL.
*      lv_error = 'Unable to read production activities'.
*    ENDIF.
*
*    DATA ls_act_values
*      TYPE STRUCTURE FOR CREATE i_productionordconfirmationtp.
*
*    CLEAR ls_act_values.
*
*    IF lv_error IS INITIAL.
*
*      LOOP AT lt_post_activities INTO DATA(ls_act).
*
*        IF ls_act-activityqty < 0.
*          lv_error = 'Activity quantity cannot be negative'.
*          EXIT.
*        ENDIF.
*
*        IF ls_act-activityqty <> 0
*           AND ls_act-activityunit IS INITIAL.
*          lv_error = 'Enter a unit for the activity quantity'.
*          EXIT.
*        ENDIF.
*
*        CASE ls_act-activityslot.
*
*          WHEN '1'.
*            ls_act_values-opconfirmedworkquantity1 =
*              ls_act-activityqty.
*            ls_act_values-workquantityunit1sapcode =
*              ls_act-activityunit.
*
*          WHEN '2'.
*            ls_act_values-opconfirmedworkquantity2 =
*              ls_act-activityqty.
*            ls_act_values-workquantityunit2sapcode =
*              ls_act-activityunit.
*
*          WHEN '3'.
*            ls_act_values-opconfirmedworkquantity3 =
*              ls_act-activityqty.
*            ls_act_values-workquantityunit3sapcode =
*              ls_act-activityunit.
*
*          WHEN '4'.
*            ls_act_values-opconfirmedworkquantity4 =
*              ls_act-activityqty.
*            ls_act_values-workquantityunit4sapcode =
*              ls_act-activityunit.
*
*          WHEN '5'.
*            ls_act_values-opconfirmedworkquantity5 =
*              ls_act-activityqty.
*            ls_act_values-workquantityunit5sapcode =
*              ls_act-activityunit.
*
*          WHEN '6'.
*            ls_act_values-opconfirmedworkquantity6 =
*              ls_act-activityqty.
*            ls_act_values-workquantityunit6sapcode =
*              ls_act-activityunit.
*
*          WHEN OTHERS.
*            lv_error = 'Activity number must be between 1 and 6'.
*            EXIT.
*
*        ENDCASE.
*
*      ENDLOOP.
*
*    ENDIF.
*
*    IF lv_error IS NOT INITIAL.
*
*      IF NOT line_exists(
*        failed-railway_ord[ %tky = ls_header-%tky ]
*      ).
*        APPEND VALUE #(
*          %tky = ls_header-%tky
*        ) TO failed-railway_ord.
*      ENDIF.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*        %msg = new_message_with_text(
*          severity = if_abap_behv_message=>severity-error
*          text     = lv_error
*        )
*      ) TO reported-railway_ord.
*
*      CONTINUE.
*
*    ENDIF.
*
*    "Create standard confirmation and scrap movements
*    MODIFY ENTITIES OF i_productionordconfirmationtp
*      ENTITY productionorderconfirmation
*
*        CREATE FIELDS (
*          orderid
*          sequence
*          orderoperation
*          plant
*          workcenter
*          postingdate
*          confirmedexecutionstartdate
*          confirmedexecutionstarttime
*          confirmedexecutionenddate
*          confirmedexecutionendtime
*          shiftgrouping
*          shiftdefinition
*          finalconfirmationtype
*          confirmationyieldquantity
*          confirmationscrapquantity
*          confirmationunitsapcode
*          opconfirmedworkquantity1
*          workquantityunit1sapcode
*          opconfirmedworkquantity2
*          workquantityunit2sapcode
*          opconfirmedworkquantity3
*          workquantityunit3sapcode
*          opconfirmedworkquantity4
*          workquantityunit4sapcode
*          opconfirmedworkquantity5
*          workquantityunit5sapcode
*          opconfirmedworkquantity6
*          workquantityunit6sapcode
*        )
*
*        WITH VALUE #(
*          (
*            %cid = 'CONF_1'
*
*            orderid        = ls_standard_header-orderid
*            sequence       = '000000'
*            orderoperation = ls_header-operation
*            plant          = ls_header-plant
*            workcenter     = ls_header-workcenter
*            postingdate    = lv_posting_date
*
*            confirmedexecutionstartdate = lv_posting_date
*            confirmedexecutionenddate   = lv_posting_date
*            confirmedexecutionstarttime = lv_current_time
*            confirmedexecutionendtime   = lv_current_time
*
*            shiftgrouping   = 'PP'
*            shiftdefinition = ls_header-group_defn
*
*            finalconfirmationtype = COND #(
*              WHEN ls_header-remainingqty =
*                   ls_header-qtytoconfirm + ls_header-scrapqty
*              THEN 'X'
*              ELSE space
*            )
*
*            confirmationyieldquantity = ls_header-qtytoconfirm
*            confirmationscrapquantity = ls_header-scrapqty
*            confirmationunitsapcode   = ls_header-unit
*
*            opconfirmedworkquantity1 =
*              ls_act_values-opconfirmedworkquantity1
*            workquantityunit1sapcode =
*              ls_act_values-workquantityunit1sapcode
*
*            opconfirmedworkquantity2 =
*              ls_act_values-opconfirmedworkquantity2
*            workquantityunit2sapcode =
*              ls_act_values-workquantityunit2sapcode
*
*            opconfirmedworkquantity3 =
*              ls_act_values-opconfirmedworkquantity3
*            workquantityunit3sapcode =
*              ls_act_values-workquantityunit3sapcode
*
*            opconfirmedworkquantity4 =
*              ls_act_values-opconfirmedworkquantity4
*            workquantityunit4sapcode =
*              ls_act_values-workquantityunit4sapcode
*
*            opconfirmedworkquantity5 =
*              ls_act_values-opconfirmedworkquantity5
*            workquantityunit5sapcode =
*              ls_act_values-workquantityunit5sapcode
*
*            opconfirmedworkquantity6 =
*              ls_act_values-opconfirmedworkquantity6
*            workquantityunit6sapcode =
*              ls_act_values-workquantityunit6sapcode
*          )
*        )
*
*        CREATE BY \_prodnordconfmatldocitm
*          FIELDS (
*            orderid
*            material
*            plant
*            storagelocation
*            goodsmovementtype
*            entryunitsapcode
*            quantityinentryunit
*          )
*          WITH lt_movements
*
*      MAPPED DATA(ls_post_mapped)
*      FAILED DATA(ls_post_failed)
*      REPORTED DATA(ls_post_reported).
*
*    "Forward standard confirmation messages
*    LOOP AT ls_post_reported-productionorderconfirmation
*      INTO DATA(ls_conf_message).
*
*      IF ls_conf_message-%msg IS BOUND.
*        APPEND VALUE #(
*          %tky = ls_header-%tky
*          %msg = ls_conf_message-%msg
*        ) TO reported-railway_ord.
*      ENDIF.
*
*    ENDLOOP.
*
*    "Forward standard goods movement messages
*    LOOP AT ls_post_reported-prodorderconfmatldocitem
*      INTO DATA(ls_gm_message).
*
*      IF ls_gm_message-%msg IS BOUND.
*        APPEND VALUE #(
*          %tky = ls_header-%tky
*          %msg = ls_gm_message-%msg
*        ) TO reported-railway_ord.
*      ENDIF.
*
*    ENDLOOP.
*
*    IF ls_post_failed IS NOT INITIAL.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*      ) TO failed-railway_ord.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*        %msg = new_message_with_text(
*          severity = if_abap_behv_message=>severity-error
*          text = |Posting request failed for order { ls_header-orderno }|
*        )
*      ) TO reported-railway_ord.
*
*      CONTINUE.
*
*    ENDIF.
*
*    "Buffer standard confirmation PID for save_modified
*    LOOP AT ls_post_mapped-productionorderconfirmation
*      INTO DATA(ls_created_confirmation)
*      WHERE %cid = 'CONF_1'.
*
*      APPEND VALUE #(
*        confirm_id = ls_header-confirmid
*        pid        = ls_created_confirmation-%pid
*      ) TO lcl_confirmation_buffer=>entries.
*
*    ENDLOOP.
*
*    "Mark railway confirmation as posted
*    MODIFY ENTITIES OF zi_railway_ord IN LOCAL MODE
*      ENTITY railway_ord
*        UPDATE FIELDS ( status postingdate )
*        WITH VALUE #(
*          (
*            %tky        = ls_header-%tky
*            status = COND #(
*              WHEN ls_header-ScrapQty > 0
*              THEN 'PART_POST'
*              ELSE 'POSTED'
*            )
*            postingdate = lv_posting_date
*          )
*        )
*      FAILED DATA(ls_update_failed)
*      REPORTED DATA(ls_update_reported).
*
*    APPEND LINES OF ls_update_failed-railway_ord
*      TO failed-railway_ord.
*
*    APPEND LINES OF ls_update_reported-railway_ord
*      TO reported-railway_ord.
*
*    IF ls_update_failed IS NOT INITIAL.
*      CONTINUE.
*    ENDIF.
*
*    ls_header-status = 'POSTED'.
*    ls_header-postingdate = lv_posting_date.
*
*    APPEND VALUE #(
*      %tky = ls_header-%tky
*      %msg = new_message_with_text(
*        severity = if_abap_behv_message=>severity-success
*        text = |Confirmation done for order { ls_header-orderno }|
*      )
*    ) TO reported-railway_ord.
*
*    APPEND VALUE #(
*      %tky   = ls_header-%tky
*      %param = ls_header
*    ) TO result.
*
*  ENDLOOP.
*
*ENDMETHOD.
*
*  METHOD cancelconfirmation.
*
*  READ ENTITIES OF zi_railway_ord IN LOCAL MODE
*    ENTITY railway_ord
*      ALL FIELDS
*      WITH CORRESPONDING #( keys )
*    RESULT DATA(lt_headers)
*    FAILED DATA(ls_read_failed)
*    REPORTED DATA(ls_read_reported).
*
*  APPEND LINES OF ls_read_failed-railway_ord
*    TO failed-railway_ord.
*
*  APPEND LINES OF ls_read_reported-railway_ord
*    TO reported-railway_ord.
*
*  LOOP AT lt_headers INTO DATA(ls_header).
*
*    DATA(lv_error) = CONV string( '' ).
*
*    "Validate before cancellation
*    IF ls_header-%is_draft = if_abap_behv=>mk-on.
*      lv_error = 'Save the record before cancellation'.
*
*    ELSEIF ls_header-status <> 'POSTED'.
*      lv_error = 'Only a posted confirmation can be cancelled'.
*
*    ELSEIF ls_header-confirmationgroup IS INITIAL
*        OR ls_header-confirmationcount IS INITIAL.
*      lv_error = 'Original confirmation identifiers are missing'.
*
*    ENDIF.
*
*    IF lv_error IS NOT INITIAL.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*      ) TO failed-railway_ord.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*        %msg = new_message_with_text(
*          severity = if_abap_behv_message=>severity-error
*          text     = lv_error
*        )
*      ) TO reported-railway_ord.
*
*      CONTINUE.
*
*    ENDIF.
*
*    "Cancel the exact original standard confirmation
*    MODIFY ENTITIES OF i_productionordconfirmationtp
*      ENTITY productionorderconfirmation
*        EXECUTE cancelprodnordconf
*        FROM VALUE #(
*          (
*            %tky-confirmationgroup =
*              ls_header-confirmationgroup
*            %tky-confirmationcount =
*              ls_header-confirmationcount
*          )
*        )
*      FAILED DATA(ls_cancel_failed)
*      REPORTED DATA(ls_cancel_reported).
*
*    "Forward standard confirmation messages
*    LOOP AT ls_cancel_reported-productionorderconfirmation
*      INTO DATA(ls_message).
*
*      IF ls_message-%msg IS BOUND.
*
*        APPEND VALUE #(
*          %tky = ls_header-%tky
*          %msg = ls_message-%msg
*        ) TO reported-railway_ord.
*
*      ENDIF.
*
*    ENDLOOP.
*
*    "Forward any standard goods movement messages
*    LOOP AT ls_cancel_reported-prodorderconfmatldocitem
*      INTO DATA(ls_movement_message).
*
*      IF ls_movement_message-%msg IS BOUND.
*
*        APPEND VALUE #(
*          %tky = ls_header-%tky
*          %msg = ls_movement_message-%msg
*        ) TO reported-railway_ord.
*
*      ENDIF.
*
*    ENDLOOP.
*
*    IF ls_cancel_failed IS NOT INITIAL.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*      ) TO failed-railway_ord.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*        %msg = new_message_with_text(
*          severity = if_abap_behv_message=>severity-error
*          text     = 'Confirmation cancellation request failed'
*        )
*      ) TO reported-railway_ord.
*
*      CONTINUE.
*
*    ENDIF.
*
*    "Update railway status in the same RAP transaction
*    MODIFY ENTITIES OF zi_railway_ord IN LOCAL MODE
*      ENTITY railway_ord
*        UPDATE FIELDS ( status )
*        WITH VALUE #(
*          (
*            %tky   = ls_header-%tky
*            status = 'CANCELLED'
*          )
*        )
*      FAILED DATA(ls_update_failed)
*      REPORTED DATA(ls_update_reported).
*
*    APPEND LINES OF ls_update_failed-railway_ord
*      TO failed-railway_ord.
*
*    APPEND LINES OF ls_update_reported-railway_ord
*      TO reported-railway_ord.
*
*    IF ls_update_failed IS NOT INITIAL.
*      CONTINUE.
*    ENDIF.
*
*    "Read the updated railway header
*    READ ENTITIES OF zi_railway_ord IN LOCAL MODE
*      ENTITY railway_ord
*        ALL FIELDS
*        WITH VALUE #( ( %tky = ls_header-%tky ) )
*      RESULT DATA(lt_updated)
*      FAILED DATA(ls_final_read_failed)
*      REPORTED DATA(ls_final_read_reported).
*
*    APPEND LINES OF ls_final_read_failed-railway_ord
*      TO failed-railway_ord.
*
*    APPEND LINES OF ls_final_read_reported-railway_ord
*      TO reported-railway_ord.
*
*    IF ls_final_read_failed IS NOT INITIAL.
*      CONTINUE.
*    ENDIF.
*
*    LOOP AT lt_updated INTO DATA(ls_updated).
*
*      APPEND VALUE #(
*        %tky   = ls_updated-%tky
*        %param = ls_updated
*      ) TO result.
*
*    ENDLOOP.
*
*    APPEND VALUE #(
*      %tky = ls_header-%tky
*      %msg = new_message_with_text(
*        severity = if_abap_behv_message=>severity-success
*        text = |Confirmation cancelled successfully for order { ls_header-orderno }|
*      )
*    ) TO reported-railway_ord.
*
*  ENDLOOP.
*
*ENDMETHOD.
*
**METHOD postrejection.
**
**  DATA:
**    lv_error            TYPE string,
**    lv_storage_location TYPE
**      i_materialdocumentitem_2-storagelocation,
**    lv_order            TYPE
**      i_manufacturingorder-manufacturingorder,
**    lv_total_quantity   TYPE ztb_rail_reject-quantity.
**
**  READ ENTITIES OF zi_railway_ord IN LOCAL MODE
**    ENTITY railway_ord
**      ALL FIELDS
**      WITH CORRESPONDING #( keys )
**    RESULT DATA(lt_headers)
**    FAILED DATA(ls_read_failed)
**    REPORTED DATA(ls_read_reported).
**
**  APPEND LINES OF ls_read_failed-railway_ord
**    TO failed-railway_ord.
**
**  APPEND LINES OF ls_read_reported-railway_ord
**    TO reported-railway_ord.
**
**  LOOP AT lt_headers INTO DATA(ls_header).
**
**    CLEAR:
**      lv_error,
**      lv_storage_location,
**      lv_order,
**      lv_total_quantity.
**
**    "Validate the saved header
**    IF ls_header-%is_draft = if_abap_behv=>mk-on.
**      lv_error = 'Save the record before posting rejection items'.
**
**    ELSEIF ls_header-materialdocument IS NOT INITIAL.
**      lv_error =
**        'A material document is already assigned. Posting is blocked'.
**
**    ELSEIF ls_header-status <> 'POSTED'
**       AND ls_header-status <> 'PART_POST'.
**      lv_error = 'Complete Post Confirmation before posting rejection'.
**
**    ELSEIF ls_header-orderno IS INITIAL.
**      lv_error = 'Order number is required'.
**
**    ELSEIF ls_header-material IS INITIAL.
**      lv_error = 'Material is required'.
**
**    ELSEIF ls_header-plant IS INITIAL.
**      lv_error = 'Plant is required'.
**
**    ELSEIF ls_header-batch_number IS INITIAL.
**      lv_error = 'Batch number is required'.
**
**    ELSEIF ls_header-postingdate IS INITIAL.
**      lv_error = 'Posting date is required'.
**
**    ELSEIF ls_header-unit IS INITIAL.
**      lv_error = 'Confirmation unit is required'.
**    ENDIF.
**
**    IF lv_error IS NOT INITIAL.
**      APPEND VALUE #(
**        %tky = ls_header-%tky
**      ) TO failed-railway_ord.
**
**      APPEND VALUE #(
**        %tky = ls_header-%tky
**        %msg = new_message_with_text(
**          severity = if_abap_behv_message=>severity-error
**          text     = lv_error
**        )
**      ) TO reported-railway_ord.
**
**      CONTINUE.
**    ENDIF.
**
**    "Read saved rejection rows
**    READ ENTITIES OF zi_railway_ord IN LOCAL MODE
**      ENTITY railway_ord BY \_REJECTION
**        ALL FIELDS
**        WITH VALUE #( ( %tky = ls_header-%tky ) )
**      RESULT DATA(lt_rejections)
**      FAILED DATA(ls_child_failed)
**      REPORTED DATA(ls_child_reported).
**
**    APPEND LINES OF ls_child_failed-railway_ord
**      TO failed-railway_ord.
**    APPEND LINES OF ls_child_failed-rejection
**      TO failed-rejection.
**
**    APPEND LINES OF ls_child_reported-railway_ord
**      TO reported-railway_ord.
**    APPEND LINES OF ls_child_reported-rejection
**      TO reported-rejection.
**
**    IF ls_child_failed IS NOT INITIAL.
**      lv_error = 'Unable to read rejection items'.
**
**    ELSEIF lt_rejections IS INITIAL.
**      lv_error = 'No rejection items available for posting'.
**
**    ELSE.
**      LOOP AT lt_rejections INTO DATA(ls_rejection).
**
**        IF ls_rejection-rejectionreason IS INITIAL.
**          lv_error = 'Enter a rejection reason on every row'.
**          EXIT.
**        ENDIF.
**
**        IF ls_rejection-quantity <= 0.
**          lv_error =
**            'Every rejection row must have a quantity greater than zero'.
**          EXIT.
**        ENDIF.
**
**        IF ls_rejection-unit <> ls_header-unit.
**          lv_error =
**            'Rejection units must match the header confirmation unit'.
**          EXIT.
**        ENDIF.
**
**        lv_total_quantity =
**          lv_total_quantity + ls_rejection-quantity.
**
**      ENDLOOP.
**    ENDIF.
**
**    "Use the manufacturing order receiving storage location
**    IF lv_error IS INITIAL.
**
**      lv_order = ls_header-orderno.
**      lv_order = |{ lv_order ALPHA = IN }|.
**
**      SELECT SINGLE
**        FROM i_manufacturingorderitem
**        FIELDS storagelocation
**        WHERE manufacturingorder = @lv_order
**          AND manufacturingorderitem = '0001'
**        INTO @lv_storage_location.
**
**      IF sy-subrc <> 0 OR lv_storage_location IS INITIAL.
**        lv_error =
**          'Storage location not found in manufacturing order item'.
**      ENDIF.
**
**    ENDIF.
**
**    IF lv_error IS NOT INITIAL.
**
**      APPEND VALUE #(
**        %tky = ls_header-%tky
**      ) TO failed-railway_ord.
**
**      APPEND VALUE #(
**        %tky = ls_header-%tky
**        %msg = new_message_with_text(
**          severity = if_abap_behv_message=>severity-error
**          text     = lv_error
**        )
**      ) TO reported-railway_ord.
**
**      CONTINUE.
**    ENDIF.
**
**    DATA(lv_header_cid) = |RH_{ ls_header-confirmid }|.
**    DATA(lv_item_cid)   = |RI_{ ls_header-confirmid }|.
**
**    "One batch receipt for the total rejection quantity.
**    "No serial-number children are created.
**    MODIFY ENTITIES OF i_materialdocumenttp
**
**      ENTITY materialdocument
**        CREATE FIELDS (
**          documentdate
**          postingdate
**          goodsmovementcode
**        )
**        WITH VALUE #(
**          (
**            %cid              = lv_header_cid
**            documentdate      = ls_header-postingdate
**            postingdate       = ls_header-postingdate
**            goodsmovementcode = '02'
**          )
**        )
**
**        CREATE BY \_materialdocumentitem
**          FIELDS (
**            material
**            plant
**            storagelocation
**            batch
**            goodsmovementtype
**            manufacturingorder
**            manufacturingorderitem
**            goodsmovementrefdoctype
**            quantityinentryunit
**            entryunit
**          )
**          WITH VALUE #(
**            (
**              %cid_ref = lv_header_cid
**              %target = VALUE #(
**                (
**                  %cid                    = lv_item_cid
**                  material                = ls_header-material
**                  plant                   = ls_header-plant
**                  storagelocation         = lv_storage_location
**                  batch                   = ls_header-batch_number
**                  goodsmovementtype       = '101'
**                  manufacturingorder      = lv_order
**                  manufacturingorderitem  = '0001'
**                  goodsmovementrefdoctype = 'F'
**                  quantityinentryunit     = lv_total_quantity
**                  entryunit               = ls_header-unit
**                )
**              )
**            )
**          )
**
**      MAPPED DATA(ls_md_mapped)
**      FAILED DATA(ls_md_failed)
**      REPORTED DATA(ls_md_reported).
**
**    LOOP AT ls_md_reported-materialdocument
**      INTO DATA(ls_header_message).
**
**      IF ls_header_message-%msg IS BOUND.
**        APPEND VALUE #(
**          %tky = ls_header-%tky
**          %msg = ls_header_message-%msg
**        ) TO reported-railway_ord.
**      ENDIF.
**
**    ENDLOOP.
**
**    LOOP AT ls_md_reported-materialdocumentitem
**      INTO DATA(ls_item_message).
**
**      IF ls_item_message-%msg IS BOUND.
**        APPEND VALUE #(
**          %tky = ls_header-%tky
**          %msg = ls_item_message-%msg
**        ) TO reported-railway_ord.
**      ENDIF.
**
**    ENDLOOP.
**
**    IF ls_md_failed IS NOT INITIAL.
**
**      APPEND VALUE #(
**        %tky = ls_header-%tky
**      ) TO failed-railway_ord.
**
**      APPEND VALUE #(
**        %tky = ls_header-%tky
**        %msg = new_message_with_text(
**          severity = if_abap_behv_message=>severity-error
**          text     = 'Rejection material-document request failed'
**        )
**      ) TO reported-railway_ord.
**
**      CONTINUE.
**    ENDIF.
**
**    READ TABLE ls_md_mapped-materialdocument
**      INTO DATA(ls_created_document)
**      WITH KEY %cid = lv_header_cid.
**
**    IF sy-subrc <> 0.
**
**      APPEND VALUE #(
**        %tky = ls_header-%tky
**      ) TO failed-railway_ord.
**
**      APPEND VALUE #(
**        %tky = ls_header-%tky
**        %msg = new_message_with_text(
**          severity = if_abap_behv_message=>severity-error
**          text     = 'Material-document mapping was not returned'
**        )
**      ) TO reported-railway_ord.
**
**      CONTINUE.
**    ENDIF.
**
**    APPEND VALUE #(
**      confirm_id = ls_header-confirmid
**      pid        = ls_created_document-%pid
**    ) TO lcl_rejection_material_buffer=>entries.
**
**    "Ensure this header participates in the custom save sequence.
**    "Do not change confirmation status or SerialsPosted.
**       "Set POSTED after successful rejection processing.
**    MODIFY ENTITIES OF zi_railway_ord IN LOCAL MODE
**      ENTITY railway_ord
**        UPDATE FIELDS ( Status )
**        WITH VALUE #(
**          (
**            %tky   = ls_header-%tky
**            Status = 'POSTED'
**          )
**        )
**      FAILED DATA(ls_update_failed)
**      REPORTED DATA(ls_update_reported).
**
**    APPEND LINES OF ls_update_failed-railway_ord
**      TO failed-railway_ord.
**    APPEND LINES OF ls_update_reported-railway_ord
**      TO reported-railway_ord.
**
**    IF ls_update_failed IS NOT INITIAL.
**      CONTINUE.
**    ENDIF.
**
**      READ ENTITIES OF zi_railway_ord IN LOCAL MODE
**      ENTITY railway_ord
**        ALL FIELDS
**        WITH VALUE #( ( %tky = ls_header-%tky ) )
**      RESULT DATA(lt_updated_headers).
**
**    LOOP AT lt_updated_headers INTO DATA(ls_updated_header).
**
**      APPEND VALUE #(
**        %tky   = ls_updated_header-%tky
**        %param = ls_updated_header
**      ) TO result.
**
**    ENDLOOP.
**    APPEND VALUE #(
**      %tky = ls_header-%tky
**      %msg = new_message_with_text(
**        severity = if_abap_behv_message=>severity-information
**        text     = 'Batch rejection receipt accepted for saving'
**      )
**    ) TO reported-railway_ord.
**
**  ENDLOOP.
**
**ENDMETHOD.
*
*METHOD postrejection.
*
*  DATA:
*    lv_error            TYPE string,
*    lv_storage_location TYPE
*      i_materialdocumentitem_2-storagelocation,
*    lv_order            TYPE
*      i_manufacturingorder-manufacturingorder,
*    lv_total_quantity   TYPE ztb_rail_reject-quantity.
*
*  READ ENTITIES OF zi_railway_ord IN LOCAL MODE
*    ENTITY railway_ord
*      ALL FIELDS
*      WITH CORRESPONDING #( keys )
*    RESULT DATA(lt_headers)
*    FAILED DATA(ls_read_failed)
*    REPORTED DATA(ls_read_reported).
*
*  APPEND LINES OF ls_read_failed-railway_ord
*    TO failed-railway_ord.
*
*  APPEND LINES OF ls_read_reported-railway_ord
*    TO reported-railway_ord.
*
*  LOOP AT lt_headers INTO DATA(ls_header).
*
*    CLEAR:
*      lv_error,
*      lv_storage_location,
*      lv_order,
*      lv_total_quantity.
*
*    "Validate the saved header
*    IF ls_header-%is_draft = if_abap_behv=>mk-on.
*      lv_error = 'Save the record before posting goods receipt'.
*
*    ELSEIF ls_header-materialdocument IS NOT INITIAL.
*      lv_error =
*        'A material document is already assigned. Posting is blocked'.
*
*    ELSEIF ls_header-status <> 'POSTED'
*       AND ls_header-status <> 'PART_POST'.
*      lv_error = 'Complete Post Confirmation before posting goods receipt'.
*
*    ELSEIF ls_header-orderno IS INITIAL.
*      lv_error = 'Order number is required'.
*
*    ELSEIF ls_header-material IS INITIAL.
*      lv_error = 'Material is required'.
*
*    ELSEIF ls_header-plant IS INITIAL.
*      lv_error = 'Plant is required'.
*
*    ELSEIF ls_header-batch_number IS INITIAL.
*      lv_error = 'Batch number is required'.
*
*    ELSEIF ls_header-postingdate IS INITIAL.
*      lv_error = 'Posting date is required'.
*
*    ELSEIF ls_header-unit IS INITIAL.
*      lv_error = 'Confirmation unit is required'.
*    ENDIF.
*
*    IF lv_error IS NOT INITIAL.
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*      ) TO failed-railway_ord.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*        %msg = new_message_with_text(
*          severity = if_abap_behv_message=>severity-error
*          text     = lv_error
*        )
*      ) TO reported-railway_ord.
*
*      CONTINUE.
*    ENDIF.
*
*    "Without scrap, post the header yield as a batch goods receipt.
*    IF ls_header-scrapqty = 0.
*
*      lv_total_quantity = ls_header-qtytoconfirm.
*
*      IF lv_total_quantity <= 0.
*        lv_error = 'Quantity to Confirm must be greater than zero'.
*      ENDIF.
*
*    ELSEIF ls_header-scrapqty < 0.
*
*      lv_error = 'Scrap Quantity cannot be negative'.
*
*    ELSE.
*
*    "Read saved rejection rows
*    READ ENTITIES OF zi_railway_ord IN LOCAL MODE
*      ENTITY railway_ord BY \_REJECTION
*        ALL FIELDS
*        WITH VALUE #( ( %tky = ls_header-%tky ) )
*      RESULT DATA(lt_rejections)
*      FAILED DATA(ls_child_failed)
*      REPORTED DATA(ls_child_reported).
*
*      "Update Rejection Display Unit
**IF lt_rejections IS NOT INITIAL.
**
**  MODIFY ENTITIES OF zi_railway_ord IN LOCAL MODE
**    ENTITY rejection
**      UPDATE FIELDS ( DisplayREJUnit )
**      WITH VALUE #(
**        FOR ls_rejection IN lt_rejections
**        (
**          %tky = ls_rejection-%tky
**
**          DisplayREJUnit = COND #(
**            WHEN ls_rejection-Unit = 'ST'
**            THEN 'PC'
**            ELSE ls_rejection-Unit
**          )
**        )
**      )
**    FAILED DATA(ls_unit_failed)
**    REPORTED DATA(ls_unit_reported).
**
**ENDIF.
*
*    APPEND LINES OF ls_child_failed-railway_ord
*      TO failed-railway_ord.
*    APPEND LINES OF ls_child_failed-rejection
*      TO failed-rejection.
*
*    APPEND LINES OF ls_child_reported-railway_ord
*      TO reported-railway_ord.
*    APPEND LINES OF ls_child_reported-rejection
*      TO reported-rejection.
*
*    IF ls_child_failed IS NOT INITIAL.
*      lv_error = 'Unable to read rejection items'.
*
*    ELSEIF lt_rejections IS INITIAL.
*      lv_error = 'No rejection items available for posting'.
*
*    ELSE.
*      LOOP AT lt_rejections INTO DATA(ls_rejection).
*
*        IF ls_rejection-rejectionreason IS INITIAL.
*          lv_error = 'Enter a rejection reason on every row'.
*          EXIT.
*        ENDIF.
*
**        IF ls_rejection-quantity <= 0.
**          lv_error =
**            'Every rejection row must have a quantity greater than zero'.
**          EXIT.
**        ENDIF.
*
*        IF ls_rejection-unit <> ls_header-unit.
*          lv_error =
*            'Rejection units must match the header confirmation unit'.
*          EXIT.
*        ENDIF.
*
*        lv_total_quantity =
*          lv_total_quantity + ls_rejection-quantity.
*
*      ENDLOOP.
*    ENDIF.
*
*    ENDIF.
*
*    "Use the manufacturing order receiving storage location
*    IF lv_error IS INITIAL.
*
*      lv_order = ls_header-orderno.
*      lv_order = |{ lv_order ALPHA = IN }|.
*
*      SELECT SINGLE
*        FROM i_manufacturingorderitem
*        FIELDS storagelocation
*        WHERE manufacturingorder = @lv_order
*          AND manufacturingorderitem = '0001'
*        INTO @lv_storage_location.
*
*      IF sy-subrc <> 0 OR lv_storage_location IS INITIAL.
*        lv_error =
*          'Storage location not found in manufacturing order item'.
*      ENDIF.
*
*    ENDIF.
*
*    IF lv_error IS NOT INITIAL.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*      ) TO failed-railway_ord.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*        %msg = new_message_with_text(
*          severity = if_abap_behv_message=>severity-error
*          text     = lv_error
*        )
*      ) TO reported-railway_ord.
*
*      CONTINUE.
*    ENDIF.
*
*    DATA(lv_header_cid) = |RH_{ ls_header-confirmid }|.
*    DATA(lv_item_cid)   = |RI_{ ls_header-confirmid }|.
*
*    "One batch receipt for the selected receipt quantity.
*    "No serial-number children are created.
*    MODIFY ENTITIES OF i_materialdocumenttp
*
*      ENTITY materialdocument
*        CREATE FIELDS (
*          documentdate
*          postingdate
*          goodsmovementcode
*        )
*        WITH VALUE #(
*          (
*            %cid              = lv_header_cid
*            documentdate      = ls_header-postingdate
*            postingdate       = ls_header-postingdate
*            goodsmovementcode = '02'
*          )
*        )
*
*        CREATE BY \_materialdocumentitem
*          FIELDS (
*            material
*            plant
*            storagelocation
*            batch
*            goodsmovementtype
*            manufacturingorder
*            manufacturingorderitem
*            goodsmovementrefdoctype
*            quantityinentryunit
*            entryunit
*          )
*          WITH VALUE #(
*            (
*              %cid_ref = lv_header_cid
*              %target = VALUE #(
*                (
*                  %cid                    = lv_item_cid
*                  material                = ls_header-material
*                  plant                   = ls_header-plant
*                  storagelocation         = lv_storage_location
*                  batch                   = ls_header-batch_number
*                  goodsmovementtype       = '101'
*                  manufacturingorder      = lv_order
*                  manufacturingorderitem  = '0001'
*                  goodsmovementrefdoctype = 'F'
*                  quantityinentryunit     = ls_header-QtyToConfirm
*                  entryunit               = ls_header-unit
*                )
*              )
*            )
*          )
*
*      MAPPED DATA(ls_md_mapped)
*      FAILED DATA(ls_md_failed)
*      REPORTED DATA(ls_md_reported).
*
*    LOOP AT ls_md_reported-materialdocument
*      INTO DATA(ls_header_message).
*
*      IF ls_header_message-%msg IS BOUND.
*        APPEND VALUE #(
*          %tky = ls_header-%tky
*          %msg = ls_header_message-%msg
*        ) TO reported-railway_ord.
*      ENDIF.
*
*    ENDLOOP.
*
*    LOOP AT ls_md_reported-materialdocumentitem
*      INTO DATA(ls_item_message).
*
*      IF ls_item_message-%msg IS BOUND.
*        APPEND VALUE #(
*          %tky = ls_header-%tky
*          %msg = ls_item_message-%msg
*        ) TO reported-railway_ord.
*      ENDIF.
*
*    ENDLOOP.
*
*    IF ls_md_failed IS NOT INITIAL.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*      ) TO failed-railway_ord.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*        %msg = new_message_with_text(
*          severity = if_abap_behv_message=>severity-error
*          text     = 'Goods receipt material-document request failed'
*        )
*      ) TO reported-railway_ord.
*
*      CONTINUE.
*    ENDIF.
*
*    READ TABLE ls_md_mapped-materialdocument
*      INTO DATA(ls_created_document)
*      WITH KEY %cid = lv_header_cid.
*
*    IF sy-subrc <> 0.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*      ) TO failed-railway_ord.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*        %msg = new_message_with_text(
*          severity = if_abap_behv_message=>severity-error
*          text     = 'Material-document mapping was not returned'
*        )
*      ) TO reported-railway_ord.
*
*      CONTINUE.
*    ENDIF.
*
*    APPEND VALUE #(
*      confirm_id = ls_header-confirmid
*      pid        = ls_created_document-%pid
*    ) TO lcl_rejection_material_buffer=>entries.
*
*    "Ensure this header participates in the custom save sequence.
*    "Keep SerialsPosted unchanged.
*       "Set POSTED after successful rejection processing.
*    MODIFY ENTITIES OF zi_railway_ord IN LOCAL MODE
*      ENTITY railway_ord
*        UPDATE FIELDS ( Status )
*        WITH VALUE #(
*          (
*            %tky   = ls_header-%tky
*            Status = 'POSTED'
*          )
*        )
*      FAILED DATA(ls_update_failed)
*      REPORTED DATA(ls_update_reported).
*
*    APPEND LINES OF ls_update_failed-railway_ord
*      TO failed-railway_ord.
*    APPEND LINES OF ls_update_reported-railway_ord
*      TO reported-railway_ord.
*
*    IF ls_update_failed IS NOT INITIAL.
*      CONTINUE.
*    ENDIF.
*
*      READ ENTITIES OF zi_railway_ord IN LOCAL MODE
*      ENTITY railway_ord
*        ALL FIELDS
*        WITH VALUE #( ( %tky = ls_header-%tky ) )
*      RESULT DATA(lt_updated_headers).
*
*    LOOP AT lt_updated_headers INTO DATA(ls_updated_header).
*
*      APPEND VALUE #(
*        %tky   = ls_updated_header-%tky
*        %param = ls_updated_header
*      ) TO result.
*
*    ENDLOOP.
*    APPEND VALUE #(
*      %tky = ls_header-%tky
*      %msg = new_message_with_text(
*        severity = if_abap_behv_message=>severity-information
*        text     = 'Batch goods receipt accepted for saving'
*      )
*    ) TO reported-railway_ord.
*
*  ENDLOOP.
*
*ENDMETHOD.
*
*
*
*METHOD cancelrejection.
*
*  READ ENTITIES OF zi_railway_ord IN LOCAL MODE
*    ENTITY railway_ord
*      ALL FIELDS
*      WITH CORRESPONDING #( keys )
*    RESULT DATA(lt_headers)
*    FAILED DATA(ls_read_failed)
*    REPORTED DATA(ls_read_reported).
*
*  APPEND LINES OF ls_read_failed-railway_ord
*    TO failed-railway_ord.
*
*  APPEND LINES OF ls_read_reported-railway_ord
*    TO reported-railway_ord.
*
*  DATA(lv_reversal_date) =
*    cl_abap_context_info=>get_system_date( ).
*
*  LOOP AT lt_headers INTO DATA(ls_header).
*
*    DATA(lv_error) = CONV string( '' ).
*
*    "Validate the saved rejection document.
*    IF ls_header-%is_draft = if_abap_behv=>mk-on.
*
*      lv_error =
*        'Save the record before cancelling rejection posting'.
*
*    ELSEIF ls_header-materialdocument IS INITIAL
*        OR ls_header-materialdocumentyear IS INITIAL.
*
*      lv_error =
*        'No posted rejection material document is assigned'.
*
*    ENDIF.
*
*    IF lv_error IS NOT INITIAL.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*      ) TO failed-railway_ord.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*        %msg = new_message_with_text(
*          severity = if_abap_behv_message=>severity-error
*          text     = lv_error
*        )
*      ) TO reported-railway_ord.
*
*      CONTINUE.
*
*    ENDIF.
*
*    "Cancel the original document.
*    "SAP reverses its original batch and quantity.
*    MODIFY ENTITIES OF i_materialdocumenttp
*      ENTITY materialdocument
*        EXECUTE cancel
*        FROM VALUE #(
*          (
*            %tky-materialdocument =
*              ls_header-materialdocument
*
*            %tky-materialdocumentyear =
*              ls_header-materialdocumentyear
*
*            %tky-%is_draft =
*              if_abap_behv=>mk-off
*
*            %param-postingdate =
*              lv_reversal_date
*          )
*        )
*      RESULT DATA(lt_cancel_result)
*      FAILED DATA(ls_cancel_failed)
*      REPORTED DATA(ls_cancel_reported).
*
*    "Forward material document header messages.
*    LOOP AT ls_cancel_reported-materialdocument
*      INTO DATA(ls_header_message).
*
*      IF ls_header_message-%msg IS BOUND.
*
*        APPEND VALUE #(
*          %tky = ls_header-%tky
*          %msg = ls_header_message-%msg
*        ) TO reported-railway_ord.
*
*      ENDIF.
*
*    ENDLOOP.
*
*    "Forward material document item messages.
*    LOOP AT ls_cancel_reported-materialdocumentitem
*      INTO DATA(ls_item_message).
*
*      IF ls_item_message-%msg IS BOUND.
*
*        APPEND VALUE #(
*          %tky = ls_header-%tky
*          %msg = ls_item_message-%msg
*        ) TO reported-railway_ord.
*
*      ENDIF.
*
*    ENDLOOP.
*
*    IF ls_cancel_failed IS NOT INITIAL.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*      ) TO failed-railway_ord.
*
*      APPEND VALUE #(
*        %tky = ls_header-%tky
*        %msg = new_message_with_text(
*          severity = if_abap_behv_message=>severity-error
*          text =
*            'Rejection material document cancellation failed'
*        )
*      ) TO reported-railway_ord.
*
*      CONTINUE.
*
*    ENDIF.
*
*    "Retain the original document reference for traceability.
*    "The production confirmation status is unchanged.
*    APPEND VALUE #(
*      %tky   = ls_header-%tky
*      %param = ls_header
*    ) TO result.
*
*    APPEND VALUE #(
*      %tky = ls_header-%tky
*      %msg = new_message_with_text(
*        severity = if_abap_behv_message=>severity-success
*        text =
*          |Rejection cancellation accepted for material document { ls_header-materialdocument }/{ ls_header-materialdocumentyear }|
*      )
*    ) TO reported-railway_ord.
*
*  ENDLOOP.
*
*ENDMETHOD.
*
*ENDCLASS.
*
*
*CLASS lsc_zi_railway_ord DEFINITION
*  INHERITING FROM cl_abap_behavior_saver.
*
*  PROTECTED SECTION.
*
*    METHODS save_modified REDEFINITION.
*    METHODS cleanup_finalize REDEFINITION.
*
*ENDCLASS.
*
*
*CLASS lsc_zi_railway_ord IMPLEMENTATION.
*
*  METHOD save_modified.
*
*  LOOP AT lcl_confirmation_buffer=>entries
*    INTO DATA(ls_entry).
*
*    CONVERT KEY OF i_productionordconfirmationtp
*      FROM ls_entry-pid
*      TO DATA(ls_confirmation_key).
*
*    UPDATE ztb_railway_ord
*      SET confirmation_group =
*            @ls_confirmation_key-confirmationgroup,
*          confirmation_count =
*            @ls_confirmation_key-confirmationcount
*      WHERE confirm_id = @ls_entry-confirm_id.
*
*  ENDLOOP.
*
*  LOOP AT lcl_rejection_material_buffer=>entries
*    INTO DATA(ls_rejection_entry).
*
*    CONVERT KEY OF i_materialdocumenttp
*      FROM ls_rejection_entry-pid
*      TO DATA(ls_rejection_document_key).
*
*    UPDATE ztb_railway_ord
*      SET material_document =
*            @ls_rejection_document_key-materialdocument,
*          material_document_year =
*            @ls_rejection_document_key-materialdocumentyear
*      WHERE confirm_id = @ls_rejection_entry-confirm_id.
*
*  ENDLOOP.
*
*ENDMETHOD.
*
*
*  METHOD cleanup_finalize.
*
*       CLEAR:
*    lcl_confirmation_buffer=>entries,
*    lcl_rejection_material_buffer=>entries.
*
*  ENDMETHOD.
*
*ENDCLASS.
