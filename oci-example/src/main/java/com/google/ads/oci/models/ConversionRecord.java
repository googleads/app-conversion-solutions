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
