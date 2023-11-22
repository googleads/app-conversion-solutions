# Project Bare Metal

## Disclaimer
Copyright 2019 Google LLC. This solution, including any related sample code or data, is made available on an “as is,” “as available,” and “with all faults” basis, solely for illustrative purposes, and without warranty or representation of any kind. This solution is experimental, unsupported and provided solely for your convenience. Your use of it is subject to your agreements with Google, as applicable, and may constitute a beta feature as defined under those agreements.  To the extent that you make any data available to Google in connection with your use of the solution, you represent and warrant that you have all necessary and appropriate rights, consents and permissions to permit Google to use and process that data.  By using any portion of this solution, you acknowledge, assume and accept all risks, known and unknown, associated with its usage, including with respect to your deployment of any portion of this solution in your systems, or usage in connection with your business, if at all.


## First time setup
1. Install Google Cloud SDK on your machine (or use the Google Cloud Shell).

2. Create a blank GCP project.

3. Run the following command to deploy the project.
```bash
PROJECT_ID=your_project BUCKET_NAME=your_bucket bash bin/deploy.sh
```
The deployment is successful if you see "Deployment success" at the end.

## Redeployment
After changing the code, you can redeploy only the cloud functions using the following command:
```bash
bash bin/deploy-functions.sh
```

## Input files
See `example/data.csv` for examples of input data files. Please prepare your data with the same COLUMN NAMES as the example.
You can use a command like `gsutil cp file.csv gs://$BUCKET_NAME/input`