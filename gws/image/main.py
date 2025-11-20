import glob
import json
import logging
import os
import shlex
import subprocess
from datetime import datetime

import yaml
from scubagoggles.scuba_constants import API_SCOPES

from google.auth import default, iam
from google.auth.transport.requests import Request
from google.oauth2 import service_account
from google.cloud import storage

import google.cloud.logging
log_client = google.cloud.logging.Client()
log_client.setup_logging()

PROJECT_ID = os.environ.get('PROJECT')
OUTPUT_BUCKET = os.environ.get('OUTPUT_BUCKET')
RUN_TYPE = os.environ.get('RUN_TYPE')
INPUT_BUCKET = os.environ.get('INPUT_BUCKET')
OUTPUT_ALL_FILES = os.environ.get('OUTPUT_ALL_FILES', "false").lower() == "true"
SCUBA_GWS_ARGS = '--outputpath output/{} --config {} --accesstoken {} --quiet'


def get_token(impersonate: str) -> str:
    """
    Gets service account token for authorization. We have to create new credentials for this
    SA to be able to change the subject to match a user's email for access to the reports api. 
    See Google example: 
    https://github.com/GoogleCloudPlatform/professional-services/blob/main/examples/gce-to-adminsdk

    :param impersonate: user to impersonate for request calls
    :raises Exception: if the credentials are invalid after refresh
    :return: the valid token
    """
    credentials, _ = default()
    request = Request()

    # Refresh the default credentials. This ensures that the information
    # about this account, notably the email, is populated.
    credentials.refresh(request)

    # Create an IAM signer using the default credentials.
    signer = iam.Signer(request, credentials, credentials.service_account_email)

    # Create OAuth 2.0 Service Account credentials using the IAM-based
    # signer and the bootstrap_credential's service account email.
    updated_credentials = service_account.Credentials(
        signer,
        credentials.service_account_email,
        "https://accounts.google.com/o/oauth2/token",
        scopes=API_SCOPES,
        subject=impersonate,
    )
    updated_credentials.refresh(Request())

    if not updated_credentials.valid:
        raise Exception(f"Couldn't get valid credentials for {impersonate}")
    return updated_credentials.token


if __name__ == '__main__':
    logging.info(f"run type: {RUN_TYPE}")
    os.makedirs(f"input/{RUN_TYPE}", exist_ok=True)

    config_blobs = storage.Client().list_blobs(INPUT_BUCKET, prefix=RUN_TYPE)
    for config in config_blobs:
        if config.name.endswith("/"):
            continue  # skip directory itself
        config.download_to_filename(f"input/{config.name}")

    successes = 0
    config_files = glob.glob(f"input/{RUN_TYPE}/*")
    for config in config_files:
        try:
            org = os.path.splitext(os.path.basename(config))[0]
            logging.info(f"Running for: {org}")
            os.makedirs(f"output/{org}", exist_ok=True)
            with open(config, 'r') as f:
                contents = yaml.safe_load(f)
                if "subjectemail" not in contents:
                    logging.error(f"file {config} missing 'subjectemail' field")
                    continue
                subject_email = contents["subjectemail"]
            cmd = "scubagoggles gws " + SCUBA_GWS_ARGS.format(org, config, get_token(subject_email))
            result = subprocess.run(shlex.split(cmd), check=True, capture_output=True, text=True)
            if result.stderr is not None and len(result.stderr) > 0:
                logging.warning(f"(scubagoggles) {result.stderr}")
            results_file_path = glob.glob(f"output/{org}/*/ScubaResults*.json")[0]
            with open(results_file_path, 'r+') as results_file:
                results = json.load(results_file)
                results['MetaData']['RunType'] = RUN_TYPE
                results_file.seek(0)
                json.dump(results, results_file)

            logging.info(f"Finished for: {org}")
            successes += 1
        except Exception as e:
            logging.exception(f"Exception running for org {org}")
            if isinstance(e, subprocess.CalledProcessError):
                if e.stderr is not None and len(e.stderr) > 0:
                    logging.error(f"(scubagoggles) {e.stderr}")

    logging.info(f"Copying files to GCS bucket: {OUTPUT_BUCKET}")
    rel_paths = glob.glob('output/**', recursive=True)
    out_bucket = storage.Client().get_bucket(OUTPUT_BUCKET)
    transferred = 0
    today = datetime.today()
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
            logging.info(f"Uploaded {blob.id}")
            transferred += 1
    logging.info(f"Finished. Successes: {successes}/{len(config_files)}. Transferred {transferred} files.")
    log_client.close()
    if successes < len(config_files):
        exit(1)
