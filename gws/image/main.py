import glob
import json
import logging
import os
import shlex
import subprocess
from datetime import datetime

from scubagoggles import __version__ as goggles_version

from google.cloud import storage
import google.cloud.logging

PROJECT_ID = os.environ.get('PROJECT')
OUTPUT_BUCKETS = json.loads(os.environ.get('OUTPUT_BUCKETS', '[]'))
RUN_TYPE = os.environ.get('RUN_TYPE')
INPUT_BUCKET = os.environ.get('INPUT_BUCKET')
OUTPUT_ALL_FILES = os.environ.get('OUTPUT_ALL_FILES', "false").lower() == "true"
SCUBA_GWS_ARGS = '--outputpath output/{} --config {} --usemetadataserverauth --quiet'

log_client = google.cloud.logging.Client()
log_client.setup_logging()

if __name__ == '__main__':
    logging.info(f"ScubaGoggles v{goggles_version}")
    logging.info(f"run type: {RUN_TYPE}")

    if not OUTPUT_BUCKETS or len(OUTPUT_BUCKETS) == 0:
        logging.error("No output buckets configured!")
        exit(1)

    os.makedirs(f"input/{RUN_TYPE}", exist_ok=True)
    logging.info(f"Reading files from: {INPUT_BUCKET}/{RUN_TYPE}")
    config_blobs = storage.Client().list_blobs(INPUT_BUCKET, prefix=RUN_TYPE)
    for config in config_blobs:
        if config.name.endswith("/"):
            continue  # skip directory itself
        config.download_to_filename(f"input/{config.name}")

    run_successes = 0
    config_files = glob.glob(f"input/{RUN_TYPE}/*")
    for config in config_files:
        org = ""
        try:
            org = os.path.splitext(os.path.basename(config))[0]
            logging.info(f"Running for: {org}")
            os.makedirs(f"output/{org}", exist_ok=True)
            
            cmd = "scubagoggles gws " + SCUBA_GWS_ARGS.format(org, config)
            result = subprocess.run(shlex.split(cmd), check=True, capture_output=True, text=True)
            if result.stderr is not None and len(result.stderr) > 0:
                logging.warning(f"(scubagoggles) {result.stderr}")
            logging.info(f"(scubagoggles stdout) {result.stdout}")
            results_file_path = glob.glob(f"output/{org}/*/ScubaResults*.json")[0]
            with open(results_file_path, 'r+') as results_file:
                results = json.load(results_file)
                results['MetaData']['RunType'] = RUN_TYPE
                results_file.seek(0)
                results_file.truncate()
                json.dump(results, results_file)

            logging.info(f"Finished for: {org}")
            run_successes += 1
        except Exception as e:
            logging.exception(f"Exception running for org {org}")
            if isinstance(e, subprocess.CalledProcessError):
                if e.stderr is not None and len(e.stderr) > 0:
                    logging.error(f"(scubagoggles) {e.stderr}")

    logging.info(f"Copying files to {len(OUTPUT_BUCKETS)} GCS bucket(s)")
    rel_paths = glob.glob('output/**', recursive=True)
    storage_client = storage.Client()
    today = datetime.today()
    upload_failures = []

    for bucket_name in OUTPUT_BUCKETS:
        try:
            logging.info(f"Uploading to bucket: {bucket_name}")
            out_bucket = storage_client.get_bucket(bucket_name)
            transferred = 0
            
            for local_file in rel_paths:
                if os.path.isfile(local_file) and (OUTPUT_ALL_FILES or ("ScubaResults" in local_file)):
                    file_parts = local_file.split("/")
                    date_str = today.strftime('%Y/%m/%d/')
                    if OUTPUT_ALL_FILES:
                        seconds_since_midnight = (today - today.replace(hour=0, minute=0, second=0, microsecond=0)).seconds  
                        dir_str = f'{file_parts[1]}_{seconds_since_midnight}/'
                        file_str = '/'.join(file_parts[2:])
                    else:
                        dir_str = ""
                        file_str = file_parts[-1]
                    blob = out_bucket.blob(f"{date_str}{dir_str}{file_str}")
                    blob.upload_from_filename(local_file)
                    logging.info(f"Uploaded: {blob.id}")
                    transferred += 1
            
            logging.info(f"Successfully uploaded {transferred} files to {bucket_name}")
        except Exception as e:
            logging.error(f"Failed to upload to bucket {bucket_name}: {e}")
            upload_failures.append(bucket_name)

    if upload_failures:
        logging.error(f"Failed to upload to {len(upload_failures)} of {len(OUTPUT_BUCKETS)} bucket(s): {', '.join(upload_failures)}")

    if run_successes < len(config_files):
        logging.error(f"ScubaGoggles failed for {len(config_files) - run_successes} of {len(config_files)} organization(s)")

    logging.info(f"Finished. Successes: {run_successes}/{len(config_files)}.")
    log_client.close()

    if len(upload_failures) > 0 or run_successes < len(config_files):
        exit(1)
