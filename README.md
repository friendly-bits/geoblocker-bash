# geoblocker_bash
Automatic geoip blocker for Linux based on a whitelist for a specific country.

Suite of bash scripts with easy install and uninstall, focusing on reliability and fault tolerance. Fetches, parses and validates an ipv4 subnets whitelist for a given country, then blocks incoming traffic from anywhere except whitelisted subnets. Implements automatic update of the whitelist. Uses iptables.

ip/subnets list is fetched from RIPE - regional Internet registry for Europe, the Middle East and parts of Central Asia. RIPE appears to store ip lists for countries in other regions as well, although I did not check every country in the world.

Intended use case is a server that needs to be publically accessible in your country but does not need to be internationally accessible. For example, a server you run your CRM application on.

**TL;DR**

Recommended to read the NOTES section below.

To install:
1) Download the latest realease:
https://github.com/blunderful-scripts/geoblocker_bash/releases
2) Install prerequisites. On Debian and derivatives run: sudo apt install ipset jq wget
3) Download *all* scripts in this suite into the same folder
4) run "sudo bash geoblocker_bash-install -c [country_code]"
 
 To uninstall:
 run "sudo geoblocker_bash-uninstall"

**Detailed description**

The suite includes 6 scripts:
1. geoblocker_bash-install
2. geoblocker_bash-uninstall
3. geoblocker_bash-run
4. geoblocker_bash-fetch
5. geoblocker_bash-apply
6. validate_cron_schedule.sh

**The install script**:
- Checks prerequisites
- Creates system folder to store data in /var/lib/geoblocker_bash. Data consists of fetched subnet lists from RIPE, a file storing pre-install iptables policies for the INPUT and FORWARD chains (for backup), and a file storing last known-good ipset and iptables config (for backup and fault recovery).
- Copies all scripts included in this suite to /usr/local/bin
- Creates backup of pre-install policies for INPUT and FORWARD chains
- Calls geoblocker_bash-run to immediately fetch and apply new firewall config.
- Verifies that crond service is enabled. Enables it if not.
- Validates optionally user-specified cron schedule expression (if not specified then uses default schedule "0 4 * * *" (at 4:00 [am] every day).
- Creates periodic cron task based on that schedule and a reboot task. Both cron tasks call the geoblocker_bash-run script with the necessary arguments.
- If an error occurs at any point during installation, calls the uninstall script to revert any changes made to the system.

**The uninstall script**:
- Deletes associated cron jobs
- Restores pre-install state of default policies for INPUT and FORWARD chains
- Deletes associated iptables rules and removes the whitelist ipset
- Deletes scripts' data folder /var/lib/geoblocker_bash
- Deletes the scripts from /usr/local/bin

**The run script** simply calls the fetch script, then calls the apply script, passing required arguments. Used for easier triggering from cron jobs.

**The fetch script** is based on a prior script by @mivk, called get-ripe-ips, located here:
https://github.com/mivk/ip-country/blob/master/get-ripe-ips

- Fetches ipv4 subnets for a given country from RIPE
- Parses, validates and compiles the downloaded (JSON formatted) list into a plain list, and saves that to a file
- Attempts to determine the local ipv4 subnet for the main network interface and appends it to the file

**The apply script**:
- Creates or updates an ipset from a user-specified whitelist file (which should contain a plain ipv4 subnets list)
- Creates iptables rule that allows connection from subnets included in the ipset
- Sets default policy on INPUT and FORWARD iptables chains to DROP
- Saves a backup of the current (known-good) iptables state and the current ipset
- In case of an error, attempts to restore last known-good state from the backup
- If that fails, the script assumes that something is broken and calls the uninstall script which will attempt to remove any rules we have set, delete the associated cron jobs and restore policies for INPUT and FORWARD chains to the pre-install state

**The validate_cron_schedule script** is used by the install script. It accepts cron schedule expression and attempts to make sure that it complies with the format that cron expects. Used to validate optionally user-specified cron schedule expressions.

**Prerequisites**:
- Linux running systemd (tested on Debian, should work on any Debian derivative, may or may not work on other distributions)
- Root access
- iptables (default firewall management utility on most linux distributions)
- standard linux utilities including awk, sed, grep
- either curl or wget
- ipset utility (install it with 'apt install ipset' or similar)
- jq - Json processor (install it with 'apt install jq' or similar)

**NOTES**:

- Since these scripts are intended to be used on servers (including on my own server), much effort has gone into ensuring reliability and error handling. Yet, I can not guarantee that they will work as intended (or at all...) in your environment. You should test by yourself.

- If accessing your server remotely, make sure that you do not lock yourself out by using this script! Meaning, before running the install script verify that your ipv4 subnet is indeed included in the list that the script receives from RIPE. You can do that by running the "fetch" script separately and then simply checking inside the output file. (the "fetch" script on its own doesn't make any changes to the firewall)

- Changes applied to iptables are made persistent via cron jobs: a periodic job running at a daily schedule (which you can optionally change when running the install script), and a job which runs at system reboot (after 30 seconds delay).

- To test before deployment, you can run the install script with the "-n" switch to skip creating cron jobs. This way, a simple server restart will undo all changes made to the firewall. To enable persistence later, simply uninstall with "bash geoblocker_bash-uninstall" and install again without the "-n" switch.

- Most scripts accept the -d switch for debug (in case troubleshooting is needed).
- The "apply" script also accepts the -t switch to simulate a fault and to test recovery. To use it, you will need to install the suite first and then call the "apply" script manually with the correct parameters.

- The run, fetch and apply scripts write to syslog in case an error occurs. The run script also writes a syslog line upon success.

- **Note** that the install script creates cron jobs that **will be run as root**. Make appropriate security arrangements to prevent it from getting modified by unauthorized third parties.

- I will be interested to hear your feedback, for example whether it works or doesn't work on your system (please specify which), or if you find a bug, or would like to suggest code improvements. You can use the "Discussions" or "Issues" tab for that.
