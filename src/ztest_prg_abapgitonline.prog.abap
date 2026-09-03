*&---------------------------------------------------------------------*
*& Report ZTEST_PRG_ABAPGITONLINE
*& Description: SALV report + HTML/SVG dashboard for sales items by plant
*& Compatible: SAP ECC 6.0 EHP8 (SAP_BASIS 750)
*&---------------------------------------------------------------------*
REPORT ztest_prg_abapgitonline.

TYPE-POOLS: cntl.

TABLES: vbak, vbap.

*----------------------------------------------------------------------*
* Selection Screen
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE text-001.
  PARAMETERS     p_werks TYPE werks_d OBLIGATORY.
  SELECT-OPTIONS s_vbeln FOR vbak-vbeln.
  SELECT-OPTIONS s_erdat FOR vbak-erdat.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE text-002.
  SELECTION-SCREEN PUSHBUTTON 1(22) p_dash USER-COMMAND dash.
SELECTION-SCREEN END OF BLOCK b2.

*----------------------------------------------------------------------*
* Local Class
*----------------------------------------------------------------------*
CLASS lcl_report DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_output,
             vbeln  TYPE vbak-vbeln,
             posnr  TYPE vbap-posnr,
             erdat  TYPE vbak-erdat,
             auart  TYPE vbak-auart,
             kunnr  TYPE vbak-kunnr,
             matnr  TYPE vbap-matnr,
             werks  TYPE vbap-werks,
             kwmeng TYPE vbap-kwmeng,
             vrkme  TYPE vbap-vrkme,
             netwr  TYPE vbap-netwr,
             waerk  TYPE vbak-waerk,
           END OF ty_output.

    TYPES: BEGIN OF ty_slice,
             key   TYPE c LENGTH 40,
             items TYPE i,
             qty   TYPE vbap-kwmeng,
             netwr TYPE vbap-netwr,
             pct   TYPE p LENGTH 5 DECIMALS 1,
             color TYPE c LENGTH 7,
           END OF ty_slice.

    TYPES tt_output TYPE STANDARD TABLE OF ty_output WITH DEFAULT KEY.
    TYPES tt_slice  TYPE STANDARD TABLE OF ty_slice WITH DEFAULT KEY.
    TYPES ty_html   TYPE c LENGTH 255.
    TYPES tt_html   TYPE STANDARD TABLE OF ty_html WITH DEFAULT KEY.

    METHODS:
      validate_plant,
      get_data
        RETURNING VALUE(rv_ok) TYPE abap_bool,
      display_alv,
      display_dashboard,
      close_dashboard.

  PRIVATE SECTION.
    DATA:
      mt_output TYPE tt_output,
      mt_auart  TYPE tt_slice,
      mt_kunnr  TYPE tt_slice,
      mt_matnr  TYPE tt_slice,
      mo_salv   TYPE REF TO cl_salv_table,
      mo_dialog TYPE REF TO cl_gui_dialogbox_container,
      mo_html   TYPE REF TO cl_gui_html_viewer,
      mv_orders TYPE i,
      mv_items  TYPE i,
      mv_cust   TYPE i,
      mv_mats   TYPE i,
      mv_qty    TYPE vbap-kwmeng,
      mv_netwr  TYPE vbap-netwr,
      mv_avg    TYPE vbap-netwr,
      mv_waerk  TYPE vbak-waerk,
      mv_from   TYPE vbak-erdat,
      mv_to     TYPE vbak-erdat.

    METHODS:
      set_functions,
      set_columns,
      set_layout,
      register_events,
      build_summary,
      add_slice
        IMPORTING iv_key   TYPE clike
                  iv_qty   TYPE vbap-kwmeng
                  iv_netwr TYPE vbap-netwr
        CHANGING  ct_slice TYPE tt_slice,
      finish_slices
        CHANGING ct_slice TYPE tt_slice,
      color_for
        IMPORTING iv_index       TYPE i
        RETURNING VALUE(rv_color) TYPE ty_slice-color,
      fmt_amt
        IMPORTING iv_amt         TYPE numeric
        RETURNING VALUE(rv_text) TYPE string,
      build_html
        RETURNING VALUE(rv_html) TYPE string,
      build_kpi
        IMPORTING iv_label       TYPE clike
                  iv_value       TYPE clike
                  iv_color       TYPE clike
        RETURNING VALUE(rv_html) TYPE string,
      build_table
        IMPORTING it_slice       TYPE tt_slice
        RETURNING VALUE(rv_html) TYPE string,
      build_bars
        IMPORTING it_slice       TYPE tt_slice
        RETURNING VALUE(rv_html) TYPE string,
      build_pie_svg
        IMPORTING it_slice       TYPE tt_slice
                  iv_total       TYPE vbap-netwr
        RETURNING VALUE(rv_svg)  TYPE string,
      html_to_table
        IMPORTING iv_html        TYPE string
        RETURNING VALUE(rt_html) TYPE tt_html,
      free_dashboard,
      on_close FOR EVENT close OF cl_gui_dialogbox_container
        IMPORTING sender,
      on_sapevent FOR EVENT sapevent OF cl_gui_html_viewer
        IMPORTING action.
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
    CLEAR: mt_output, rv_ok.

    TRY.
        SELECT a~vbeln,
               b~posnr,
               a~erdat,
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
        MESSAGE lx_sql->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    IF mt_output IS INITIAL.
      MESSAGE 'No sales order items found for the plant.' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    rv_ok = abap_true.
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

  METHOD display_dashboard.
    DATA: lv_url  TYPE c LENGTH 2048,
          lt_html TYPE tt_html.

    build_summary( ).
    lt_html = html_to_table( build_html( ) ).
    free_dashboard( ).

    TRY.
        mo_dialog = NEW cl_gui_dialogbox_container(
          width   = 1120
          height  = 740
          top     = 30
          left    = 40
          caption = |Dashboard - Plant { p_werks }| ).

        mo_html = NEW cl_gui_html_viewer( parent = mo_dialog ).
        register_events( ).

      CATCH cx_root INTO DATA(lx_gui).
        MESSAGE lx_gui->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
        free_dashboard( ).
        RETURN.
    ENDTRY.

    mo_html->load_data(
      EXPORTING
        type                 = 'text'
        subtype              = 'html'
      IMPORTING
        assigned_url         = lv_url
      CHANGING
        data_table           = lt_html
      EXCEPTIONS
        dp_invalid_parameter = 1
        dp_error_general     = 2
        cntl_error           = 3
        OTHERS               = 4 ).

    IF sy-subrc <> 0 OR lv_url IS INITIAL.
      MESSAGE 'Could not load the dashboard view.' TYPE 'S' DISPLAY LIKE 'E'.
      free_dashboard( ).
      RETURN.
    ENDIF.

    mo_html->show_url(
      EXPORTING
        url        = lv_url
      EXCEPTIONS
        cntl_error = 1
        OTHERS     = 2 ).

    IF sy-subrc <> 0.
      MESSAGE 'Could not display the dashboard view.' TYPE 'S' DISPLAY LIKE 'E'.
      free_dashboard( ).
      RETURN.
    ENDIF.

    cl_gui_cfw=>flush( EXCEPTIONS OTHERS = 1 ).
  ENDMETHOD.

  METHOD register_events.
    DATA: lt_events TYPE cntl_simple_events,
          ls_event  TYPE cntl_simple_event.

    ls_event-eventid    = cl_gui_dialogbox_container=>eventid_close.
    ls_event-appl_event = abap_true.
    APPEND ls_event TO lt_events.

    mo_dialog->set_registered_events(
      EXPORTING
        events                    = lt_events
      EXCEPTIONS
        cntl_error                = 1
        cntl_system_error         = 2
        illegal_event_combination = 3
        OTHERS                    = 4 ).

    SET HANDLER on_close FOR mo_dialog.

    CLEAR: lt_events, ls_event.
    ls_event-eventid    = cl_gui_html_viewer=>m_id_sapevent.
    ls_event-appl_event = abap_true.
    APPEND ls_event TO lt_events.

    mo_html->set_registered_events(
      EXPORTING
        events                    = lt_events
      EXCEPTIONS
        cntl_error                = 1
        cntl_system_error         = 2
        illegal_event_combination = 3
        OTHERS                    = 4 ).

    SET HANDLER on_sapevent FOR mo_html.
  ENDMETHOD.

  METHOD close_dashboard.
    free_dashboard( ).
  ENDMETHOD.

  METHOD build_summary.
    DATA: lt_ord TYPE HASHED TABLE OF vbak-vbeln WITH UNIQUE KEY table_line,
          lt_cus TYPE HASHED TABLE OF vbak-kunnr WITH UNIQUE KEY table_line,
          lt_mat TYPE HASHED TABLE OF vbap-matnr WITH UNIQUE KEY table_line,
          lt_cur TYPE HASHED TABLE OF vbak-waerk WITH UNIQUE KEY table_line.

    CLEAR: mt_auart, mt_kunnr, mt_matnr,
           mv_orders, mv_items, mv_cust, mv_mats, mv_qty, mv_netwr, mv_avg, mv_waerk,
           mv_from, mv_to.

    mv_items = lines( mt_output ).

    LOOP AT mt_output ASSIGNING FIELD-SYMBOL(<ls_out>).
      INSERT <ls_out>-vbeln INTO TABLE lt_ord.
      INSERT <ls_out>-kunnr INTO TABLE lt_cus.
      INSERT <ls_out>-matnr INTO TABLE lt_mat.
      INSERT <ls_out>-waerk INTO TABLE lt_cur.

      mv_netwr = mv_netwr + <ls_out>-netwr.
      mv_qty   = mv_qty   + <ls_out>-kwmeng.

      IF mv_from IS INITIAL OR <ls_out>-erdat < mv_from.
        mv_from = <ls_out>-erdat.
      ENDIF.
      IF <ls_out>-erdat > mv_to.
        mv_to = <ls_out>-erdat.
      ENDIF.

      add_slice( EXPORTING iv_key = <ls_out>-auart iv_qty = <ls_out>-kwmeng iv_netwr = <ls_out>-netwr
                 CHANGING  ct_slice = mt_auart ).
      add_slice( EXPORTING iv_key = <ls_out>-kunnr iv_qty = <ls_out>-kwmeng iv_netwr = <ls_out>-netwr
                 CHANGING  ct_slice = mt_kunnr ).
      add_slice( EXPORTING iv_key = <ls_out>-matnr iv_qty = <ls_out>-kwmeng iv_netwr = <ls_out>-netwr
                 CHANGING  ct_slice = mt_matnr ).
    ENDLOOP.

    mv_orders = lines( lt_ord ).
    mv_cust   = lines( lt_cus ).
    mv_mats   = lines( lt_mat ).

    IF mv_orders > 0.
      mv_avg = mv_netwr / mv_orders.
    ENDIF.

    IF lines( lt_cur ) = 1.
      LOOP AT lt_cur INTO mv_waerk.
        EXIT.
      ENDLOOP.
    ELSE.
      mv_waerk = 'MULTI'.
    ENDIF.

    finish_slices( CHANGING ct_slice = mt_auart ).
    finish_slices( CHANGING ct_slice = mt_kunnr ).
    finish_slices( CHANGING ct_slice = mt_matnr ).
  ENDMETHOD.

  METHOD add_slice.
    READ TABLE ct_slice ASSIGNING FIELD-SYMBOL(<ls>)
      WITH KEY key = iv_key.
    IF sy-subrc <> 0.
      APPEND VALUE ty_slice( key = iv_key ) TO ct_slice ASSIGNING <ls>.
    ENDIF.
    <ls>-items = <ls>-items + 1.
    <ls>-qty   = <ls>-qty + iv_qty.
    <ls>-netwr = <ls>-netwr + iv_netwr.
  ENDMETHOD.

  METHOD finish_slices.
    DATA: ls_oth TYPE ty_slice,
          lv_idx TYPE i.

    SORT ct_slice BY netwr DESCENDING.

    IF lines( ct_slice ) > 6.
      LOOP AT ct_slice ASSIGNING FIELD-SYMBOL(<ls>) FROM 7.
        ls_oth-items = ls_oth-items + <ls>-items.
        ls_oth-qty   = ls_oth-qty   + <ls>-qty.
        ls_oth-netwr = ls_oth-netwr + <ls>-netwr.
      ENDLOOP.
      DELETE ct_slice FROM 7.
      ls_oth-key = 'Others'.
      APPEND ls_oth TO ct_slice.
    ENDIF.

    LOOP AT ct_slice ASSIGNING <ls>.
      lv_idx = lv_idx + 1.
      <ls>-color = color_for( lv_idx ).
      IF mv_netwr > 0.
        <ls>-pct = ( <ls>-netwr * 100 ) / mv_netwr.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD color_for.
    DATA(lv_mod) = iv_index MOD 8.
    IF lv_mod = 0.
      lv_mod = 8.
    ENDIF.
    CASE lv_mod.
      WHEN 1. rv_color = '#1F77B4'.
      WHEN 2. rv_color = '#FF7F0E'.
      WHEN 3. rv_color = '#2CA02C'.
      WHEN 4. rv_color = '#D62728'.
      WHEN 5. rv_color = '#9467BD'.
      WHEN 6. rv_color = '#8C564B'.
      WHEN 7. rv_color = '#E377C2'.
      WHEN 8. rv_color = '#17BECF'.
    ENDCASE.
  ENDMETHOD.

  METHOD fmt_amt.
    DATA lv_txt TYPE c LENGTH 24.
    WRITE iv_amt TO lv_txt.
    CONDENSE lv_txt.
    rv_text = lv_txt.
  ENDMETHOD.

  METHOD build_html.
    DATA: lv_period TYPE string,
          lv_from   TYPE c LENGTH 10,
          lv_to     TYPE c LENGTH 10.

    WRITE mv_from TO lv_from DD/MM/YYYY.
    WRITE mv_to   TO lv_to   DD/MM/YYYY.
    lv_period = |{ lv_from } - { lv_to }|.

    rv_html =
      `<html><head><meta http-equiv="X-UA-Compatible" content="IE=edge"/>` &&
      `<style>` &&
      `body{font-family:Arial,sans-serif;margin:10px;background:#eef2f6;color:#222;}` &&
      `h2{margin:0;display:inline-block;}` &&
      `.top{width:100%;margin-bottom:8px;}` &&
      `.btn{background:#c0392b;color:#fff;padding:6px 14px;text-decoration:none;font-weight:bold;}` &&
      `.kpi{border-collapse:separate;border-spacing:6px;width:100%;}` &&
      `.kpi td{color:#fff;padding:10px 12px;width:12%;}` &&
      `.lbl{font-size:11px;opacity:.9;}` &&
      `.val{font-size:18px;font-weight:bold;}` &&
      `.box{background:#fff;border:1px solid #d5dde5;padding:8px;}` &&
      `h3{margin:0 0 8px 0;font-size:13px;color:#1f4e79;}` &&
      `table.grid{border-collapse:collapse;width:100%;}` &&
      `table.grid th,table.grid td{border:1px solid #d9dee5;padding:5px 6px;font-size:11px;}` &&
      `table.grid th{background:#1f4e79;color:#fff;}` &&
      `.barbg{background:#e9eef3;height:14px;width:100%;}` &&
      `.bar{height:14px;}` &&
      `</style></head><body>` &&
      `<table class="top"><tr>` &&
      |<td><h2>Sales dashboard - plant { p_werks }</h2><div class="lbl">Period { lv_period } | { mv_waerk }</div></td>| &&
      `<td align="right"><a class="btn" href="sapevent:CLOSE">Close</a></td>` &&
      `</tr></table>` &&
      `<table class="kpi"><tr>` &&
      build_kpi( iv_label = 'Sales orders' iv_value = |{ mv_orders }| iv_color = '#1F77B4' ) &&
      build_kpi( iv_label = 'Order items' iv_value = |{ mv_items }| iv_color = '#FF7F0E' ) &&
      build_kpi( iv_label = 'Customers' iv_value = |{ mv_cust }| iv_color = '#2CA02C' ) &&
      build_kpi( iv_label = 'Materials' iv_value = |{ mv_mats }| iv_color = '#9467BD' ) &&
      build_kpi( iv_label = 'Quantity' iv_value = fmt_amt( mv_qty ) iv_color = '#17BECF' ) &&
      build_kpi( iv_label = |Net value ({ mv_waerk })| iv_value = fmt_amt( mv_netwr ) iv_color = '#D62728' ) &&
      build_kpi( iv_label = 'Avg / order' iv_value = fmt_amt( mv_avg ) iv_color = '#8C564B' ) &&
      `</tr></table>` &&
      `<table width="100%" cellspacing="6"><tr valign="top">` &&
      `<td width="33%" class="box"><h3>By order type</h3>` &&
      build_pie_svg( it_slice = mt_auart iv_total = mv_netwr ) &&
      build_table( mt_auart ) &&
      `</td>` &&
      `<td width="33%" class="box"><h3>By customer</h3>` &&
      build_pie_svg( it_slice = mt_kunnr iv_total = mv_netwr ) &&
      build_table( mt_kunnr ) &&
      `</td>` &&
      `<td width="34%" class="box"><h3>By material (net value)</h3>` &&
      build_bars( mt_matnr ) &&
      build_table( mt_matnr ) &&
      `</td>` &&
      `</tr></table>` &&
      `</body></html>`.
  ENDMETHOD.

  METHOD build_kpi.
    rv_html =
      |<td style="background:{ iv_color };">| &&
      |<div class="lbl">{ iv_label }</div>| &&
      |<div class="val">{ iv_value }</div></td>|.
  ENDMETHOD.

  METHOD build_table.
    DATA: lv_qty TYPE string,
          lv_amt TYPE string,
          lv_rows TYPE string.

    LOOP AT it_slice ASSIGNING FIELD-SYMBOL(<ls>).
      lv_qty = fmt_amt( <ls>-qty ).
      lv_amt = fmt_amt( <ls>-netwr ).
      lv_rows = lv_rows &&
        |<tr>| &&
        |<td><span style="display:inline-block;width:10px;height:10px;background:{ <ls>-color };"></span> { <ls>-key }</td>| &&
        |<td align="right">{ <ls>-items }</td>| &&
        |<td align="right">{ lv_qty }</td>| &&
        |<td align="right">{ lv_amt }</td>| &&
        |<td align="right">{ <ls>-pct }%</td>| &&
        |</tr>|.
    ENDLOOP.

    rv_html =
      `<table class="grid">` &&
      `<tr><th>Value</th><th>Items</th><th>Qty</th><th>Net</th><th>%</th></tr>` &&
      lv_rows &&
      `</table>`.
  ENDMETHOD.

  METHOD build_bars.
    DATA: lv_w   TYPE i,
          lv_amt TYPE string.

    rv_html = `<table width="100%" cellpadding="2">`.

    LOOP AT it_slice ASSIGNING FIELD-SYMBOL(<ls>).
      lv_w = <ls>-pct.
      IF lv_w < 1 AND <ls>-pct > 0.
        lv_w = 1.
      ENDIF.
      lv_amt = fmt_amt( <ls>-netwr ).
      rv_html = rv_html &&
        |<tr><td nowrap>{ <ls>-key }</td></tr>| &&
        |<tr><td><div class="barbg"><div class="bar" style="width:{ lv_w }%;background:{ <ls>-color };"></div></div>| &&
        |<div class="lbl">{ lv_amt } ({ <ls>-pct }%)</div></td></tr>|.
    ENDLOOP.

    rv_html = rv_html && `</table><br/>`.
  ENDMETHOD.

  METHOD build_pie_svg.
    CONSTANTS:
      lc_cx TYPE f VALUE '110',
      lc_cy TYPE f VALUE '110',
      lc_r  TYPE f VALUE '90',
      lc_pi TYPE f VALUE '3.1415926535897931'.

    DATA:
      lv_angle TYPE f,
      lv_from  TYPE f,
      lv_to    TYPE f,
      lv_x1    TYPE f,
      lv_y1    TYPE f,
      lv_x2    TYPE f,
      lv_y2    TYPE f,
      lv_large TYPE c LENGTH 1,
      lv_paths TYPE string.

    IF iv_total <= 0 OR it_slice IS INITIAL.
      rv_svg = `<p>No values for chart.</p>`.
      RETURN.
    ENDIF.

    IF lines( it_slice ) = 1.
      READ TABLE it_slice ASSIGNING FIELD-SYMBOL(<ls_one>) INDEX 1.
      rv_svg =
        `<svg width="220" height="220" viewBox="0 0 220 220">` &&
        |<circle cx="110" cy="110" r="90" fill="{ <ls_one>-color }"/>| &&
        `<circle cx="110" cy="110" r="48" fill="#ffffff"/>` &&
        `</svg>`.
      RETURN.
    ENDIF.

    lv_angle = -1 * ( lc_pi / 2 ).

    LOOP AT it_slice ASSIGNING FIELD-SYMBOL(<ls>).
      lv_from = lv_angle.
      lv_to   = lv_angle + ( ( <ls>-netwr / iv_total ) * 2 * lc_pi ).

      lv_x1 = lc_cx + ( lc_r * cos( lv_from ) ).
      lv_y1 = lc_cy + ( lc_r * sin( lv_from ) ).
      lv_x2 = lc_cx + ( lc_r * cos( lv_to ) ).
      lv_y2 = lc_cy + ( lc_r * sin( lv_to ) ).

      IF ( lv_to - lv_from ) > lc_pi.
        lv_large = '1'.
      ELSE.
        lv_large = '0'.
      ENDIF.

      lv_paths = lv_paths &&
        |<path d="M { lc_cx DECIMALS = 1 } { lc_cy DECIMALS = 1 } | &&
        |L { lv_x1 DECIMALS = 1 } { lv_y1 DECIMALS = 1 } | &&
        |A { lc_r DECIMALS = 1 } { lc_r DECIMALS = 1 } 0 { lv_large } 1 | &&
        |{ lv_x2 DECIMALS = 1 } { lv_y2 DECIMALS = 1 } Z" | &&
        |fill="{ <ls>-color }" stroke="#fff" stroke-width="1"/>|.

      lv_angle = lv_to.
    ENDLOOP.

    rv_svg =
      `<svg width="220" height="220" viewBox="0 0 220 220">` &&
      lv_paths &&
      `<circle cx="110" cy="110" r="48" fill="#ffffff"/>` &&
      `</svg>`.
  ENDMETHOD.

  METHOD html_to_table.
    DATA: lv_off  TYPE i,
          lv_len  TYPE i,
          lv_take TYPE i,
          ls_line TYPE ty_html.

    lv_len = strlen( iv_html ).
    WHILE lv_off < lv_len.
      lv_take = lv_len - lv_off.
      IF lv_take > 255.
        lv_take = 255.
      ENDIF.
      CLEAR ls_line.
      ls_line = iv_html+lv_off(lv_take).
      APPEND ls_line TO rt_html.
      lv_off = lv_off + lv_take.
    ENDWHILE.
  ENDMETHOD.

  METHOD free_dashboard.
    IF mo_html IS BOUND.
      SET HANDLER on_sapevent FOR mo_html ACTIVATION space.
      mo_html->free( EXCEPTIONS OTHERS = 1 ).
      CLEAR mo_html.
    ENDIF.

    IF mo_dialog IS BOUND.
      SET HANDLER on_close FOR mo_dialog ACTIVATION space.
      mo_dialog->free( EXCEPTIONS OTHERS = 1 ).
      CLEAR mo_dialog.
    ENDIF.

    cl_gui_cfw=>flush( EXCEPTIONS OTHERS = 1 ).
  ENDMETHOD.

  METHOD on_close.
    free_dashboard( ).
  ENDMETHOD.

  METHOD on_sapevent.
    IF action = 'CLOSE'.
      free_dashboard( ).
    ENDIF.
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
* Global instance (must live after selection-screen PAI for GUI controls)
*----------------------------------------------------------------------*
DATA go_app TYPE REF TO lcl_report.

*----------------------------------------------------------------------*
* Events
*----------------------------------------------------------------------*
INITIALIZATION.
  go_app = NEW lcl_report( ).
  p_dash = 'Show Dashboard'.

AT SELECTION-SCREEN.
  DATA lv_rc TYPE i.

  cl_gui_cfw=>dispatch(
    IMPORTING
      return_code = lv_rc ).

  IF lv_rc <> cl_gui_cfw=>rc_noevent.
    RETURN.
  ENDIF.

  CASE sy-ucomm.
    WHEN 'CLOSE'.
      go_app->close_dashboard( ).
    WHEN 'DASH'.
      go_app->validate_plant( ).
      IF go_app->get_data( ) = abap_true.
        go_app->display_dashboard( ).
      ENDIF.
    WHEN OTHERS.
      go_app->validate_plant( ).
  ENDCASE.

START-OF-SELECTION.
  IF go_app->get_data( ) = abap_true.
    go_app->display_alv( ).
  ENDIF.
