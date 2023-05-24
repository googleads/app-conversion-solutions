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

public abstract class ConversionRecord {
    private final String gclid;
    private final String gbraid;
    private final String wbraid;
    private final Double value;
    private final String currencyCode;
    private final String conversionDateTime;

    protected ConversionRecord(String gclid, String gbraid, String wbraid, Double value, String currencyCode, String conversionDateTime) {
        this.gclid = gclid;
        this.gbraid = gbraid;
        this.wbraid = wbraid;
        this.value = value;
        this.currencyCode = currencyCode;
        this.conversionDateTime = conversionDateTime;
    }

    public String getGCLID() {
        return gclid;
    }

    public String getGBRAID() {
        return gbraid;
    }

    public String getWBRAID() {
        return wbraid;
    }

    public double getValue() {
        return value;
    }

    public String getCurrencyCode() {
        return currencyCode;
    }

    public String getConversionDateTime() {
        return conversionDateTime;
    }
}
