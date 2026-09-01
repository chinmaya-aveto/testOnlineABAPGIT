*&---------------------------------------------------------------------*
*& Report ZTESTONLINEABAPGIT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT ZTESTONLINEABAPGIT.

write : 'push data from SAP ECC saraswati'.
write : 'new push from github'.
write : 'new push fom SAP ECC sarswati 2 new change'.
write : 'new push fom github 2 new change'.
write : 'new push testing newwww change'.

write : '1st sep change push from guthub'.

WRITE: / 'Modernized ABAP output example 1',
         / 'Executed on', sy-datum, sy-uzeit,
         / 'User:', sy-uname,
         / 'SAP system:', sy-sysid,
         / 'End of modernized block'.

CONSTANTS: gc_hello TYPE string VALUE 'Hello'.
DATA(lv_msg) = |{ gc_hello } from string templates on { sy-datum }|.

WRITE: / lv_msg,
       / `Another literal with backticks`,
       / 'Client:', sy-mandt.

IF sy-uname IS NOT INITIAL.
  WRITE: / 'Current user is active:', sy-uname.
ELSE.
  WRITE: / 'No active user detected'.
ENDIF.
