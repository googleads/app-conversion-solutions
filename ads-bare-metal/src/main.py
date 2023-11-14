# pylint: disable=missing-function-docstring
"""Main file for cloud functions."""
import logging
import utils
import json
import math
import config
import csv
import datetime
import uuid
import os
import pkg_resources
import gspread
import google.auth

from google.cloud import storage
from google.cloud import bigquery
from google.ads.googleads.errors import GoogleAdsException

from function_flow import futures
from function_flow import tasks
from function_flow import cloud_task_helper

import conversion_api

_OAUTH_SCOPE = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive'
]

installed_packages_list = sorted(
    ['%s==%s' % (i.key, i.version) for i in pkg_resources.working_set])
print(installed_packages_list)
logging.info('installed packages: %s', '\n'.join(installed_packages_list))
print('GCP project:', config.get_project())

main_job = tasks.Job(
    name='bare_metal_job', schedule_topic='SCHEDULE', max_parallel_tasks=3)

# The cloud function to schedule next tasks to run.
scheduler = main_job.make_scheduler()

# The cloud function triggered by external events(e.g. finished bigquery jobs)
external_event_listener = main_job.make_external_event_listener()

pingback_tasks = cloud_task_helper.CloudTaskHelper(
    event_topic='SCHEDULE_EXTERNAL_EVENTS',
    queue_id_prefix='bare-metal-queue')

_COLUMNS = [
    'customer_id', 'conversion_action_id', 'gclid', 'gbraid', 'wbraid', 'conversion_date_time',
    'conversion_value', 'currency'
]


@main_job.task(task_id='pingback')
def pingback(task: tasks.Task, job: tasks.Job):
  """Splits the input file by batch_size, then send workloads to multiple workers."""
  args = job.get_arguments()
  bucket_name = args['bucket']
  input_path = args['processing_input']
  input_dir = args['processing_dir']
  src_dir = args['src']
  job_id = job.id

  storage_client = storage.Client()

  blob = storage.Blob(input_path, storage_client.get_bucket(bucket_name))

  events_per_worker = config.get_config('events_per_worker')

  # split job by batch size
  lines = []
  worker = 0
  headers = []
  with blob.open('rt') as f:
    csv_reader = csv.DictReader(f)
    for data in csv_reader:
      lines.append(','.join([data[col] for col in _COLUMNS]))

      if len(lines) == events_per_worker:
        worker_blob = storage.Blob(f'{input_dir}/worker-{worker}.csv',
                                   storage_client.get_bucket(bucket_name))
        worker_blob.upload_from_string('\n'.join(lines))
        lines = []
        worker += 1

  # last worker
  if lines:
    logging.info('last worker: %s lines', len(lines))
    worker_blob = storage.Blob(f'{input_dir}/worker-{worker}.csv',
                               storage_client.get_bucket(bucket_name))
    worker_blob.upload_from_string('\n'.join(lines))
    lines = []
    worker += 1

  logging.info('sending with %s workers', worker)

  def params_func(worker_id):
    return {
        'bucket': bucket_name,
        'job_id': job_id,
        'input_dir': input_dir,
        'input_path': f'{input_dir}/worker-{worker_id}.csv',
        'src': src_dir
    }

  max_concurrent_workers = config.get_config('max_concurrent_workers')
  pingback_tasks.start(
      num_workers=worker,
      params_func=params_func,
      max_concurrent_dispatches=max_concurrent_workers)
  return pingback_tasks.future()


@pingback_tasks.wraps
def pingback_worker(worker_id, params):
  """On worker sends one csv file of events."""
  logging.info('worker %s params %s', worker_id, params)
  storage_client = storage.Client()
  bucket = params['bucket']
  input_path = params['input_path']
  input_dir = params['input_dir']
  job_id = params['job_id']
  src_dir = params['src']
  input_blob = storage.Blob(input_path, storage_client.get_bucket(bucket))
  log_blob = storage.Blob(f'{input_dir}/worker-log-{worker_id}.json',
                          storage_client.get_bucket(bucket))
  log_error_blob = storage.Blob(f'{input_dir}/worker-errors-{worker_id}.txt',
                                storage_client.get_bucket(bucket))

  config_path = f'gs://{bucket}/config/google-ads.yaml'
  conversion_client = conversion_api.ConversionClient(config_path=config_path)

  events_per_batch = config.get_config('events_per_batch')

  def send_events(customer_id, conversion_action_ids, events, log, log_error):
    results = conversion_client.send_event(
        customer_id=customer_id, conversions=events)

    success_cnt = 0
    for e, c, r in zip(events, conversion_action_ids, results):
      if r['status'] == conversion_api._STATUS_SUCCESS:
        success_cnt += 1
      log.write(
          json.dumps({
              'customer_id': customer_id,
              'conversion_action_id': c,
              'gclid': e.gclid,
              'gbraid': e.gbraid,
              'wbraid': e.wbraid,
              'conversion_date_time': e.conversion_date_time,
              'currency': e.currency_code,
              'conversion_value': e.conversion_value,
              'status': r['status'],
              'code': r['code'],
              'message': r['message'],
              'job_id': job_id,
              'src': src_dir,
              'process_time': datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
          }) + '\n')
    return len(events), success_cnt

  with input_blob.open() as input_file, \
       log_blob.open('w') as log, \
       log_error_blob.open('w') as log_error :
    total_cnt = 0
    success_cnt = 0
    events = []
    conversion_action_ids = []
    
    csv_reader = csv.DictReader(input_file, fieldnames=_COLUMNS)
    for data in csv_reader:
      customer_id = data['customer_id']
      try:
        data['conversion_value'] = float(data['conversion_value'])
      except:
        data['conversion_value'] = 0.0

      event = conversion_client.build_event(**data)
      events.append(event)
      conversion_action_ids.append(data['conversion_action_id'])

      if len(events) == events_per_batch:
        t, s = send_events(customer_id, conversion_action_ids, events, log,
                           log_error)
        total_cnt += t
        success_cnt += s
        events = []
        conversion_action_ids = []

    if events:
      t, s = send_events(customer_id, conversion_action_ids, events, log,
                         log_error)
      total_cnt += t
      success_cnt += s
      events = []
      conversion_action_ids = []

  return {'total': total_cnt, 'success': success_cnt}


@main_job.task(task_id='load_logs_into_bq', deps=['pingback'])
def load_logs_into_bq(task: tasks.Task, job: tasks.Job):
  args = job.get_arguments()
  project = config.get_project()
  bucket_name = args['bucket']
  input_dir = args['processing_dir']
  gcs_path = f'gs://{bucket_name}/{input_dir}/worker-log-*.json'
  bq_table = f'{project}.bare_metal.send_event_log'
  utils.load_data_gcs_to_bq(
      gcs_path,
      bq_table,
      source_format=bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
      write_disposition=bigquery.WriteDisposition.WRITE_APPEND)
  return {'gcs': gcs_path, 'bq': bq_table}


def _start():
  logging.info('job started')
  project = config.get_project()
  bucket_name = config.get_bucket()
  storage_client = storage.Client()

  blobs = storage_client.list_blobs(
      bucket_name, prefix='input/', delimiter=None)

  input_blob = None
  for blob in blobs:
    if blob.name.endswith('.csv'):
      input_blob = blob
      break

  if not input_blob:
    return {'status': 'skipped', 'reason': 'no input file detected.'}

  with input_blob.open('rt') as f:
    for line in f:
      logging.info('input blob: %s first line: %s', input_blob.name, line)
      break

  time_str = datetime.datetime.now().strftime('%Y-%m-%d-%H-%M')
  directory = f'{time_str}'
  blob_copy = storage_client.bucket(bucket_name).copy_blob(
      input_blob, input_blob.bucket, f'processing/{directory}/data.csv')

  try:
    base_name = os.path.split(input_blob.name)[-1]
    storage_client.bucket(bucket_name).rename_blob(
        input_blob, f'history/{directory}/{base_name}')
  except:
    logging.exception(f'failed moving input data {input_blob.name}')
    return {'status': 'skipped', 'src': input_blob.name}

  args = {
      'bucket': bucket_name,
      'src': input_blob.name,
      'processing_dir': f'processing/{directory}',
      'processing_input': blob_copy.name
  }
  main_job.start(args)

  return dict(
      id=main_job.id,
      status=f'https://pantheon.corp.google.com/firestore/data/JobStatus/{main_job.id}?project={project}',
      **args)


def _send_notification_email():
  email = config.get_config('notification_email')
  project = config.get_project()

  date = (datetime.datetime.today()-datetime.timedelta(days=1)).strftime('%Y-%m-%d')

  if email:
    email_message = [f'Bare Metal Daily Summary {date}\n']

    bq_client = bigquery.Client(project=project)
    for field in ['status', 'code']:
      sql = f"""SELECT {field}, COUNT(*) as count
FROM `{project}.bare_metal.send_event_log`
WHERE DATE(process_time) =
DATE_SUB(current_date, INTERVAL 1 DAY)
GROUP BY {field}"""
      email_message.append(f'Count By {field}')
      for r in bq_client.query(sql):
        email_message.append(r[field] + f': {r["count"]}')
      email_message.append('\n')

    email_message.append(f'For details, please visit https://pantheon.corp.google.com/bigquery?project={project}')

    credentials, _ = google.auth.default(_OAUTH_SCOPE)
    if hasattr(credentials, 'service_account_email'):
      print('Using service account:', credentials.service_account_email)
      gc = gspread.authorize(credentials)
    else:
      print('Running locally using user account')
      gc = gspread.oauth()
    print('send to email', email)
    sh = gc.create(f'BareMetal Summary {date}')
    sh.sheet1.update([email_message])

    for e in email.split(','):
      sh.share(
          e,
          perm_type='user',
          email_message='\n'.join(email_message),
          role='writer',
          notify=True)
    print('Shared trix:', sh.url)
    return sh.url

  return 'Skipped_Empty_Email'


@utils.log_errors
@utils.jsonify
def start(request: 'flask.Request') -> str:
  """The workflow entry point."""
  tasks.cleanup_expired_jobs(max_expire_days=90, max_timeout_days=3)
  return _start()


@utils.log_errors
def send_single_event(request: 'flask.Request') -> str:
  """A test function to send a single conversion event."""
  request_json = request.get_json()
  for field in ['config_path', *_COLUMNS]:
    if field not in request_json:
      return f'Error: {field} not exist in request json.'
  config_path = request_json.pop('config_path')
  customer_id = request_json['customer_id']
  conversion_client = conversion_api.ConversionClient(config_path=config_path)
  event = conversion_client.build_event(**request_json)
  response = conversion_client.send_event(
      customer_id=customer_id, conversions=[event])
  return f'Response: {response}'


@utils.log_errors
@utils.jsonify
def cron(*unused_args) -> str:
  """Cron job."""
  tasks.cleanup_expired_jobs(max_expire_days=90, max_timeout_days=3)
  pingback_tasks.cleanup_expired_queues(max_expire_days=7)  
  return _start()


@utils.log_errors
def email_cron(*unused_args) -> str:
  """Cron job."""
  tzinfo = datetime.datetime.now().astimezone().tzinfo
  print('time zone:', tzinfo)
  return _send_notification_email()
