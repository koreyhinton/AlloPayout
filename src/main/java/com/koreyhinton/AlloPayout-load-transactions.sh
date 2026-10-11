#!/bin/bash

v=${1}
# maps
. ${NSMAP}/bind ${v} SpreadsheetId SheetService DecimalFormat

cat << EOF

/* from: Pending Transactions
|-------------------+------+--------+--------+----------------+----------|
| A                 | B    | C      | D      | E              | F        |
|-------------------+------+--------+--------+----------------+----------|
| Timestamp         | Type | Person | Amount | Description    | Approved |
|-------------------+------+--------+--------+----------------+----------|
| 10/8/2026 0:00:00 | +    | Alice  |      2 | Take out trash | Y        |
|-------------------+------+--------+--------+----------------+----------|
*/

/* to: Transactions
|-------------------+------+--------+--------+----------------|
| A                 | B    | C      | D      | E              |
|-------------------+------+--------+--------+----------------|
| Timestamp         | Type | Person | Amount | Description    |
|-------------------+------+--------+--------+----------------|
| 10/8/2026 0:00:00 | +    | Alice  |      2 | Take out trash |
|-------------------+------+--------+--------+----------------|
*/

    String ${v}Range = "Pending Transactions!A:F";
    ValueRange ${v}Response = ${!sheet_service}.spreadsheets().values()
        .get(${!spreadsheet_id}, ${v}Range)
        .execute();
    List<List<Object>> ${v}Values = ${v}Response.getValues();
    if (${v}Values == null || ${v}Values.isEmpty())
        throw new Exception("No data found in sheet: Pending Transactions");

    List<List<Object>> ${v}WriteValues = new ArrayList<List<Object>>();

    boolean ${v}Once = false;
    // grab all columns except the "Approved" column,
    // skip first row,
    // only grab 'Y' approved ones,
    // and skip 0 amount rows (sticky/required tasks)
    for (List row : ${v}Values) {
        if (!${v}Once) {
            ${v}Once = true;
            continue;
        }
        BigDecimal amount = (BigDecimal)${!decimal_format}
            .parse((String)row.get(3)); 
        boolean zeroTask = amount.compareTo(BigDecimal.ZERO) == 0;
        if (zeroTask)
            continue;
        if (!"Y".equals((String)row.get(5)))
            continue;

        List<Object> cols = new ArrayList<Object>();
        cols.add(row.get(0));
        cols.add("'" + row.get(1)); // + needs to be qualified with apostraphe
        cols.add(row.get(2));
        cols.add(row.get(3));
        cols.add(row.get(4));
        ${v}WriteValues.add(cols);
    }

    ValueRange ${v}AppendValueRange = new ValueRange();
    ${v}AppendValueRange.setValues(${v}WriteValues);
    ${!sheet_service}.spreadsheets().values()
        .append(
            ${!spreadsheet_id},
            "Transactions!A:A",
            ${v}AppendValueRange
        )
        .setValueInputOption("USER_ENTERED")
        .execute();

    BatchClearValuesRequest ${v}ClearRequest = new BatchClearValuesRequest();
    List<String> ${v}ClearRanges = new ArrayList<>();
    Integer ${v}ClearRow = 2;
    for (Integer i=0; i<${v}Values.size(); i++) {
        // ignore i var
        ${v}ClearRanges.add("Pending Transactions!A" + 
            Integer.toString(${v}ClearRow) + 
            ":F" + 
            Integer.toString(${v}ClearRow)
        );
        ${v}ClearRow += 1;
    }

    ${v}ClearRequest.setRanges(${v}ClearRanges);
    ${!sheet_service}.spreadsheets().values()
        .batchClear(
            ${!spreadsheet_id},
            ${v}ClearRequest
        )
        .execute();    

EOF
