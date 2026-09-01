*&---------------------------------------------------------------------*
*& Report ZMM_PO_ALV_REPORT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT ZMM_TEST_ONLINE.


TYPES: BEGIN OF ty_po,
         ebeln TYPE ekko-ebeln,   " PO Number
         ebelp TYPE ekpo-ebelp,   " PO Item
         bukrs TYPE ekko-bukrs,   " Company Code
         bsart TYPE ekko-bsart,   " PO Type
         lifnr TYPE ekko-lifnr,   " Vendor
         ekorg TYPE ekko-ekorg,   " Purchasing Org
         ekgrp TYPE ekko-ekgrp,   " Purchasing Group
         matnr TYPE ekpo-matnr,   " Material
         menge TYPE ekpo-menge,   " Quantity
         netpr TYPE ekpo-netpr,   " Net Price
       END OF ty_po.

DATA: gt_po   TYPE STANDARD TABLE OF ty_po,
      gs_po   TYPE ty_po,
      gt_fcat TYPE slis_t_fieldcat_alv,
      gs_fcat TYPE slis_fieldcat_alv,
      gs_layout TYPE slis_layout_alv.

SELECT-OPTIONS:
  s_ebeln FOR gs_po-ebeln,
  s_bukrs FOR gs_po-bukrs,
  s_lifnr FOR gs_po-lifnr.

START-OF-SELECTION.

  SELECT ekko~ebeln
         ekpo~ebelp
         ekko~bukrs
         ekko~bsart
         ekko~lifnr
         ekko~ekorg
         ekko~ekgrp
         ekpo~matnr
         ekpo~menge
         ekpo~netpr
    INTO TABLE gt_po
    FROM ekko
    INNER JOIN ekpo
      ON ekpo~ebeln = ekko~ebeln
    WHERE ekko~ebeln IN s_ebeln
      AND ekko~bukrs IN s_bukrs
      AND ekko~lifnr IN s_lifnr.

  IF gt_po[] IS INITIAL.
    MESSAGE 'No PO data found for selection' TYPE 'I'.
    RETURN.
  ENDIF.

  PERFORM build_fieldcat.
  PERFORM display_alv.

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

  add_field: 'EBELN' 'PO Number'      10,
             'EBELP' 'PO Item'        6,
             'BUKRS' 'Co. Code'       6,
             'BSART' 'PO Type'        6,
             'LIFNR' 'Vendor'         10,
             'EKORG' 'Purch Org'      6,
             'EKGRP' 'Purch Group'    6,
             'MATNR' 'Material'       18,
             'MENGE' 'Quantity'       10,
             'NETPR' 'Net Price'      12.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  DISPLAY_ALV
*&---------------------------------------------------------------------*
FORM display_alv.

  gs_layout-zebra = 'X'.
  gs_layout-colwidth_optimize = 'X'.

  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
    EXPORTING
      i_callback_program = sy-repid
      is_layout          = gs_layout
      it_fieldcat        = gt_fcat
    TABLES
      t_outtab            = gt_po
    EXCEPTIONS
      program_error       = 1
      OTHERS               = 2.

  IF sy-subrc <> 0.
    MESSAGE 'Error displaying ALV from GIT' TYPE 'I'.
  ENDIF.

ENDFORM.
