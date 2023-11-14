"""Google Ads Converstion API."""

import argparse
import logging
import re
import sys
import urllib
import uuid
import csv

from google.ads.googleads.client import GoogleAdsClient
from google.ads.googleads.errors import GoogleAdsException
from google.cloud import storage


_API_VERSION = 'v13'

_STATUS_SUCCESS = 'SUCCESS'
_STATUS_FAIL = 'FAIL'


class ConversionClient:
  """Google Ads conversion client."""

  def __init__(self, config_path):
    """Constructor."""
    # Install requirements with `pip install google-ads~=14.0.0`
    # https://github.com/googleads/google-ads-python/blob/master/google-ads.yaml
    # https://developers.google.com/google-ads/api/docs/client-libs/python/configuration
    if config_path.startswith('gs://'):
      storage_client = storage.Client()
      config_url = urllib.parse.urlparse(config_path)
      bucket, path = config_url.netloc, re.sub(r'^/', '', config_url.path)
      print('config bucket:', bucket, 'path:', path)
      config_blob = storage.Blob(path, storage_client.get_bucket(bucket))
      config_path = '/tmp/google-ads.yaml'
      config_blob.download_to_filename(config_path)

    self.client = GoogleAdsClient.load_from_storage(config_path, version=_API_VERSION)

  def build_event(self, customer_id, conversion_action_id, gclid, gbraid, wbraid,
                  conversion_date_time, conversion_value, currency):
    """Builds a conversion event."""
    # Ref: https://developers.google.com/google-ads/api/reference/rpc/v8/ClickConversion

    click_conversion = self.client.get_type('ClickConversion')
    conversion_action_service = self.client.get_service(
        'ConversionActionService')
    click_conversion.conversion_action = (
        conversion_action_service.conversion_action_path(
            customer_id, conversion_action_id))
    if gclid:
        click_conversion.gclid = gclid
    elif wbraid:
        click_conversion.wbraid = wbraid
    else:
        click_conversion.gbraid = gbraid
    click_conversion.conversion_value = float(conversion_value)
    click_conversion.conversion_date_time = conversion_date_time
    click_conversion.currency_code = currency

    return click_conversion

  def send_event(self, customer_id, conversions, validate_only=False):
    """Sends conversion event."""
    conversion_upload_service = self.client.get_service(
        'ConversionUploadService')
    request = self.client.get_type('UploadClickConversionsRequest')
    request.customer_id = customer_id
    request.conversions = conversions
    request.validate_only = validate_only
    request.partial_failure = True

    try:
      response = conversion_upload_service.upload_click_conversions(
          request=request)
    except GoogleAdsException as ex:
      code = ex.error.code().name
      message = '\n'.join([error.message for error in ex.failure.errors])
      return [{'status': _STATUS_FAIL, 'code': code, 'message': message}
              for _ in conversions]

    results = [{'status': _STATUS_SUCCESS, 'code': '', 'message': ''}
               for _ in conversions]

    partial_failure = getattr(response, 'partial_failure_error', None)
    code = getattr(partial_failure, 'code', 0)
    if code != 0:
      partial_failure = getattr(response, 'partial_failure_error', None)
      # partial_failure_error.details is a repeated field and iterable
      error_details = getattr(partial_failure, 'details', [])

      for error_detail in error_details:
        # Retrieve an instance of the GoogleAdsFailure class from the client
        failure_message = self.client.get_type('GoogleAdsFailure')
        # Parse the string into a GoogleAdsFailure message instance.
        # To access class-only methods on the message we retrieve its type.
        GoogleAdsFailure = type(failure_message)
        failure_object = GoogleAdsFailure.deserialize(error_detail.value)

        for error in failure_object.errors:
          # Construct and print a string that details which element in
          # the above ad_group_operations list failed (by index number)
          # as well as the error message and error code.
          # print('A partial failure at index '
          #       f'{error.location.field_path_elements[0].index} occurred '
          #       f'\nError message: {error.message}\nError code: '
          #       f'{error.error_code}')

          results[error.location.field_path_elements[0].index] = {
              'status': _STATUS_FAIL,
              'code': str(error.error_code),
              'message': error.message
          }

    return results


#     print(conversion_upload_response.results)
#     uploaded_click_conversion = conversion_upload_response.results[0]
#     print(
#         f"Uploaded conversion that occurred at "
#         f'"{uploaded_click_conversion.conversion_date_time}" from '
#         f'Google Click ID "{uploaded_click_conversion.gclid}" '
#         f'to "{uploaded_click_conversion.conversion_action}"'
#     )

if __name__ == '__main__':
  import argparse

  parser = argparse.ArgumentParser(description='Conversion data loader.')
  parser.add_argument(
      '--config',
      dest='config',
      required=True,
      help='Path to google-ads.yaml, can be either a local file or a GCS path gs://.'
  )
  parser.add_argument(
      '--data',
      dest='data',
      required=True,
      help='Path to data. A gs:// file path.')
  parser.add_argument(
      '--validate_only',
      dest='validate_only',
      action='store_true',
      help='Validate data without sending event.')
  parser.add_argument(
      '--batch_size',
      dest='batch_size',
      default=50,
      type=int,
      help='Validate data without sending event.')

  args = parser.parse_args()

  client = ConversionClient(config_path=args.config)

  data_url = urllib.parse.urlparse(args.data)
  bucket, path = data_url.netloc, re.sub(r'^/', '', data_url.path)
  storage_client = storage.Client()
  blob = storage.Blob(path, storage_client.get_bucket(bucket))

  headers = []
  events = []

  def _send_events(events):
    results = client.send_event(
        customer_id=data['customer_id'],
        conversions=events,
        validate_only=args.validate_only)
    for e, r in zip(events, results):
      print('\n====event===\n', e)
      print('\n====result===\n', r)

  with blob.open('rt') as f:
    csv_reader = csv.DictReader(f)
    for data in csv_reader:
      event = client.build_event(
          customer_id=data['customer_id'],
          conversion_action_id=data['conversion_action_id'],
          gclid=data['gclid'],
          gbraid=data['gbraid'],
          wbraid=data['wbraid'],
          conversion_date_time=data['conversion_date_time'],
          conversion_value=data['conversion_value'],
          currency=data['currency'])

      if len(events) >= args.batch_size:
        _send_events(events)
        events = []
      else:
        events.append(event)

    if len(events) >= 0:
      _send_events(events)
      events = []

