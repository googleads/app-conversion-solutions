package com.google.ads.oci.service;

import com.google.ads.googleads.lib.GoogleAdsClient;
import com.google.ads.googleads.v13.errors.GoogleAdsFailure;
import com.google.ads.googleads.v13.services.ClickConversion;
import com.google.ads.googleads.v13.services.ConversionUploadServiceClient;
import com.google.ads.googleads.v13.services.UploadClickConversionsRequest;
import com.google.ads.googleads.v13.services.UploadClickConversionsResponse;
import com.google.ads.googleads.v13.utils.ErrorUtils;
import com.google.ads.googleads.v13.utils.ResourceNames;
import com.google.ads.oci.models.AFConversionRecord;
import com.google.auth.oauth2.UserCredentials;
import com.google.common.collect.Lists;
import io.grpc.LoadBalancerRegistry;
import io.grpc.internal.PickFirstLoadBalancerProvider;
import io.grpc.netty.shaded.io.netty.util.internal.StringUtil;

import java.util.List;
import java.util.stream.Collectors;

public class OCIUploadService {
    private final GoogleAdsClient googleAdsClient;

    static {
        LoadBalancerRegistry.getDefaultRegistry().register(new PickFirstLoadBalancerProvider());
    }

    public OCIUploadService(String mccId, String clientId, String clientSecret, String refreshToken, String devToken) {
        UserCredentials credentials =
                UserCredentials.newBuilder()
                        .setClientId(clientId)
                        .setClientSecret(clientSecret)
                        .setRefreshToken(refreshToken)
                        .build();

        // Creates a GoogleAdsClient with the provided credentials.
        googleAdsClient =
                GoogleAdsClient.newBuilder()
                        .setDeveloperToken(devToken)
                        .setCredentials(credentials)
                        .setLoginCustomerId(Long.valueOf(mccId))
                        .build();
    }

    public void uploadAFConversionList(List<AFConversionRecord> afConversionRecordList, long conversionId) {
        long mccID = googleAdsClient.getLoginCustomerId();
        List<ClickConversion> conversions = afConversionRecordList.stream()
                .map(record ->
                        this.buildConversion(mccID, conversionId,
                                record.getGCLID(), record.getWBRAID(), record.getConversionDateTime(), record.getValue(), record.getCurrencyCode())
                ).collect(Collectors.toList());
        Lists.partition(conversions, 50).forEach(partitionedConvs -> this.uploadConversions(mccID, partitionedConvs));
    }

    private ClickConversion buildConversion(
            long customerId,
            long conversionActionId,
            String gclid,
            String wbraid,
            String conversionDateTime,
            Double conversionValue,
            String currencyCode) {
        // Constructs the conversion action resource name from the customer and conversion action IDs.
        String conversionActionResourceName =
                ResourceNames.conversionAction(customerId, conversionActionId);

        // Creates the click conversion.
        ClickConversion.Builder clickConversionBuilder =
                ClickConversion.newBuilder()
                        .setConversionAction(conversionActionResourceName)
                        .setConversionDateTime(conversionDateTime);
        if (conversionValue != null) {
            clickConversionBuilder.setConversionValue(conversionValue).setCurrencyCode(currencyCode);
        }

        // Sets the single specified ID field.
        if (!StringUtil.isNullOrEmpty(gclid)) {
            clickConversionBuilder.setGclid(gclid);
        } else {
            clickConversionBuilder.setWbraid(wbraid);
        }

        return clickConversionBuilder.build();
    }

    private void uploadConversions(long customerId, List<ClickConversion> conversions) {
        try (ConversionUploadServiceClient conversionUploadServiceClient =
                     googleAdsClient.getLatestVersion().createConversionUploadServiceClient()) {
            // Uploads the click conversion. Partial failure should always be set to true.
            UploadClickConversionsRequest.Builder reqBuilder = UploadClickConversionsRequest.newBuilder()
                    .setCustomerId(Long.toString(customerId));
            conversions.forEach(reqBuilder::addConversions);
            UploadClickConversionsResponse response = conversionUploadServiceClient.uploadClickConversions(reqBuilder.setPartialFailure(true).build());

            // Prints any partial errors returned.
            if (response.hasPartialFailureError()) {
                GoogleAdsFailure googleAdsFailure =
                        ErrorUtils.getInstance().getGoogleAdsFailure(response.getPartialFailureError());
                googleAdsFailure
                        .getErrorsList()
                        .forEach(e -> System.out.println("Partial failure occurred: " + e.getMessage()));
            }

            // Prints the result.
            response.getResultsList().forEach(result -> {
                // Only prints valid results.
                if (result.hasConversionAction()) {
                    System.out.printf(
                            "Uploaded conversion that occurred at '%s' to '%s', GCLID: '%s', WBRAID: '%s'.%n",
                            result.getConversionDateTime(), result.getConversionAction(), result.getGclid(), result.getWbraid());
                }
            });
        }
    }
}