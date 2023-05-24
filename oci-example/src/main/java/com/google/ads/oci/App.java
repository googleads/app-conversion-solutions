/*
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.google.ads.oci;

import com.google.ads.oci.models.AFConversionRecord;
import com.google.ads.oci.service.OCIUploadService;
import com.google.ads.oci.utils.CSVUtil;
import com.google.common.base.Preconditions;
import org.apache.commons.csv.CSVRecord;

import java.util.List;

public class App {
    public static void main(String[] args) {
        Preconditions.checkArgument(args != null);
        Preconditions.checkArgument(args.length == 7);

        String mccId = args[0];
        String devToken = args[1];
        String clientId = args[2];
        String clientSecret = args[3];
        String refreshToken = args[4];
        String conversionId = args[5];
        String csvFilePath = args[6];

        List<CSVRecord> records =  CSVUtil.readAppsFlyerCSV(csvFilePath);
        OCIUploadService ociUploadService = new OCIUploadService(mccId, clientId, clientSecret, refreshToken, devToken);
        ociUploadService.uploadAFConversionList(AFConversionRecord.ofList(records), Long.parseLong(conversionId));
    }
}
