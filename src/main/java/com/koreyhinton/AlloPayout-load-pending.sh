#!/bin/bash

v=$1
# maps
. ${NSMAP}/bind ${v} SpreadsheetId SheetService

cat << EOF

    String range = "Opx State";
    ValueRange ${v}Response = ${!sheet_service}.spreadsheets().values()
        .get(${!spreadsheet_id}, range)
        .execute();
    // todo

EOF
