*&---------------------------------------------------------------------*
*& Report ZTEST_PROGRAM
*& Description: ALV report for sales order header (VBAK) and item (VBAP)
*&---------------------------------------------------------------------*
REPORT ztest_program.

TABLES: vbak, vbap.

TYPES: BEGIN OF ty_sales,
         vbeln  TYPE vbak-vbeln,   " Sales document
         erdat  TYPE vbak-erdat,   " Created on
         erzet  TYPE vbak-erzet,   " Created at
         auart  TYPE vbak-auart,   " Document type
         vkorg  TYPE vbak-vkorg,   " Sales organization
         vtweg  TYPE vbak-vtweg,   " Distribution channel
         spart  TYPE vbak-spart,   " Division
         vkbur  TYPE vbak-vkbur,   " Sales office
         vkgrp  TYPE vbak-vkgrp,   " Sales group
         kunnr  TYPE vbak-kunnr,   " Sold-to party
         waerk  TYPE vbak-waerk,   " Document currency
         netwr_h TYPE vbak-netwr,  " Header net value
         posnr  TYPE vbap-posnr,   " Item
         matnr  TYPE vbap-matnr,   " Material
         arktx  TYPE vbap-arktx,   " Item description
         kwmeng TYPE vbap-kwmeng,  " Order quantity
         vrkme  TYPE vbap-vrkme,   " Sales unit
         netpr  TYPE vbap-netpr,   " Net price
         netwr  TYPE vbap-netwr,   " Item net value
         werks  TYPE vbap-werks,   " Plant
         lgort  TYPE vbap-lgort,   " Storage location
       END OF ty_sales.

DATA: gt_sales  TYPE STANDARD TABLE OF ty_sales,
      gs_sales  TYPE ty_sales,
      gt_fcat   TYPE slis_t_fieldcat_alv,
      gs_fcat   TYPE slis_fieldcat_alv,
      gs_layout TYPE slis_layout_alv.

*----------------------------------------------------------------------*
* Selection screen
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE text-001.
SELECT-OPTIONS:
  s_vbeln FOR vbak-vbeln,   " Sales document
  s_erdat FOR vbak-erdat,   " Created on
  s_auart FOR vbak-auart,   " Document type
  s_vkorg FOR vbak-vkorg,   " Sales organization
  s_vtweg FOR vbak-vtweg,   " Distribution channel
  s_spart FOR vbak-spart,   " Division
  s_kunnr FOR vbak-kunnr,   " Sold-to party
  s_matnr FOR vbap-matnr.   " Material
SELECTION-SCREEN END OF BLOCK b1.

*----------------------------------------------------------------------*
* Start of selection
*----------------------------------------------------------------------*
START-OF-SELECTION.
  PERFORM get_data.
  IF gt_sales[] IS INITIAL.
    MESSAGE 'No sales documents found for the given selection' TYPE 'I'.
    RETURN.
  ENDIF.
  PERFORM build_fieldcat.
  PERFORM display_alv.

*&---------------------------------------------------------------------*
*&      Form  GET_DATA
*&---------------------------------------------------------------------*
FORM get_data.

  SELECT vbak~vbeln
         vbak~erdat
         vbak~erzet
         vbak~auart
         vbak~vkorg
         vbak~vtweg
         vbak~spart
         vbak~vkbur
         vbak~vkgrp
         vbak~kunnr
         vbak~waerk
         vbak~netwr
         vbap~posnr
         vbap~matnr
         vbap~arktx
         vbap~kwmeng
         vbap~vrkme
         vbap~netpr
         vbap~netwr
         vbap~werks
         vbap~lgort
    INTO TABLE gt_sales
    FROM vbak
    INNER JOIN vbap
      ON vbap~vbeln = vbak~vbeln
    WHERE vbak~vbeln IN s_vbeln
      AND vbak~erdat IN s_erdat
      AND vbak~auart IN s_auart
      AND vbak~vkorg IN s_vkorg
      AND vbak~vtweg IN s_vtweg
      AND vbak~spart IN s_spart
      AND vbak~kunnr IN s_kunnr
      AND vbap~matnr IN s_matnr.

  SORT gt_sales BY vbeln posnr.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  BUILD_FIELDCAT
*&---------------------------------------------------------------------*
FORM build_fieldcat.

  DEFINE add_field.
    CLEAR gs_fcat.
    gs_fcat-fieldname = &1.
    gs_fcat-seltext_m = &2.
    gs_fcat-outputlen = &3.
    APPEND gs_fcat TO gt_fcat.
  END-OF-DEFINITION.

  add_field: 'VBELN'   'Sales Doc'      10,
             'ERDAT'   'Created On'     10,
             'ERZET'   'Created At'      8,
             'AUART'   'Doc Type'        4,
             'VKORG'   'Sales Org'       4,
             'VTWEG'   'Dist. Chan'      2,
             'SPART'   'Division'        2,
             'VKBUR'   'Sales Office'    4,
             'VKGRP'   'Sales Group'     3,
             'KUNNR'   'Sold-To'        10,
             'WAERK'   'Currency'        5,
             'NETWR_H' 'Hdr Net Value'  15,
             'POSNR'   'Item'            6,
             'MATNR'   'Material'       18,
             'ARKTX'   'Description'    40,
             'KWMENG'  'Order Qty'      15,
             'VRKME'   'Unit'            3,
             'NETPR'   'Net Price'      15,
             'NETWR'   'Item Net Value' 15,
             'WERKS'   'Plant'           4,
             'LGORT'   'Stor. Loc'       4.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  DISPLAY_ALV
*&---------------------------------------------------------------------*
FORM display_alv.

  gs_layout-zebra             = 'X'.
  gs_layout-colwidth_optimize = 'X'.

  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
    EXPORTING
      i_callback_program = sy-repid
      i_grid_title       = 'Sales Order Header and Item Details'
      is_layout          = gs_layout
      it_fieldcat        = gt_fcat
    TABLES
      t_outtab           = gt_sales
    EXCEPTIONS
      program_error      = 1
      OTHERS             = 2.

  IF sy-subrc <> 0.
    MESSAGE 'Error displaying ALV' TYPE 'I'.
  ENDIF.

ENDFORM.
