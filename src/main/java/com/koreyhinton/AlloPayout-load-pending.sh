#!/bin/bash

v=$1
# maps
. ${NSMAP}/bind ${v} SpreadsheetId SheetService DecimalFormat DateTimeFormatter

cat << EOF

    String ${v}Timestamp = LocalDateTime.now().format(
        ${!date_time_formatter}
    );

    /* Opx State
        |--------+-----------------|
        | A      |               B |
        |--------+-----------------|
        | Person | Last task index |
        |--------+-----------------|
        | Bob    |               0 |
        |--------+-----------------|
        | Alice  |               0 |
        |--------+-----------------|
    */
    String ${v}Range = "Opx State!A:B";
    ValueRange ${v}Response = ${!sheet_service}.spreadsheets().values()
        .get(${!spreadsheet_id}, ${v}Range)
        .execute();
    List<List<Object>> ${v}Values = ${v}Response.getValues();
    if (${v}Values == null || ${v}Values.isEmpty())
        throw new Exception("No data found in sheet: Opx State");

    /* Tasks
        |--------------------+--------+-------------------+-------------------|
        | A                  | B      | C                 | D                 |
        |--------------------+--------+-------------------+-------------------|
        | Task               | Sticky | Priority Person 1 | Priority Person 2 |
        |--------------------+--------+-------------------+-------------------|
        | Play with the cats | N      | Alice             | Bob               |
        |--------------------+--------+-------------------+-------------------|
    */
    String ${v}TasksRange = "Tasks!A:D";
    ValueRange ${v}TasksResponse = ${!sheet_service}.spreadsheets().values()
        .get(${!spreadsheet_id}, ${v}TasksRange)
        .execute();
    List<List<Object>> ${v}TasksValues = ${v}TasksResponse.getValues();
    if (${v}TasksValues == null || ${v}TasksValues.isEmpty())
        throw new Exception("No data found in sheet: Tasks");

    /* Weekly Allowance
        |--------+--------+----------------|
        | A      |      B |              C |
        |--------+--------+----------------|
        | Person | Amount | Tasks per week |
        |--------+--------+----------------|
        | Bob    |     10 |              5 |
        |--------+--------+----------------|
        | Alice  |     10 |              5 |
        |--------+--------+----------------|
    */
    String ${v}WeeklyRange = "Weekly Allowance!A:C";
    ValueRange ${v}WeeklyResponse = ${!sheet_service}.spreadsheets().values()
        .get(${!spreadsheet_id}, ${v}WeeklyRange)
        .execute();
    List<List<Object>> ${v}WeeklyValues = ${v}WeeklyResponse.getValues();
    if (${v}WeeklyValues == null || ${v}WeeklyValues.isEmpty())
        throw new Exception("No data found in sheet: Weekly Allowance");

    List<List<Object>> ${v}AppendValues = new ArrayList<List<Object>>();
    List<List<Object>> ${v}UpdateValues = new ArrayList<List<Object>>();

    Set<Integer> ${v}TakenTaskIndices = new HashSet<>();
    Map<Integer, PersonAllowanceState> ${v}PersonStateMap = new HashMap<>();

    boolean ${v}Once = false;
    Integer ${v}I = 0; // person index map (skips header, 0 is first data row)
    for (List row : ${v}Values) { // person rows
        if (!${v}Once) {
            ${v}Once = true;
            continue; // skip header row
        }
        String personName = (String)row.get(0);
        Integer lastTaskIndex = Integer.parseInt((String)row.get(1));
        System.out.printf("%s %d\n", personName, lastTaskIndex);

        BigDecimal allowanceAmountInUsd = BigDecimal.ZERO;
        Integer tasksPerWeek = null;

        for (List weeklyRow : ${v}WeeklyValues) {
            System.out.printf("personName: %s\n", (String)weeklyRow.get(0));
            if (personName.equals((String)weeklyRow.get(0))) {
                allowanceAmountInUsd
                    = (BigDecimal)${!decimal_format}.parse((String)weeklyRow.get(1));
                tasksPerWeek = Integer.parseInt((String)weeklyRow.get(2));
                System.out.printf("%.2f, %d\n", allowanceAmountInUsd, tasksPerWeek);
                break;
            }
        }

        if (null == tasksPerWeek || 0 == tasksPerWeek)
            throw new Exception("No tasks found, divide by zero error");

        Integer lastAddedTaskIndex = null;

        // task loop (priority pass: 1st of 2 passes)
        Integer i = ((lastTaskIndex + 1) % (${v}TasksValues.size()-1)) + 1; //row 1 thru end
        Integer satisfiedTasks = 0;
        for (Integer j = 0; j < ${v}TasksValues.size(); j++) {
            // ignore j var
            boolean zeroTask = "Y".equals(
                (String)${v}TasksValues.get(i).get(1)
            ); // pays $0 but is expected to be completed
            boolean isPersonTask = personName.equals(
                (String)${v}TasksValues.get(i).get(2)
            );
            boolean isPersonStickyTask = zeroTask && isPersonTask;

            if (!${v}TakenTaskIndices.contains(j) && isPersonStickyTask) {
                List<Object> cols = new ArrayList<Object>();
                cols.add(${v}Timestamp);
                cols.add("'+");
                cols.add(personName);
                cols.add(new BigDecimal(0));
                cols.add("REQUIRED " + ${v}TasksValues.get(i).get(0));
                cols.add("N"); // not approved yet
                ${v}AppendValues.add(cols);
                ${v}TakenTaskIndices.add(i);
                lastAddedTaskIndex = i;
            } else if (!${v}TakenTaskIndices.contains(j) && isPersonTask && satisfiedTasks < tasksPerWeek) {
                satisfiedTasks += 1;
                List<Object> cols = new ArrayList<Object>();
                cols.add(${v}Timestamp);
                cols.add("'+");
                cols.add(personName);
                cols.add(allowanceAmountInUsd
                    .divide(
                        new BigDecimal(tasksPerWeek),
                        2,
                        RoundingMode.HALF_UP
                    )
                );
                cols.add(${v}TasksValues.get(i).get(0));
                cols.add("N"); // not approved yet
                ${v}AppendValues.add(cols);
                ${v}TakenTaskIndices.add(i);
                lastAddedTaskIndex = i;
            } // else skip other person's task
            i = ((i + 1) % (${v}TasksValues.size() - 1)) + 1; // row 1 thru end
        }

        PersonAllowanceState state = new PersonAllowanceState.Builder()
            .lastTaskIndex(lastAddedTaskIndex)
            .satisfiedTasks(satisfiedTasks)
            .personName(personName)
            .tasksPerWeek(tasksPerWeek)
            .allowanceInUsd(allowanceAmountInUsd)
            .build();

        ${v}PersonStateMap.put(${v}I, state);

        ${v}I += 1;
        System.out.println("-----\n\n");
    }

    ${v}Once = false;
    ${v}I = 0;
    for (List row : ${v}Values) {
        if (!${v}Once) {
            ${v}Once = true;
            continue; // skip header row
        }

        PersonAllowanceState state = ${v}PersonStateMap.get(${v}I);

        // task loop (no-priority pass: 2nd of 2 passes)
        Integer i = ((state.lastTaskIndex + 1) % (${v}TasksValues.size()-1)) + 1; //1-end
        Integer satisfiedTasks = 0;
        for (Integer j = 0; j < ${v}TasksValues.size(); j++) {
            // ignore j var
            boolean zeroTask = "Y".equals(
                (String)${v}TasksValues.get(i).get(1)
            ); // pays $0 but is expected to be completed

            if (!${v}TakenTaskIndices.contains(j) && !zeroTask && state.satisfiedTasks < state.tasksPerWeek) {
                state.satisfiedTasks += 1;
                List<Object> cols = new ArrayList<Object>();
                cols.add(${v}Timestamp);
                cols.add("'+");
                cols.add(state.personName);
                cols.add(state.allowanceInUsd
                    .divide(
                        new BigDecimal(state.tasksPerWeek),
                        2,
                        RoundingMode.HALF_UP
                    )
                );
                cols.add(${v}TasksValues.get(i).get(0));
                cols.add("N"); // not approved yet
                ${v}AppendValues.add(cols);
                ${v}TakenTaskIndices.add(i);
                state.lastTaskIndex = i;
            }
            i = ((i + 1) % (${v}TasksValues.size() - 1)) + 1; // row 1 thru end
        }


        List<Object> updateCols = new ArrayList<Object>();
        updateCols.add(state.personName);
        updateCols.add(state.lastTaskIndex);
        ${v}UpdateValues.add(updateCols);

        ${v}I += 1;
    }

    ValueRange ${v}AppendValueRange = new ValueRange();
    ${v}AppendValueRange.setValues(${v}AppendValues);
    AppendValuesResponse ${v}AppendResponse = ${!sheet_service}.spreadsheets().values()
        .append(
            ${!spreadsheet_id},
            "Pending Transactions!A:A",
            ${v}AppendValueRange
        )
        .setValueInputOption("USER_ENTERED")
        .execute();

    ValueRange ${v}UpdateValueRange = new ValueRange();
    ${v}UpdateValueRange.setValues(${v}UpdateValues);
    UpdateValuesResponse ${v}UpdateResponse = ${!sheet_service}.spreadsheets().values()
        .update(
            ${!spreadsheet_id},
            "Opx State!A2:B3", // skip header row
            ${v}UpdateValueRange
        )
        .setValueInputOption("USER_ENTERED")
        .execute();

EOF
