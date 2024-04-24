#!/bin/bash

function aws_auth() {

  local op_vault="Work"

  # Check if 1Password CLI is installed
  if ! command -v op &> /dev/null; then
    echo "Error: 1Password CLI is not installed." >&2
    return 1
  fi

  # Check if AWS CLI is installed
  if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed." >&2
    return 1
  fi

  # Check if jq is installed
  if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed." >&2
    return 1
  fi

  # Check if profile name is provided as an argument
  if [ -z "$1" ]; then
    echo "Usage: aws_auth <profile_name>"
    return 1
  fi

  echo "AWS Authentication Function (1Password Integration)"
  echo "==================================================="
  echo "Requested Profile: $1"

  echo "Beginning pre-checks ..."

  # Check AWS CLI profile configuration
  echo "Looking up AWS CLI profile: $1 ..."
  local profile_parse
  profile_parse=$(aws configure list --profile "$1")
  if [ $? -ne 0 ]; then
    echo " Error: Provided profile '$1' is not configured for AWS CLI." >&2
    return 1
  fi
  echo " AWS CLI profile '$1' found."

  # Check 1Password entry with aws_cli_profile label
  echo "Looking up 1Password entry where aws_cli_profile='$1' ..."
  local op_item
  op_item=$(op item list --vault $op_vault --categories Login --format=json | op item get - --format=json | jq --arg profile "$1" '
    select(.fields | any(.label == "aws_cli_profile" and .value == $profile))
  ')

  local op_item_count
  op_item_count=$(echo $op_item | jq -s | jq length)

  if [ -z "$op_item" ] || [ "$op_item_count" -eq 0 ]; then
    echo " Error: No 1Password entry where aws_cli_profile='$1' was found." >&2
    return 1
  fi
  if [ "$op_item_count" -gt 1 ]; then
    echo " Error: Expected ONE (not $op_item_count) 1Password entries where aws_cli_profile='$1' was found." >&2
    return 1
  fi

  local op_id
  op_id=$(echo "$op_item" | jq -r '.id')

  echo " 1Password item $op_id found."

  echo "Pre-checks completed."

  echo "Unsetting all existing AWS_* credential-related environment variables...";
  unset AWS_ACCESS_KEY_ID;
  unset AWS_SECRET_ACCESS_KEY;
  unset AWS_SESSION_TOKEN;
  unset AWS_MFA_EXPIRY;
  unset AWS_SESSION_EXPIRY;
  unset AWS_ROLE;
  unset AWS_PROFILE;
  unset AWS_ASSUMED_ACCESS_KEY_ID
  unset AWS_ASSUMED_SECRET_ACCESS_KEY
  unset AWS_ASSUMED_SESSION_TOKEN
  unset AWS_MFA_ACCESS_KEY_ID
  unset AWS_MFA_SECRET_ACCESS_KEY
  unset AWS_MFA_SESSION_TOKEN
  unset AWS_PREASSUME_ACCESS_KEY_ID
  unset AWS_PREASSUME_SECRET_ACCESS_KEY
  unset AWS_PREASSUME_SESSION_TOKEN
  unset AWS_ROLE_ARN

  if ! [ "${?}" -eq 0 ]; then
    return 1;
  fi;

  echo "Setting up environment variables for AWS_PROFILE $1 ..."
  AWS_PROFILE=$1
  export AWS_PROFILE

  declare -a session_tokens;

  # Check for valid AWS credentials
  local caller_identity=($(aws sts get-caller-identity --output text));
  if ! [ "${?}" -eq 0 ]; then
    echo "Error: current AWS credential configuration invalid." >&2;
    return 1;
  fi;

  # Check if currently using an STS token (i.e. MFA, role assumed, or some other funkiness)
  if [[ -n "${AWS_SESSION_TOKEN+x}" ]]; then
    echo "Error: already using an STS token, you probably don't want to do MFA authentication at this point - perhaps run aws_reset_creds to reset" >&2;
    return 1;
  fi;

  # save existing credentials, if present
  [[ -n "${AWS_ACCESS_KEY_ID+x}" ]] && export AWS_PREMFA_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
  [[ -n "${AWS_SECRET_ACCESS_KEY+x}" ]] && export AWS_PREMFA_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
  [[ -n "${AWS_SESSION_TOKEN+x}" ]] && export AWS_PREMFA_SESSION_TOKEN=${AWS_SESSION_TOKEN}

  # Get MFA Serial
  #
  # Assumes "iam list-mfa-devices" is permitted without MFA
  local mfa_serial="$(aws iam list-mfa-devices --user-name "`echo ${caller_identity[@]:1:1} | awk -F \/ '{print $2}'`"  --query 'MFADevices[*].SerialNumber' --output text)"
  if ! [ "${?}" -eq 0 ]; then
    echo "Failed to retrieve MFA serial number" >&2;
    return 1;
  fi;


  echo "Fetching OTP from 1Password for ID $op_id ..."
  # Get OTP for AWS OLCS Non Prod
  local token_code=$(op item get $op_id --otp)

  # Call STS to get the session credentials
  # Assumes "sts get-session-token" is permitted without MFA
  echo "Calling sts get-session-token with MFA token ..."
  local session_tokens=($(aws sts get-session-token --token-code "${token_code}" --serial-number "${mfa_serial}" --output text));
  if ! [ "${?}" -eq 0 ]; then
    echo "STS MFA Request Failed" >&2;
    return 1;
  fi;

  echo "Exporting environment credentials as given by STS ... "

  # Set the environment credentials as given by STS
  export AWS_ACCESS_KEY_ID="${session_tokens[@]:1:1}";
  export AWS_SECRET_ACCESS_KEY="${session_tokens[@]:3:1}";
  export AWS_SESSION_TOKEN="${session_tokens[@]:4:1}";

  export AWS_MFA_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}";
  export AWS_MFA_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}";
  export AWS_MFA_SESSION_TOKEN="${AWS_SESSION_TOKEN}";
  export AWS_MFA_EXPIRY="${session_tokens[@]:2:1}";

  if [[ -n "${AWS_ACCESS_KEY_ID}" && -n "${AWS_SECRET_ACCESS_KEY}" && -n "${AWS_SESSION_TOKEN}" ]]; then
    echo "AWS authentication successful for profile '$1'."
    echo " Token expires at: ${AWS_MFA_EXPIRY}"
    return 0;
  else
    echo "AWS authentication NOT successful for profile '$1'."
    return 1;
  fi;
}
