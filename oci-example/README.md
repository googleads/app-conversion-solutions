# Introduction
This is a demo Java project that parses a CSV file exported from AppsFlyer containing raw attribution data, and uploads the first open events to **Google Ads Offline Conversion Import** API using existing OAuth credentials and Google Ads Developer Token. ([Create OAuth2 Credentials](https://developers.google.com/google-ads/api/docs/client-libs/java/oauth-web), [Obtain Google Ads Developer Token](https://developers.google.com/google-ads/api/docs/first-call/dev-token))

For demonstration purpose, only first open events are parsed and uploaded to Google Ads conversions in this example. However, the code can be modified to parse and upload multiple Google Ads conversions as long as each event is mapped to a unique conversion id.

This demo assumes the attribution data comes from pre-configured AppsFlyer onelink, with AppsFlyer parameters `af_sub1`, `af_sub2`, `af_sub3` mapping to `gclid`, `gbraid`, and `wbraid`, which are tracking parameters for Google Ads. ([GCLID](https://support.google.com/google-ads/answer/9744275), [GBRAID and WBRAID](https://support.google.com/analytics/answer/11367152))

# How to Use
This demo Java project can be packaged into a Jar using `mvn package`. Then the Jar can be run using the following command.
```bash
java -jar oci-example-1.0-SNAPSHOT-jar-with-dependencies.jar ${mcc} ${devToken} ${client_id} ${client_secret} ${refresh_token} ${conversion_id} ${path_to_csv}
```