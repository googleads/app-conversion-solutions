"""Utils."""
import functools
import logging
import time
import traceback
import json
from google.cloud import bigquery
import google.api_core.exceptions


def log_errors(func):
  """Helper to wrap and print exceptions, work around cloud funtion bug.

  https://issuetracker.google.com/155215191
  """

  @functools.wraps(func)
  def wrapper(*args, **kwargs):
    try:
      result = func(*args, **kwargs)
      return result
    except:
      logging.exception('Error encountered in %s', func)
      err_msg = traceback.format_exc()
      return f'Error encountered in {func}:\n{err_msg}\ncheck cloud function logs for details.'

  return wrapper


def jsonify(func):

  def wrapper(*args, **kwargs):
    start_time = time.time()
    result = func(*args, **kwargs)
    time_spent = time.time() - start_time
    result['time_spent'] = time_spent
    return json.dumps(result)

  return wrapper


def load_data_gcs_to_bq(
    gcs_path,
    bq_table,
    source_format=bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
    write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE):
  client = bigquery.Client()

  # bq_table is `project.dataset.table`, remove the table part to get dataset id.
  dataset_id = '.'.join(bq_table.split('.')[:-1])
  dataset = bigquery.Dataset(dataset_id)
  try:
    dataset = client.create_dataset(dataset)  # Make an API request.
    logging.info('Created dataset %s', dataset_id)
  except google.api_core.exceptions.Conflict:
    # ignore if already exists
    logging.info('dataset already exists %s', dataset_id)

  job_config = bigquery.LoadJobConfig(
      autodetect=True,
      source_format=source_format,
      write_disposition=write_disposition,
  )
  job = client.load_table_from_uri(gcs_path, bq_table, job_config=job_config)
  logging.info('Loading result from {gcs_path} to {bq_table}')
  job.result()  # Waits for the job to complete.
