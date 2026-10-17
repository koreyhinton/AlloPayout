# AlloPayout

Allowance payout cron app. Java code is bash-assembled using [orc](https://github.com/koreyhinton/orc).

## Build

`./build.sh`

## Run

```sh
CREDENTIALS_FILE_PATH="${credentials_json_filepath}" SPREADSHEET_ID="${spreadhseet_id}" java -jar build/libs/AlloPayout.jar
```

## Schedule

[docs/schedule.md](docs/schedule.md)
