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
package com.google.ads.oci.models;

import io.grpc.netty.shaded.io.netty.util.internal.StringUtil;
import org.apache.commons.csv.CSVRecord;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Objects;
import java.util.Optional;
import java.util.stream.Collectors;

public class AFConversionRecord extends ConversionRecord{
    private static final DateTimeFormatter AF_DATE_TIME_FORMATTER = DateTimeFormatter.ofPattern("yyyy/M/d H:m");
    private static final DateTimeFormatter OCI_DATE_TIME_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss+00:00");
    private AFConversionRecord(String gclid, String gbraid, String wbraid, Double value, String currencyCode, String conversionDateTime) {
        super(gclid, gbraid, wbraid, value, currencyCode, conversionDateTime);
    }

    public static List<AFConversionRecord> ofList(List<CSVRecord> csvRecords) {
        return csvRecords.stream().map(AFConversionRecord::of).map(optionalRecord -> optionalRecord.orElse(null))
                .filter(Objects::nonNull).collect(Collectors.toList());
    }

    public static Optional<AFConversionRecord> of(CSVRecord csvRecord) {
        String convertedDateTime = LocalDateTime.parse(csvRecord.get("Event Time"), AF_DATE_TIME_FORMATTER).format(OCI_DATE_TIME_FORMATTER);
        String gclid = csvRecord.get("Sub Param 1");
        String wbraid = csvRecord.get("Sub Param 3");
        String valueStr = csvRecord.get("Event Value");
        String currencyCode = csvRecord.get("Event Revenue Currency");

        if (StringUtil.isNullOrEmpty(gclid) && StringUtil.isNullOrEmpty(wbraid)) {
            System.out.println("Both gclid and wbraid are empty, csv record: " + csvRecord);
            return Optional.empty();
        }

        return Objects.equals(csvRecord.get("Event Name"), "install")? Optional.of(
                new AFConversionRecord(
                        gclid,
                        null,
                        wbraid,
                        StringUtil.isNullOrEmpty(valueStr) ? null : Double.parseDouble(valueStr),
                        StringUtil.isNullOrEmpty(currencyCode) ? null : currencyCode,
                        convertedDateTime))
                : Optional.empty();
    }
}