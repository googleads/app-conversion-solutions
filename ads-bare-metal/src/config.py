from google.cloud import firestore
import google.auth
import os


_CONFIG_COLLECTION = 'Config'
_MAIN_SECTION = 'main'


def get(key, default=None):
  db = firestore.Client()
  c = db.collection(_CONFIG_COLLECTION)
  return c.document(key).get().to_dict() or default


def get_config(key, section=_MAIN_SECTION, default=None):
  return get(section, {}).get(key, default)


def get_project():
  _, project = google.auth.default()
  return project


def init_config(bucket_name):
  print('using bucket:', bucket_name)

  db = firestore.Client()
  c = db.collection(_CONFIG_COLLECTION)
  main_config = c.document('main')
  main_config.set({
    'bucket': bucket_name,
    'max_concurrent_workers': 3,
    'events_per_worker': 20000,
    'events_per_batch': 500,
    'notification_email': ''
  })

  
def get_bucket():
  return get_config('bucket')


if __name__ == '__main__':
  init_config(bucket_name=os.environ['BUCKET_NAME'])