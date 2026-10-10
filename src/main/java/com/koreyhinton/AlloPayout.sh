#!/bin/bash

# DOCUMENTATION URLS
#
# SheetService setup / Read Values
# https://developers.google.com/workspace/sheets/api/quickstart/java
#
# Append Values
# https://developers.google.com/workspace/sheets/api/guides/values#java_4
#
# Update Values
# https://developers.google.com/workspace/sheets/api/guides/values#java_2

v=${1:-mn_}
# maps
export ${v}lp_SheetService=${v}SheetService
export ${v}lp_SpreadsheetId=${v}SpreadsheetId

cat << EOF
    package com.koreyhinton;

    import com.google.auth.http.HttpCredentialsAdapter;
    import com.google.auth.oauth2.GoogleCredentials;
    import com.google.api.client.auth.oauth2.Credential;
    import com.google.api.client.googleapis.auth.oauth2.GoogleAuthorizationCodeFlow;
    import com.google.api.client.googleapis.auth.oauth2.GoogleClientSecrets;
    import com.google.api.client.googleapis.javanet.GoogleNetHttpTransport;
    import com.google.api.client.http.javanet.NetHttpTransport;
    import com.google.api.client.json.JsonFactory;
    import com.google.api.client.json.gson.GsonFactory;
    import com.google.api.client.util.store.FileDataStoreFactory;
    import com.google.api.services.sheets.v4.Sheets;
    import com.google.api.services.sheets.v4.SheetsScopes;
    import com.google.api.services.sheets.v4.model.ValueRange;
    import java.io.FileNotFoundException;
    import java.io.IOException;
    import java.io.InputStream;
    import java.io.InputStreamReader;
    import java.math.BigDecimal;
    import java.math.RoundingMode;
    import java.security.GeneralSecurityException;
    import java.text.DecimalFormat;
    import java.text.NumberFormat;
    import java.time.format.DateTimeFormatter;
    import java.time.LocalDateTime;
    import java.util.ArrayList;
    import java.util.Collections;
    import java.util.List;
    import java.util.Locale;

    public class AlloPayout {
        public static void main(String[] args) throws Exception {
            String ${v}SpreadsheetId = System.getenv("SPREADSHEET_ID");
            if (null == ${v}SpreadsheetId)
                throw new Exception("SPREADSHEET_ID env var must be set");
            String credentialsFilePath = System.getenv("CREDENTIALS_FILE_PATH");
            if (null == credentialsFilePath)
                throw new Exception("CREDENTIALS_FILE_PATH env var must be set");
            Sheets ${v}SheetService;
            try {
                NetHttpTransport httpTransport
                    = GoogleNetHttpTransport.newTrustedTransport();
                JsonFactory jsonFactory = GsonFactory.getDefaultInstance();

                InputStream in = new java.io.FileInputStream(
                    credentialsFilePath
                );
                if (in == null)
                    throw new FileNotFoundException("File not found: " +
                        credentialsFilePath);
                List<String> scopes = Collections.singletonList(
                    SheetsScopes.SPREADSHEETS);
                GoogleCredentials googleAuthCredentials = GoogleCredentials
                    .fromStream(in)
                    .createScoped(scopes);
                ${v}SheetService =
                    new Sheets.Builder(
                        httpTransport,
                        jsonFactory,
                        new HttpCredentialsAdapter(googleAuthCredentials)
                    ).setApplicationName("AlloPayout")
                    .build();
            } catch (Exception e) {
                System.out.println("Unable to initialize google sheet service");
                throw e;
            }

            ` ./AlloPayout-load-transactions.sh ${v}lt_ `
            ` ./AlloPayout-load-pending.sh ${v}lp_ `
        }
    }
EOF
