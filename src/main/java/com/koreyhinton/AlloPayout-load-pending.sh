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
        |--------------------+--------+-----------------|
        | A                  | B      | C               |
        |--------------------+--------+-----------------|
        | Task               | Sticky | Priority Person |
        |--------------------+--------+-----------------|
        | Play with the cats | N      | Alice           |
        |--------------------+--------+-----------------|
    */
    String ${v}TasksRange = "Tasks!A:C";
    ValueRange ${v}TasksResponse = ${!sheet_service}.spreadsheets().values()
        .get(${!spreadsheet_id}, ${v}TasksRange)
        .execute();
    List<List<Object>> ${v}TasksValues = ${v}TasksResponse.getValues();
    if (${v}TasksValues == null || ${v}TasksValues.isEmpty())
        throw new Exception("No data found in sheet: Tasks");
    if (${v}TasksValues.size() < 2)
        throw new Exception("No tasks found in sheet: Tasks (only the header row)");

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

    List<List<Object>> ${v}AppendPendingTasksValues = new ArrayList<List<Object>>();
    // person name (= their tab name) -> rows of: Amount, Description
    Map<String, List<List<Object>>> ${v}AppendPersonToChoresValues = new LinkedHashMap<>();
    // a person tab must not overwrite one of these (lowercase: Sheets tab
    // names are case-insensitive)
    Set<String> ${v}ReservedTabs = Set.of(
        "pending transactions", "transactions", "opx state", "tasks", "weekly allowance"
    );
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
        if (${v}ReservedTabs.contains(personName.toLowerCase()))
            throw new Exception("Person name matches an existing sheet tab: " + personName);
        ${v}AppendPersonToChoresValues.put(personName, new ArrayList<List<Object>>());

        // lastTaskIndex's range is 1-n (or if set to 0 it is reassigned to n)
        Integer lastTaskIndex = Integer.parseInt((String)row.get(1));
        if (lastTaskIndex == 0) lastTaskIndex = ${v}TasksValues.size()-1;
        System.out.printf("%s %d\n", personName, lastTaskIndex);

        BigDecimal allowanceAmountInUsd = BigDecimal.ZERO;
        Integer tasksPerWeek = null;

        for (List weeklyRow : ${v}WeeklyValues) {
            // System.out.printf("personName: %s\n", (String)weeklyRow.get(0));
            if (personName.equals((String)weeklyRow.get(0))) {
                allowanceAmountInUsd
                    = (BigDecimal)${!decimal_format}.parse((String)weeklyRow.get(1));
                tasksPerWeek = Integer.parseInt((String)weeklyRow.get(2));
                // System.out.printf("%.2f, %d\n", allowanceAmountInUsd, tasksPerWeek);
                break;
            }
        }

        if (null == tasksPerWeek || 0 == tasksPerWeek)
            throw new Exception("No tasks found, divide by zero error");

        // task loop (required pass: 1st of 3 passes)
        Integer satisfiedTasks = 0;

        for (Integer j = 0; j < ${v}TasksValues.size()-1; j++) { // -1 to skip header
            // j + 1 for everything to start at the data row
            System.out.printf("%d\n", j+1);
            boolean zeroTask = "Y".equals(
                (${v}TasksValues.get(j+1).size() > 1 ? (String)${v}TasksValues.get(j+1).get(1) : "").toUpperCase()
            ); // pays $0 but is expected to be completed
            boolean isPersonTask = personName.equals(
                (${v}TasksValues.get(j+1).size() > 2 ? (String)${v}TasksValues.get(j+1).get(2) : "")
            );
            boolean isPersonStickyTask = zeroTask && isPersonTask;
            // System.out.printf("%d %b %b\n", j+1, zeroTask, isPersonTask);
            if (!${v}TakenTaskIndices.contains(j+1) && isPersonStickyTask) {
                List<Object> cols = new ArrayList<Object>();
                cols.add(${v}Timestamp);
                cols.add("'+");
                cols.add(personName);
                cols.add(new BigDecimal(0));
                cols.add("REQUIRED " + ${v}TasksValues.get(j+1).get(0));
                cols.add("N"); // not approved yet
                ${v}AppendPendingTasksValues.add(cols);
                String ${v}mob_wrap_TextIn = String.valueOf(cols.get(4));
                ` ./AlloPayout-mobile-text-wrap.sh ${v}mob_wrap_ `
                ${v}AppendPersonToChoresValues.get((String)cols.get(2)).add(List.<Object>of(
                    ${!decimal_format}.format(cols.get(3)),
                    ${v}mob_wrap_TextOut
                ));
                ${v}TakenTaskIndices.add(j+1);
                System.out.printf("REQUIRED Person task %s %s %d\n", personName, ${v}TasksValues.get(j+1).get(0), j+1);
            }
        }

        PersonAllowanceState state = new PersonAllowanceState.Builder()
            .lastTaskIndex(lastTaskIndex)
            .captureTaskIndex(lastTaskIndex)
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
    ${v}I = 0; // person index map (skips header, 0 is first data row)
    for (List row : ${v}Values) {
        if (!${v}Once) {
            ${v}Once = true;
            continue; // skip header row
        }

        PersonAllowanceState state = ${v}PersonStateMap.get(${v}I);

        // task loop (priority pass: 2nd of 3 passes)
        Integer i = (state.lastTaskIndex % (${v}TasksValues.size()-1)) + 1; //1 thru end
System.out.printf("Seeking starting at index: %d\n", i);
        for (Integer j = 0; j < ${v}TasksValues.size()-1; j++) { // -1 to skip header
            // ignore j var
            boolean zeroTask = "Y".equals(
                (${v}TasksValues.get(i).size() > 1 ? (String)${v}TasksValues.get(i).get(1) : "").toUpperCase()
            ); // pays $0 but is expected to be completed
            boolean isPersonTask = state.personName.equals(
                (${v}TasksValues.get(i).size() > 2 ? (String)${v}TasksValues.get(i).get(2) : "")
            );
            System.out.printf("%s %d %b %b %b\n", state.personName, i, !${v}TakenTaskIndices.contains(i), !zeroTask, isPersonTask);
            if (
                !${v}TakenTaskIndices.contains(i) && !zeroTask &&
                state.satisfiedTasks < state.tasksPerWeek && isPersonTask
            ) {
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
                ${v}AppendPendingTasksValues.add(cols);
                String ${v}mob_wrap_TextIn = String.valueOf(cols.get(4));
                ` ./AlloPayout-mobile-text-wrap.sh ${v}mob_wrap_ `
                ${v}AppendPersonToChoresValues.get((String)cols.get(2)).add(List.<Object>of(
                    ${!decimal_format}.format(cols.get(3)),
                    ${v}mob_wrap_TextOut
                ));
                ${v}TakenTaskIndices.add(i);
                state.lastTaskIndex = i;
                System.out.printf("priority loop %s %d %s\n", state.personName, i, ${v}TasksValues.get(i).get(0));
            }
            i = (i % (${v}TasksValues.size()-1)) + 1; // row 1 thru end
        }
        ${v}I += 1;
    }

    ${v}Once = false;
    ${v}I = 0; // person index map (skips header, 0 is first data row)
    for (List row : ${v}Values) {
        if (!${v}Once) {
            ${v}Once = true;
            continue; // skip header row
        }

        PersonAllowanceState state = ${v}PersonStateMap.get(${v}I);

        // reset the lastTaskIndex
        if (state.satisfiedTasks < state.tasksPerWeek)
            state.lastTaskIndex = state.captureTaskIndex;

        // task loop (no-priority pass: 3rd of 3 passes)
        Integer i = (state.lastTaskIndex % (${v}TasksValues.size()-1)) + 1; //1 thru end
        Integer satisfiedTasks = 0;
        for (Integer j = 0; j < ${v}TasksValues.size()-1; j++) {// -1 to skip header
            // ignore j var
            boolean zeroTask = "Y".equals(
                (${v}TasksValues.get(i).size() > 1 ? (String)${v}TasksValues.get(i).get(1) : "").toUpperCase()
            ); // pays $0 but is expected to be completed

            if (!${v}TakenTaskIndices.contains(i) && !zeroTask && state.satisfiedTasks < state.tasksPerWeek) {
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
                ${v}AppendPendingTasksValues.add(cols);
                String ${v}mob_wrap_TextIn = String.valueOf(cols.get(4));
                ` ./AlloPayout-mobile-text-wrap.sh ${v}mob_wrap_ `
                ${v}AppendPersonToChoresValues.get((String)cols.get(2)).add(List.<Object>of(
                    ${!decimal_format}.format(cols.get(3)),
                    ${v}mob_wrap_TextOut
                ));
                ${v}TakenTaskIndices.add(i);
                state.lastTaskIndex = i;
                System.out.printf("non-priority loop %s %d\n", state.personName, i);
            }
            i = (i % (${v}TasksValues.size()-1)) + 1; // row 1 thru end
        }

        List<Object> updateCols = new ArrayList<Object>();
        updateCols.add(state.personName);
        updateCols.add(state.lastTaskIndex);
        ${v}UpdateValues.add(updateCols);

        ${v}I += 1;
    }

    // create any person tabs that don't exist yet. This runs before this step's
    // other writes, so if it fails, Pending Transactions and Opx State are
    // unchanged and a re-run assigns the same chores.
    // Sheets tab names are case-insensitive, so compare lowercased.
    Set<String> ${v}ExistingTabs = new HashSet<>();
    for (Sheet tab : ${!sheet_service}.spreadsheets()
            .get(${!spreadsheet_id}).execute().getSheets())
        ${v}ExistingTabs.add(tab.getProperties().getTitle().toLowerCase());
    List<Request> ${v}AddTabRequests = new ArrayList<>();
    for (String personName : ${v}AppendPersonToChoresValues.keySet()) {
        if (!${v}ExistingTabs.contains(personName.toLowerCase()))
            ${v}AddTabRequests.add(new Request().setAddSheet(
                new AddSheetRequest().setProperties(
                    new SheetProperties().setTitle(personName)
                )
            ));
    }
    if (!${v}AddTabRequests.isEmpty())
        ${!sheet_service}.spreadsheets()
            .batchUpdate(
                ${!spreadsheet_id},
                new BatchUpdateSpreadsheetRequest().setRequests(${v}AddTabRequests)
            )
            .execute();

    ValueRange ${v}AppendValueRange = new ValueRange();
    ${v}AppendValueRange.setValues(${v}AppendPendingTasksValues);
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
            "Opx State!A2:B" + (${v}UpdateValues.size() + 1), // skip header row
            ${v}UpdateValueRange
        )
        .setValueInputOption("USER_ENTERED")
        .execute();

    /* Person chore tabs (one per person, tab name = person name)
        |---------+-------------------------------------------|
        | A       | B                                         |
        |---------+-------------------------------------------|
        | Amount  | Description                               |
        |---------+-------------------------------------------|
        | \$2.00   | Wipe down the baseboards in your room an- |
        |         | d clean your window                       |
        |---------+-------------------------------------------|
    */

    // clear last week's rows (keep the header row), then write header + rows
    List<String> ${v}ChoreClearRanges = new ArrayList<>();
    List<ValueRange> ${v}ChoreWrites = new ArrayList<>();
    for (Map.Entry<String, List<List<Object>>> entry
            : ${v}AppendPersonToChoresValues.entrySet()) {
        // quote for A1 notation: O'Neil -> 'O''Neil'
        String tab = "'" + entry.getKey().replace("'", "''") + "'";
        ${v}ChoreClearRanges.add(tab + "!A2:B");
        List<List<Object>> rows = new ArrayList<List<Object>>();
        rows.add(List.<Object>of("Amount", "Description"));
        rows.addAll(entry.getValue());
        ${v}ChoreWrites.add(new ValueRange().setRange(tab + "!A1").setValues(rows));
    }
    ${!sheet_service}.spreadsheets().values()
        .batchClear(
            ${!spreadsheet_id},
            new BatchClearValuesRequest().setRanges(${v}ChoreClearRanges)
        )
        .execute();
    ${!sheet_service}.spreadsheets().values()
        .batchUpdate(
            ${!spreadsheet_id},
            new BatchUpdateValuesRequest()
                .setValueInputOption("USER_ENTERED")
                .setData(${v}ChoreWrites)
        )
        .execute();

EOF
