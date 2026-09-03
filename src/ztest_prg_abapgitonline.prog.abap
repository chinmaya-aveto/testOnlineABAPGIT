*&---------------------------------------------------------------------*
*& Report ZTEST_PRG_ABAPGITONLINE
*& Description: Simple SALV report of sales order items by plant
*& Compatible: SAP ECC 6.0 EHP8 (SAP_BASIS 750)
*&---------------------------------------------------------------------*
REPORT ztest_prg_abapgitonline.

TABLES: vbak, vbap.

*----------------------------------------------------------------------*
* Selection Screen
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE text-001.
  PARAMETERS     p_werks TYPE werks_d OBLIGATORY.
  SELECT-OPTIONS s_vbeln FOR vbak-vbeln.
  SELECT-OPTIONS s_erdat FOR vbak-erdat.
SELECTION-SCREEN END OF BLOCK b1.

*----------------------------------------------------------------------*
* Local Class
*----------------------------------------------------------------------*
CLASS lcl_report DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_output,
             vbeln  TYPE vbak-vbeln,
             posnr  TYPE vbap-posnr,
             auart  TYPE vbak-auart,
             kunnr  TYPE vbak-kunnr,
             matnr  TYPE vbap-matnr,
             werks  TYPE vbap-werks,
             kwmeng TYPE vbap-kwmeng,
             vrkme  TYPE vbap-vrkme,
             netwr  TYPE vbap-netwr,
             waerk  TYPE vbak-waerk,
           END OF ty_output.

    TYPES tt_output TYPE STANDARD TABLE OF ty_output WITH DEFAULT KEY.

    METHODS:
      validate_plant,
      get_data,
      display_alv.

  PRIVATE SECTION.
    DATA:
      mt_output TYPE tt_output,
      mo_salv   TYPE REF TO cl_salv_table.

    METHODS:
      set_functions,
      set_columns,
      set_layout.
ENDCLASS.

CLASS lcl_report IMPLEMENTATION.

  METHOD validate_plant.
    DATA lv_werks TYPE werks_d.

    SELECT SINGLE werks
      FROM t001w
      INTO lv_werks
      WHERE werks = p_werks.

    IF sy-subrc <> 0.
      MESSAGE |Plant { p_werks } does not exist| TYPE 'E'.
    ENDIF.
  ENDMETHOD.

  METHOD get_data.
    TRY.
        SELECT a~vbeln,
               b~posnr,
               a~auart,
               a~kunnr,
               b~matnr,
               b~werks,
               b~kwmeng,
               b~vrkme,
               b~netwr,
               a~waerk
          FROM vbak AS a
          INNER JOIN vbap AS b
            ON a~vbeln = b~vbeln
          INTO TABLE @mt_output
          WHERE b~werks  =  @p_werks
            AND a~vbeln IN @s_vbeln
            AND a~erdat IN @s_erdat.

      CATCH cx_sy_open_sql_error INTO DATA(lx_sql).
        MESSAGE lx_sql->get_text( ) TYPE 'E'.
    ENDTRY.

    IF mt_output IS INITIAL.
      MESSAGE 'No sales order items found for the plant.' TYPE 'S' DISPLAY LIKE 'E'.
      LEAVE LIST-PROCESSING.
    ENDIF.
  ENDMETHOD.

  METHOD display_alv.
    TRY.
        cl_salv_table=>factory(
          IMPORTING
            r_salv_table = mo_salv
          CHANGING
            t_table      = mt_output ).

        set_functions( ).
        set_columns( ).
        set_layout( ).

        mo_salv->display( ).

      CATCH cx_salv_msg INTO DATA(lx_salv).
        MESSAGE lx_salv->get_text( ) TYPE 'E'.
    ENDTRY.
  ENDMETHOD.

  METHOD set_functions.
    DATA(lo_functions) = mo_salv->get_functions( ).
    lo_functions->set_all( abap_true ).
  ENDMETHOD.

  METHOD set_columns.
    DATA(lo_columns) = mo_salv->get_columns( ).
    lo_columns->set_optimize( abap_true ).

    TRY.
        DATA(lo_qty) = CAST cl_salv_column_table( lo_columns->get_column( 'KWMENG' ) ).
        lo_qty->set_quantity_column( 'VRKME' ).

        DATA(lo_net) = CAST cl_salv_column_table( lo_columns->get_column( 'NETWR' ) ).
        lo_net->set_currency_column( 'WAERK' ).

      CATCH cx_salv_not_found
            cx_salv_data_error.
        MESSAGE 'Could not set quantity/currency column references.' TYPE 'S' DISPLAY LIKE 'W'.
    ENDTRY.
  ENDMETHOD.

  METHOD set_layout.
    DATA(lo_display) = mo_salv->get_display_settings( ).
    lo_display->set_striped_pattern( abap_true ).
    lo_display->set_list_header( |Sales order items for plant { p_werks }| ).
  ENDMETHOD.

ENDCLASS.

*----------------------------------------------------------------------*
* Events
*----------------------------------------------------------------------*
AT SELECTION-SCREEN.
  DATA(lo_check) = NEW lcl_report( ).
  lo_check->validate_plant( ).

START-OF-SELECTION.
  DATA(lo_report) = NEW lcl_report( ).
  lo_report->get_data( ).
  lo_report->display_alv( ).
