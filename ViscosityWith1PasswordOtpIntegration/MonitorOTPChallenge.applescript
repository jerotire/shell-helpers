-- Set a variable to check if OTP was entered
set otpEntered to false
set maxAttempts to 10 -- Maximum number of attempts to check for the OTP prompt
set attemptCount to 0 -- Initialize attempt counter

-- Keep trying until the OTP is entered or max attempts reached
repeat until otpEntered or attemptCount ? maxAttempts
	-- Check if Viscosity's OTP prompt is active
	tell application "System Events"
		if (exists window "Viscosity - --VPN CONNECTION NAME--" of process "Viscosity") then
			-- Fetch the OTP from 1Password
			set OTP to do shell script "/usr/local/bin/op item get --1PASSWORD ITEM UUID-- --otp"
			
			-- Bring Viscosity to the front
			tell application "Viscosity" to activate
			
			delay 0.5 -- Small delay to ensure the prompt is focused
			
			-- Type the OTP into the prompt and press Enter
			keystroke OTP
			key code 36 -- Press Enter
			
			-- Mark OTP as entered to exit the loop
			set otpEntered to true
		end if
	end tell
	
	-- Increment the attempt counter
	set attemptCount to attemptCount + 1
	
	-- Delay before checking again (adjust if needed)
	delay 1
end repeat

-- If max attempts reached without entering OTP, you may want to log a message or handle the situation
if not otpEntered then
	display dialog "Maximum attempts reached. OTP prompt was not detected." buttons {"OK"} default button "OK"
end if
