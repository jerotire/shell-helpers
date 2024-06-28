#!/bin/bash

function aws_auth() {

  local op_vault="Work"

  echo "AWS Authentication Function (1Password Integration)"
  echo "==================================================="

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

  local profile_name="$1"
  echo "Requested Profile: $profile_name"

  echo "Beginning pre-checks ..."

  # Check AWS CLI profile configuration
  echo "Looking up AWS CLI profile: $profile_name ..."
  local profile_parse
  profile_parse=$(aws configure list --profile "$profile_name" 2>&1)
  if [ $? -ne 0 ]; then
    echo "Error: Provided profile '$profile_name' is not configured for AWS CLI." >&2
    return 1
  fi
  echo "AWS CLI profile '$profile_name' found."

  # Check 1Password entry with aws_cli_profile label
  echo "Looking up 1Password entry where aws_cli_profile='$profile_name' ..."
  local op_item
  op_item=$(op item list --vault "$op_vault" --categories Login --format=json | op item get - --format=json | jq --arg profile "$profile_name" '
    select(.fields | any(.label == "aws_cli_profile" and .value == $profile))
  ')

  local op_item_count
  op_item_count=$(echo "$op_item" | jq -s length)

  if [ -z "$op_item" ] || [ "$op_item_count" -eq 0 ]; then
    echo "Error: No 1Password entry where aws_cli_profile='$profile_name' was found." >&2
    return 1
  fi
  if [ "$op_item_count" -gt 1 ]; then
    echo "Error: Expected ONE (not $op_item_count) 1Password entry where aws_cli_profile='$profile_name' was found." >&2
    return 1
  fi

  local op_id
  op_id=$(echo "$op_item" | jq -r '.id')
  echo "1Password item $op_id found."

  echo "Pre-checks completed."

  # Unset all existing AWS_* credential-related environment variables
  echo "Unsetting all existing AWS_* credential-related environment variables..."
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_MFA_EXPIRY AWS_SESSION_EXPIRY
  unset AWS_ROLE AWS_PROFILE AWS_ASSUMED_ACCESS_KEY_ID AWS_ASSUMED_SECRET_ACCESS_KEY AWS_ASSUMED_SESSION_TOKEN
  unset AWS_MFA_ACCESS_KEY_ID AWS_MFA_SECRET_ACCESS_KEY AWS_MFA_SESSION_TOKEN AWS_PREASSUME_ACCESS_KEY_ID
  unset AWS_PREASSUME_SECRET_ACCESS_KEY AWS_PREASSUME_SESSION_TOKEN AWS_ROLE_ARN

  # Set up environment variables for AWS_PROFILE
  echo "Setting up environment variables for AWS_PROFILE $profile_name ..."
  export AWS_PROFILE="$profile_name"

  # Check for valid AWS credentials
  echo "Checking for valid AWS credentials..."
  local caller_identity
  caller_identity=$(aws sts get-caller-identity --output text 2>&1)
  if [ $? -ne 0 ]; then
    echo "Error: Current AWS credential configuration is invalid." >&2
    echo "Details: $caller_identity" >&2
    return 1
  fi

  # Get MFA Serial
  echo "Retrieving MFA serial number..."
  local user_name
  user_name=$(echo "$caller_identity" | awk '{print $2}' | awk -F '/' '{print $2}')
  local mfa_serial
  mfa_serial=$(aws iam list-mfa-devices --user-name "$user_name" --query 'MFADevices[*].SerialNumber' --output text 2>&1)
  if [ $? -ne 0 ]; then
    echo "Failed to retrieve MFA serial number." >&2
    echo "Details: $mfa_serial" >&2
    return 1
  fi
  echo "MFA serial number retrieved."

  echo "Fetching OTP from 1Password for ID $op_id..."
  # Get OTP for AWS
  local token_code
  token_code=$(op item get "$op_id" --otp 2>&1)
  if [ $? -ne 0 ]; then
    echo "Failed to retrieve OTP from 1Password." >&2
    echo "Details: $token_code" >&2
    return 1
  fi
  echo "OTP retrieved."

  # Call STS to get the session credentials
  echo "Calling sts get-session-token with MFA token..."
  local session_tokens
  session_tokens=$(aws sts get-session-token --token-code "$token_code" --serial-number "$mfa_serial" --output text 2>&1)
  if [ $? -ne 0 ]; then
    echo "STS MFA Request Failed." >&2
    echo "Details: $session_tokens" >&2
    return 1
  fi
  echo "Session tokens retrieved."

  echo "Exporting environment credentials as given by STS..."

  # Set the environment credentials as given by STS
  export AWS_ACCESS_KEY_ID=$(echo "$session_tokens" | awk '{print $2}')
  export AWS_SECRET_ACCESS_KEY=$(echo "$session_tokens" | awk '{print $4}')
  export AWS_SESSION_TOKEN=$(echo "$session_tokens" | awk '{print $5}')
  export AWS_MFA_EXPIRY=$(echo "$session_tokens" | awk '{print $3}')

  if [[ -n "$AWS_ACCESS_KEY_ID" && -n "$AWS_SECRET_ACCESS_KEY" && -n "$AWS_SESSION_TOKEN" ]]; then
    echo "AWS authentication successful for profile '$profile_name'."
    echo "Token expires at: $AWS_MFA_EXPIRY"
    return 0
  else
    echo "AWS authentication NOT successful for profile '$profile_name'."
    return 1
  fi
}

# Example usage:
# aws_auth <profile_name>
