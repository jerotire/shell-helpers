-- Path to the OTP monitoring AppleScript
set monitorScriptPath to POSIX path of "--PATH TO MonitorOTPChallenge.scpt--"

-- Run the OTP monitoring script in the background and disown it
do shell script "nohup osascript " & quoted form of monitorScriptPath & " > /dev/null 2>&1 &"

-- Exit so Viscosity can proceed with the VPN connection
return
