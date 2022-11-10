# Introduction

This is a sample landing page with conversion tracking enabled for web to app campaign setting, it contains these functions:

1. A html framework to show the app content as the landing page, you just fill in your content here.
2. A button navigate to the app store / google play store(browser auto detected)
3. The sample gtag configuration and easy to edit and reuse
4. (OPTIONAL) Automatically use the clipboardjs to copy and paste "referral code" and bring into the installed app landing page.
5. (OPTIONAL) Asychronized communicate with your own server to store event and fetch the customized parameters.

# How to use
1. Create a Website conversion in Google Ads
2. Edit the conversionId like AW-123456789
3. Edit the app URL: iOSUrl and androidUrl
4. Edit the googleCode, to specific the conversion event
5. (OPTIONAL) Edit the ajax request part, communicate with your own server to customize the parameters

# Appendix

1. What is gtag? --> [gtagjs](https://developers.google.com/analytics/devguides/collection/gtagjs)
2. What is clipboardjs? --> [clipboardjs.com](https://clipboardjs.com/)
3. What is conversionId(Google Tag) and conversionId(Event Snippet) --> [Google Ads Support](https://support.google.com/google-ads/answer/7548399?hl=en)