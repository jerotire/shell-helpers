# AWS Auth with 1Password MFA Support - Script

This script is a simple bash script that allows you to authenticate with AWS CLI using 1Password MFA support.

Upon running the script, it will search for the 1Password item with the specified profile name and use the MFA token to authenticate with AWS CLI.

The script will then set the AWS CLI environment variables for the specified profile returned from STS (Simple Token Service) and print the expiration time of the token.

## Setup

### Shell Setup

You must source the `source.sh` script in your shell to use the `aws_auth` function. You can do this by running the following command:

```bash
source source.sh
```

This will make the `aws_auth` function available in your shell.

You can put this in your `~/.bashrc` or `~/.zshrc` file to make it available every time you open a new shell.

### 1Password Setup

You must install the 1Password CLI tool to use this script. You can find more information about the 1Password CLI tool [here](https://support.1password.com/command-line/).

You must also have a 1Password account and have the 1Password CLI tool configured with your account. You can find more information about configuring the 1Password CLI tool [here](https://support.1password.com/command-line-getting-started/).

By default, the script will use the category "Logins" and the vault "Work" to search for the MFA token. You can change the value for vault in the `source.sh` script.

Your 1Password item (for AWS Login [containing username/password/mfa/url/etc]) must have the additional following field:

- `aws_cli_profile`: The AWS CLI profile you want to authenticate with. (this must match the profile name in your `~/.aws/config` file)

In the instance where the query does not return a exactly ONE item, the script will return an error message and exit.

## Usage

When sourced you can use the `aws_auth` function to authenticate with AWS CLI using 1Password MFA support; like so:

```bash
aws_auth {profile}
``` 

Where `{profile}` is the AWS CLI profile you want to authenticate with.

## Requirements

The `source.sh` script is a shell script, so it should be run in a Unix-like environment.

The script requires the following tools to be installed:

- [1Password CLI](https://support.1password.com/command-line/)
- [AWS CLI](https://aws.amazon.com/cli/)
- [jq](https://stedolan.github.io/jq/)

## Contributing

Contributions are welcome. Please make sure to update documentation as appropriate.

## License

The `source.sh` script is distributed under the MIT License. See `LICENSE` for more information.
