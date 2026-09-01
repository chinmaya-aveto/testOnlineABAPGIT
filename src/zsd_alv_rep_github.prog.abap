*&---------------------------------------------------------------------*
*& Report ZSD_ALV_REP_GITHUB
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT ZSD_ALV_REP_GITHUB.
*&---------------------------------------------------------------------*
*& Report ZR_SALES_ORDER_ALV
*& Description: Standard OO ALV Report for Sales Orders (VBAK & VBAP)
*&---------------------------------------------------------------------

*----------------------------------------------------------------------*
* Selection Screen
*----------------------------------------------------------------------*
TABLES: vbak, vbap.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  SELECT-OPTIONS: s_vbeln FOR vbak-vbeln,          " Sales Document
                  s_erdat FOR vbak-erdat,          " Created On
                  s_auart FOR vbak-auart,          " Sales Document Type
                  s_matnr FOR vbap-matnr.          " Material Number
SELECTION-SCREEN END OF BLOCK b1.

*----------------------------------------------------------------------*
* Local Class Definition
*----------------------------------------------------------------------*
CLASS lcl_sales_alv DEFINITION.
  PUBLIC SECTION.
    " Output Structure Definition
    TYPES: BEGIN OF ty_output,
             vbeln TYPE vbak-vbeln,
             erdat TYPE vbak-erdat,
             auart TYPE vbak-auart,
             kunnr TYPE vbak-kunnr,
             posnr TYPE vbap-posnr,
             matnr TYPE vbap-matnr,
             arktx TYPE vbap-arktx,
             kwmeng TYPE vbap-kwmeng,
             vrkme TYPE vbap-vrkme,
             netwr TYPE vbap-netwr,
             waerk TYPE vbak-waerk,
           END OF ty_output.

    TYPES: tt_output TYPE STANDARD TABLE OF ty_output WITH DEFAULT KEY.

    METHODS:
      get_data,
      display_alv.

  PRIVATE SECTION.
    DATA: mt_output TYPE tt_output,
          mo_salv   TYPE REF TO cl_salv_table.

    METHODS:
      optimize_columns,
      set_functions,
      set_layout.
ENDCLASS.

*----------------------------------------------------------------------*
* Local Class Implementation
*----------------------------------------------------------------------*
CLASS lcl_sales_alv IMPLEMENTATION.

  METHOD get_data.
    " Fetch Header and Item details joining VBAK and VBAP
    SELECT a~vbeln,
           a~erdat,
           a~auart,
           a~kunnr,
           b~posnr,
           b~matnr,
           b~arktx,
           b~kwmeng,
           b~vrkme,
           b~netwr,
           a~waerk
      FROM vbak AS a
      INNER JOIN vbap AS b ON a~vbeln = b~vbeln
      INTO TABLE @mt_output
      WHERE a~vbeln IN @s_vbeln
        AND a~erdat IN @s_erdat
        AND a~auart IN @s_auart
        AND b~matnr IN @s_matnr.

    IF mt_output IS INITIAL.
      MESSAGE 'No records found for the selected criteria.' TYPE 'S' DISPLAY LIKE 'E'.
      LEAVE LIST-PROCESSING.
    ENDIF.
  ENDMETHOD.

  METHOD display_alv.
    TRY.
        " Instantiate SALV Object
        cl_salv_table=>factory(
          IMPORTING
            r_salv_table = mo_salv
          CHANGING
            t_table      = mt_output ).

        " Apply Formatting Configurations
        set_functions( ).
        optimize_columns( ).
        set_layout( ).

        " Display Table
        mo_salv->display( ).

      CATCH cx_salv_msg INTO DATA(lx_salv_msg).
        MESSAGE lx_salv_msg->get_text( ) TYPE 'E'.
    ENDTRY.
  ENDMETHOD.

  METHOD set_functions.
    " Enable standard ALV toolbar features (Sort, Filter, Export to Excel, etc.)
    DATA(lo_functions) = mo_salv->get_functions( ).
    lo_functions->set_all( abap_true ).
  ENDMETHOD.

  METHOD optimize_columns.
    " Auto-fit column widths to content length
    DATA(lo_columns) = mo_salv->get_columns( ).
    lo_columns->set_optimize( abap_true ).

    " Set Currency Reference for Net Value (Netwr)
    TRY.
        DATA(lo_column) = CAST cl_salv_column_table( lo_columns->get_column( 'NETWR' ) ).
        lo_column->set_currency_column( 'WAERK' ).
      CATCH cx_salv_not_found.
    ENDTRY.
  ENDMETHOD.

  METHOD set_layout.
    " Enable Zebra Striping on ALV Grid
    DATA(lo_display) = mo_salv->get_display_settings( ).
    lo_display->set_striped_pattern( abap_true ).
    lo_display->set_list_header( 'Sales Order Details Report' ).
  ENDMETHOD.

ENDCLASS.

*----------------------------------------------------------------------*
* Initialization & Execution
*----------------------------------------------------------------------*
START-OF-SELECTION.
  DATA(lo_report) = NEW lcl_sales_alv( ).
  lo_report->get_data( ).
  lo_report->display_alv( ).
