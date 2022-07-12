# Google App Campaign Data Loader Demo

This is a demo to get attributed campaign data from [App Conversion Tracking API](https://developers.google.com/app-conversion-tracking/api) on device. By doing this you can provide deferred deep linking capability to end-users based on the ads they clicked before.

Besides the implementation of [App Conversion Tracking API Call](https://developers.google.com/app-conversion-tracking/api), this toolkit embeds several features to improve the success rate and make this earsier to use.

1. Retry when network related error returns.
2. Configurable timeout.
3. Configurable back-off time when retrying for timestamp_invalid errors.
4. Built-in function to filter obsolete campaign data. 

## Deferred deep linking data flow
![Screen Shot 2019-12-11 at 3.24.12 PM.png](https://s2.loli.net/2022/05/18/p2YoUNacf9mKxDF.png)

## Usage

### iOS
Please refer to CampaignTracker.swift, call the CampaignTracker like this:
```swift
 //首次打开触发DDL
if isAppAlreadyLaunchedOnce() {
    let campaignTracker: CampaignTracker = CampaignTracker(devToken: "devToken", linkId: "linkId")
    campaignTracker.acquireCampaignInfo(tryTimes: 10, timeoutSeconds: 3, success
        : {
            let adGroupId = campaignTracker.fetchAdGroupIdWithinDays(days: 30)
            // todo, ad group id存在的情况下去查询对应的deep link并跳转
                    
        }, fail: {
                // todo, DDL 逻辑不被触发的情况下执行xxx
    })
}
```

### android
Add the required dependencies into your build.gradle under app folder.

```gradle
    implementation 'com.android.volley:volley:1.1.1'
    implementation 'com.google.android.gms:play-services-base:16.0.1'
```

Please refer to CampaignTrackTask.java, call the CampaignTrackTask like this:
```java
//需要判断app是否首次打开，首次打开触发DDL
CampaignTrackTask campaignTrackTask = (CampaignTrackTask) new CampaignTrackTask("devToken", "linkId", MainActivity.this.getApplicationContext(), 3, 2000, 10, new DDLcallback() {
            @Override
            public void execute() {
                //TODO 获取到google ads campaign ad group信息后，执行业务逻辑
            }
        }, new DDLcallback() {
            @Override
            public void execute() {
                //TODO DDL触发失败的逻辑
            }
        }).execute();
```

## Testing

You may need to mock google's response(see step 4 in above data flow) for conversion tracking testing. Since google doesn't provide a official testing interface, here we provide some typical responses in normal/exception cases. You can use this data to replace the actual response from google, but do please rollback the code to normal when you come to release apps.

### normal cases

* first_open attributed


```json
{
    "ad_events": [
        {
            "ad_event_id": "Q2owS0VRancwZHk0QlJDdXVMX2U1TQ",
            "conversion_metric": "conversion",
            "interaction_type": "engagement",
            "campaign_type": "ACI",
            "campaign_id": 123456789,
            "campaign_name": "My App Campaign",
            "ad_type": "ClickToDownload",
            "external_customer_id": 123456789,
            "location": 21144,
            "network_type": "Search",
            "network_subtype": "GoogleSearch",
            "video_id": null,
            "keyword": null,
            "match_type": null,
            "placement": null,
            "ad_group_id": 987654321,
            "ad_group_name": "My Ad Group",
            "creative_id": null,
            "timestamp": 1432681913.123456
        }
    ],
    "errors": [],
    "attributed": true
}
```

* first_open not attributed

```json
{
    "ad_events": [],
    "errors": [],
    "attributed": false
}
```

### exception cases

* timestamp_invalid

```json
{
    "ad_events": [],
    "errors": [
        "timestamp_invalid"
    ],
    "attributed": false
}
```

* linkid invalid

```json
{
    "ad_events": [],
    "errors": [
        "link_id_invalid"
    ],
    "attributed": false
}
```

* dev token invalid

```json
{
    "ad_events": [],
    "errors": [
        "dev_token_invalid"
    ],
    "attributed": false
}
```

## License & Disclaimer
### Disclaimer

PLEASE NOTE THIS IS NOT A GOOGLE PRODUCT (NOT BUILT ON ADS INFRASTRUCTURE NOR SUPPORTED BY GOOGLE ENGINEERING). WE CAN’T GUARANTEE SOLUTION STABILITY AND PERFORMANCE. ONLY USE WHEN UNDERSTAND THESE RISKS.


## License

Copyright 2019 Google LLC. This software is provided as-is, without warranty or representation for any use or purpose. Your use of it is subject to your agreements with Google.

SPDX-License-Identifier: Apache-2.0

## Implementation Guidelines

Please contact dongche@google.com or corresponding Google Representative to get more detail implementation steps.