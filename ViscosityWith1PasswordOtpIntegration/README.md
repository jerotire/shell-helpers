# Viscosity with 1Password OTP Integration

This project provides AppleScripts to automate the OTP (One-Time Password) input for Viscosity VPN clients using 1Password. The scripts allow users to connect to their VPN while automatically providing the required OTP, streamlining the authentication process.

## Overview

- **BeforeConnect.applescript**: This script is executed before Viscosity attempts to connect to the VPN. It launches the OTP monitoring script in the background.
- **MonitorOTPChallenge.applescript**: This script monitors for the OTP prompt from Viscosity and automatically retrieves the OTP from 1Password, entering it into the prompt.

## Requirements

- **macOS**: The scripts are designed for macOS and rely on AppleScript.
- **Viscosity**: You must have the Viscosity VPN client installed.
- **1Password CLI**: Install the 1Password command-line tool to access your OTPs from 1Password.

## Setup

1. **Install 1Password CLI (if not already installed)**:
   Follow the instructions on the [1Password CLI](https://developer.1password.com/docs/cli/get-started) to install and configure it.

2. **Update the Scripts**:
   - Open `BeforeConnect.applescript` and replace `--PATH TO MonitorOTPChallenge.scpt--` with the full path to `MonitorOTPChallenge.applescript`.
   - Open `MonitorOTPChallenge.applescript` and replace `--VPN CONNECTION NAME--` with the exact name of your VPN connection as it appears in Viscosity.
   - Replace `--1PASSWORD ITEM UUID--` with the UUID of your 1Password item that contains your OTP.

3. **Configure Viscosity**:
   - Open Viscosity and go to the settings for your VPN connection.
   - In the **Advanced** settings, select `BeforeConnect.applescript` as the **Before Connect** script.

## Multiple VPN Connections

For every VPN connection, you need a BeforeConnect and MonitorOTPChallenge script. Prefixing or Suffixing the filename with VPN connection name/details should help.

## Usage

To connect to your VPN:

1. Open Viscosity and select your VPN connection.
2. Click **Connect**.
3. The script will automatically handle the OTP input when prompted.

## Safety Measures

The `MonitorOTPChallenge.applescript` includes a maximum of 10 attempts to enter the OTP. If the OTP prompt does not appear within these attempts, a dialog will notify the user.

## Contributing

Contributions are welcome! If you have improvements or suggestions, feel free to submit a pull request or open an issue.

## License

This project is open-source and available under the [MIT License](LICENSE).

## Acknowledgments

- [1Password](https://1password.com/) for providing a secure way to manage passwords and OTPs.
- [Viscosity](https://www.sparklabs.com/viscosity/) for their excellent VPN client for macOS.

