# Disclaimer
*Copyright Google LLC. Supported by Google LLC and/or its affiliate(s). This solution, including any related sample code or data, is made available on an “as is,” “as available,” and “with all faults” basis, solely for illustrative purposes, and without warranty or representation of any kind. This solution is experimental, unsupported and provided solely for your convenience. Your use of it is subject to your agreements with Google, as applicable, and may constitute a beta feature as defined under those agreements.  To the extent that you make any data available to Google in connection with your use of the solution, you represent and warrant that you have all necessary and appropriate rights, consents and permissions to permit Google to use and process that data.  By using any portion of this solution, you acknowledge, assume and accept all risks, known and unknown, associated with its usage and any processing of data by Google, including with respect to your deployment of any portion of this solution in your systems, or usage in connection with your business, if at all. With respect to the entrustment of personal information to Google, you will verify that the established system is sufficient by checking Google's privacy policy and other public information, and you agree that no further information will be provided by Google.*
MAPIT is intended to be used for conversion tracking, and is not intended to be used for fingerprinting purposes, tracking user behavior, and/or tracking stored preferences.


# Introduction
This is a demo Java project that parses a CSV file exported from AppsFlyer containing raw attribution data, and uploads the first open events to **Google Ads Offline Conversion Import** API using existing OAuth credentials and Google Ads Developer Token. ([Create OAuth2 Credentials](https://developers.google.com/google-ads/api/docs/client-libs/java/oauth-web), [Obtain Google Ads Developer Token](https://developers.google.com/google-ads/api/docs/first-call/dev-token))

For demonstration purpose, only first open events are parsed and uploaded to Google Ads conversions in this example. However, the code can be modified to parse and upload multiple Google Ads conversions as long as each event is mapped to a unique conversion id.

This demo assumes the attribution data comes from pre-configured AppsFlyer onelink, with AppsFlyer parameters `af_sub1`, `af_sub2`, `af_sub3` mapping to `gclid`, `gbraid`, and `wbraid`, which are tracking parameters for Google Ads. ([GCLID](https://support.google.com/google-ads/answer/9744275), [GBRAID and WBRAID](https://support.google.com/analytics/answer/11367152))

# How to Use
This demo Java project can be packaged into a Jar using `mvn package`. Then the Jar can be run using the following command.
```bash
java -jar oci-example-1.0-SNAPSHOT-jar-with-dependencies.jar ${mcc} ${devToken} ${client_id} ${client_secret} ${refresh_token} ${conversion_id} ${path_to_csv}
```