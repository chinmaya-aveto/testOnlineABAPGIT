*&---------------------------------------------------------------------*
*& Report ZTEST_PRG_ABAPGITONLINE
*& Description: SALV report + HTML/SVG dashboard for sales items by plant
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
             auart  TYPE vbak-auart,
             kunnr  TYPE vbak-kunnr,
             matnr  TYPE vbap-matnr,
             werks  TYPE vbap-werks,
             kwmeng TYPE vbap-kwmeng,
             vrkme  TYPE vbap-vrkme,
             netwr  TYPE vbap-netwr,
             waerk  TYPE vbak-waerk,
           END OF ty_output.

    TYPES: BEGIN OF ty_pie,
             auart TYPE vbak-auart,
             items TYPE i,
             netwr TYPE vbap-netwr,
             pct   TYPE p LENGTH 5 DECIMALS 1,
             color TYPE c LENGTH 7,
           END OF ty_pie.

    TYPES tt_output TYPE STANDARD TABLE OF ty_output WITH DEFAULT KEY.
    TYPES tt_pie    TYPE STANDARD TABLE OF ty_pie WITH DEFAULT KEY.
    TYPES ty_html   TYPE c LENGTH 255.
    TYPES tt_html   TYPE STANDARD TABLE OF ty_html WITH DEFAULT KEY.

    METHODS:
      validate_plant,
      get_data
        RETURNING VALUE(rv_ok) TYPE abap_bool,
      display_alv,
      display_dashboard.

  PRIVATE SECTION.
    DATA:
      mt_output TYPE tt_output,
      mt_pie    TYPE tt_pie,
      mo_salv   TYPE REF TO cl_salv_table,
      mo_dialog TYPE REF TO cl_gui_dialogbox_container,
      mo_html   TYPE REF TO cl_gui_html_viewer,
      mv_orders TYPE i,
      mv_items  TYPE i,
      mv_netwr  TYPE vbap-netwr,
      mv_waerk  TYPE vbak-waerk.

    METHODS:
      set_functions,
      set_columns,
      set_layout,
      build_summary,
      build_html
        RETURNING VALUE(rv_html) TYPE string,
      build_pie_svg
        RETURNING VALUE(rv_svg) TYPE string,
      html_to_table
        IMPORTING iv_html        TYPE string
        RETURNING VALUE(rt_html) TYPE tt_html,
      free_dashboard,
      on_close FOR EVENT close OF cl_gui_dialogbox_container
        IMPORTING sender.
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
          width   = 980
          height  = 640
          top     = 60
          left    = 80
          caption = |Dashboard - Plant { p_werks }| ).

        SET HANDLER on_close FOR mo_dialog.

        mo_html = NEW cl_gui_html_viewer( parent = mo_dialog ).

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

    cl_gui_cfw=>flush( ).
  ENDMETHOD.

  METHOD build_summary.
    DATA: ls_pie TYPE ty_pie,
          lt_ord TYPE HASHED TABLE OF vbak-vbeln WITH UNIQUE KEY table_line,
          lt_cur TYPE HASHED TABLE OF vbak-waerk WITH UNIQUE KEY table_line.

    CLEAR: mt_pie, mv_orders, mv_items, mv_netwr, mv_waerk.

    mv_items = lines( mt_output ).

    LOOP AT mt_output ASSIGNING FIELD-SYMBOL(<ls_out>).
      INSERT <ls_out>-vbeln INTO TABLE lt_ord.
      INSERT <ls_out>-waerk INTO TABLE lt_cur.
      mv_netwr = mv_netwr + <ls_out>-netwr.

      READ TABLE mt_pie ASSIGNING FIELD-SYMBOL(<ls_pie>)
        WITH KEY auart = <ls_out>-auart.
      IF sy-subrc <> 0.
        CLEAR ls_pie.
        ls_pie-auart = <ls_out>-auart.
        APPEND ls_pie TO mt_pie ASSIGNING <ls_pie>.
      ENDIF.
      <ls_pie>-items = <ls_pie>-items + 1.
      <ls_pie>-netwr = <ls_pie>-netwr + <ls_out>-netwr.
    ENDLOOP.

    mv_orders = lines( lt_ord ).

    IF lines( lt_cur ) = 1.
      LOOP AT lt_cur INTO mv_waerk.
        EXIT.
      ENDLOOP.
    ELSE.
      mv_waerk = 'MULTI'.
    ENDIF.

    SORT mt_pie BY netwr DESCENDING.

    DATA(lv_idx) = 0.
    LOOP AT mt_pie ASSIGNING <ls_pie>.
      lv_idx = lv_idx + 1.
      CASE lv_idx.
        WHEN 1. <ls_pie>-color = '#4E79A7'.
        WHEN 2. <ls_pie>-color = '#F28E2B'.
        WHEN 3. <ls_pie>-color = '#E15759'.
        WHEN 4. <ls_pie>-color = '#76B7B2'.
        WHEN 5. <ls_pie>-color = '#59A14F'.
        WHEN 6. <ls_pie>-color = '#EDC948'.
        WHEN OTHERS. <ls_pie>-color = '#B07AA1'.
      ENDCASE.

      IF mv_netwr > 0.
        <ls_pie>-pct = ( <ls_pie>-netwr * 100 ) / mv_netwr.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD build_html.
    DATA: lv_orders TYPE string,
          lv_items  TYPE string,
          lv_net    TYPE c LENGTH 24,
          lv_rowamt TYPE c LENGTH 24,
          lv_rows   TYPE string.

    lv_orders = |{ mv_orders }|.
    lv_items  = |{ mv_items }|.
    WRITE mv_netwr TO lv_net.
    CONDENSE lv_net.

    LOOP AT mt_pie ASSIGNING FIELD-SYMBOL(<ls_pie>).
      WRITE <ls_pie>-netwr TO lv_rowamt.
      CONDENSE lv_rowamt.
      lv_rows = lv_rows &&
        |<tr>| &&
        |<td><span style="display:inline-block;width:10px;height:10px;background:{ <ls_pie>-color };"></span> { <ls_pie>-auart }</td>| &&
        |<td align="right">{ <ls_pie>-items }</td>| &&
        |<td align="right">{ lv_rowamt }</td>| &&
        |<td align="right">{ <ls_pie>-pct }%</td>| &&
        |</tr>|.
    ENDLOOP.

    rv_html =
      `<html><head><meta http-equiv="X-UA-Compatible" content="IE=edge"/>` &&
      `<style>` &&
      `body{font-family:Arial,sans-serif;margin:12px;background:#f4f6f8;color:#333;}` &&
      `h2{margin:0 0 12px 0;}` &&
      `.kpi{border-collapse:separate;border-spacing:8px;width:100%;}` &&
      `.kpi td{background:#fff;border:1px solid #d9dee5;padding:10px 14px;width:25%;}` &&
      `.lbl{font-size:11px;color:#667;}` &&
      `.val{font-size:20px;font-weight:bold;color:#1f4e79;}` &&
      `table.grid{border-collapse:collapse;width:100%;background:#fff;}` &&
      `table.grid th,table.grid td{border:1px solid #d9dee5;padding:6px 8px;font-size:12px;}` &&
      `table.grid th{background:#1f4e79;color:#fff;}` &&
      `</style></head><body>` &&
      |<h2>Sales dashboard - plant { p_werks }</h2>| &&
      `<table class="kpi"><tr>` &&
      |<td><div class="lbl">Sales orders</div><div class="val">{ lv_orders }</div></td>| &&
      |<td><div class="lbl">Order items</div><div class="val">{ lv_items }</div></td>| &&
      |<td><div class="lbl">Net value</div><div class="val">{ lv_net }</div></td>| &&
      |<td><div class="lbl">Currency</div><div class="val">{ mv_waerk }</div></td>| &&
      `</tr></table>` &&
      `<table width="100%"><tr valign="top">` &&
      |<td width="360">{ build_pie_svg( ) }</td>| &&
      `<td>` &&
      `<b>Net value by order type</b><br/><br/>` &&
      `<table class="grid">` &&
      `<tr><th>Order type</th><th>Items</th><th>Net value</th><th>Share</th></tr>` &&
      lv_rows &&
      `</table></td></tr></table>` &&
      `</body></html>`.
  ENDMETHOD.

  METHOD build_pie_svg.
    CONSTANTS:
      lc_cx TYPE f VALUE '160',
      lc_cy TYPE f VALUE '160',
      lc_r  TYPE f VALUE '120',
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

    IF mv_netwr <= 0.
      rv_svg = `<p>Net value is zero. Pie chart is not drawn.</p>`.
      RETURN.
    ENDIF.

    IF lines( mt_pie ) = 1.
      READ TABLE mt_pie ASSIGNING FIELD-SYMBOL(<ls_one>) INDEX 1.
      rv_svg =
        `<svg width="320" height="320" viewBox="0 0 320 320">` &&
        |<circle cx="160" cy="160" r="120" fill="{ <ls_one>-color }"/>| &&
        `</svg>`.
      RETURN.
    ENDIF.

    lv_angle = -1 * ( lc_pi / 2 ).

    LOOP AT mt_pie ASSIGNING FIELD-SYMBOL(<ls_pie>).
      lv_from = lv_angle.
      lv_to   = lv_angle + ( ( <ls_pie>-netwr / mv_netwr ) * 2 * lc_pi ).

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
        |fill="{ <ls_pie>-color }" stroke="#fff" stroke-width="1"/>|.

      lv_angle = lv_to.
    ENDLOOP.

    rv_svg = `<svg width="320" height="320" viewBox="0 0 320 320">` && lv_paths && `</svg>`.
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
      mo_html->free( ).
      CLEAR mo_html.
    ENDIF.

    IF mo_dialog IS BOUND.
      SET HANDLER on_close FOR mo_dialog ACTIVATION space.
      mo_dialog->free( ).
      CLEAR mo_dialog.
    ENDIF.
  ENDMETHOD.

  METHOD on_close.
    IF mo_html IS BOUND.
      mo_html->free( ).
      CLEAR mo_html.
    ENDIF.
    CLEAR mo_dialog.
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
  go_app->validate_plant( ).

  IF sy-ucomm = 'DASH'.
    IF go_app->get_data( ) = abap_true.
      go_app->display_dashboard( ).
    ENDIF.
  ENDIF.

START-OF-SELECTION.
  IF go_app->get_data( ) = abap_true.
    go_app->display_alv( ).
  ENDIF.
