---
name: allopayout-review
description: Review changes to AlloPayout (the orc-generated bash-to-Java allowance cron job) for correctness bugs, codegen/namespacing mistakes, and Google Sheets data-handling errors. Use when asked to review the current diff, a commit, a branch, or specific step scripts in this repo.
argument-hint: "[commit | branch | path]  (default: uncommitted changes)"
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git show:*), Bash(git status:*), Bash(./build.sh), Read, Grep, Glob
---

# AlloPayout code review

Review the requested changes and report bugs that would make the weekly run
produce wrong ledger data, crash, or fail to build. This job writes to a real
family ledger with no tests, so a wrong row is worse than a crash. Rank
findings by impact on the spreadsheet.

## 1. Pick the target

- No argument: `git diff HEAD` (staged + unstaged), plus untracked `.sh`/`.java` files from `git status`.
- A commit or range: `git show <sha>` / `git diff <range>`.
- A branch: `git diff main...<branch>`.
- A path: review that file in full.

Always read the full changed `.sh` file, not just the hunk. Spliced blocks
share one `main` method, so a change can break code far from the hunk.

## 2. Generate and compile (if possible)

The Java under review is generated, so check what bash actually emits:

```sh
./build.sh
```

- This needs `../orc` checked out as a sibling. If it's missing, say so in the
  report and review the bash by reading it instead. Don't fake the result.
- When it builds, read `src/main/java/com/koreyhinton/AlloPayout.java` around
  the changed code to confirm the emitted Java is what the author meant.
- **Never run the jar.** It appends rows to the real spreadsheet and clears
  Pending Transactions.

## 3. Checklist

### Codegen and orc namespacing
- Every Java local declared in a step script is prefixed with `${v}`. An
  unprefixed local (e.g. `amount`, `cols`, `row`) is only safe inside a
  block/loop scope. Flag any at method scope, since it can collide with
  another spliced script.
- A new shared variable needs **both** the `export ${v}lp_X=${v}X` /
  `export ${v}lt_X=${v}X` line in `AlloPayout.sh` **and** the name in the
  child's `. ${NSMAP}/bind ${v} ...` list. Usage is `${!snake_case}`, where
  the snake_case name comes from the CamelCase bind name (`DateTimeFormatter`
  becomes `date_time_formatter`).
- Heredocs are unquoted (`<< EOF`). Any literal `$`, backtick, or `\` in Java
  code or comments must be escaped (`\$`, `` \` ``), or bash will expand it.
  Watch string literals, regexes, and comments that mention `$`.
- New step scripts must be executable and spliced into `AlloPayout.sh` with
  their own prefix (`${v}xx_`).
- New imports go in `AlloPayout.sh`. Missing imports only show up at compile time.
- Control flow must be imperative (statements, `if`, loops). Flag new helper
  classes, static utility methods, lambdas or streams. Reusable logic belongs
  in a spliced step script with `<prefix>TextIn`/`<prefix>TextOut`-style
  variables (see `AlloPayout-mobile-text-wrap.sh`).
- Edits should be in the `.sh` files or `models/*.java`, never in the
  generated `AlloPayout.java` (it's gitignored and gets overwritten).

### Google Sheets data handling
- **Ragged rows:** the Sheets API drops trailing empty cells, so `row.get(n)`
  can throw `IndexOutOfBoundsException` when a cell is blank (for example, an
  empty Approved or Priority Person 2 column). Flag unguarded `get` on
  optional columns.
- Cell values arrive as `Object`. Casting to `String` works for formatted
  values, but blank or non-string cells can be `null` or another type.
  Check for null before `.toUpperCase()` or `.equals()`.
- The header row is skipped with the `${v}Once` pattern. Check that new loops
  over sheet values skip it too, and that index math (`${v}I`, task indices,
  Opx State rows written from `A2`) stays consistent with the skipped header.
- `USER_ENTERED` input: text starting with `+`, `-`, or `=`, and strings that
  look like numbers or dates, get reinterpreted. Type `+` must be written as `'+`.
- Ranges: sheet names with spaces need the exact tab name (`"Pending
  Transactions!A:F"`). Check column letters against the ASCII tables in the
  script comments.
- Clear vs. append: clearing Pending Transactions must happen only after the
  Transactions append succeeds, and the clear range count must cover every
  data row (`values.size()` includes the header, so it over-clears by one row,
  which is harmless). Look for any change that could clear before the append
  or drop approved rows.

### Money and task logic
- Amounts are `BigDecimal` parsed with the US currency `DecimalFormat`. Flag
  `double`/`float` math, `new BigDecimal(double)`, `equals` where
  `compareTo` is needed (`2.0` vs `2.00`), and division without a scale and
  `RoundingMode.HALF_UP`. A non-terminating divide throws `ArithmeticException`.
- The currency parser expects `$`-formatted strings. A plain `"2"` from the
  sheet may throw `ParseException`, depending on cell formatting. Check what
  the changed code feeds it.
- Per-task pay is `Amount / tasksPerWeek`. Guard against `tasksPerWeek == 0`.
- Rounding: N tasks × the rounded per-task amount may not equal the weekly
  Amount. Flag a change that makes this drift worse, or that claims exactness.
- Load-pending passes (required → priority → fill):
  - sticky (`Y`) tasks only in the required pass, at $0
  - `TakenTaskIndices` is updated by every pass, so no task goes to two people
  - round-robin starts after the person's last index, wraps with modulo, and
    terminates when there are fewer available tasks than `tasksPerWeek`
    (check for infinite loops)
  - the last index written to Opx State is the one the next run should start after
- `Y`/`N` comparisons should be case-insensitive and whitespace-tolerant
  where the sheet is hand-edited.

### Deployment
- If the change adds env vars, new sheet tabs/columns, or changes the jar
  name, check that `CLAUDE.md`, `README.md`, and `docs/schedule.md` (the cron
  script) still match.

## 4. Report

Lead with a one-line verdict (e.g. "2 bugs, 1 should block merge" or "No
issues found"). Then list findings, most severe first:

```
1. [severity: high|medium|low] path/to/file.sh:LINE — one-sentence defect
   Scenario: concrete sheet state or input → wrong output / crash
   Fix: short suggestion
```

- Report only issues you can tie to a concrete failing scenario. Leave out
  style nits unless asked.
- Say whether `./build.sh` was run and whether it compiled.
- Don't edit files unless the user asks for fixes.
