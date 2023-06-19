# geoblocker_bash
Automatic geoip blocker for Linux based on a whitelist for a country or multiple countries.

Fetches, parses and validates an ipv4 whitelist for given countries, then blocks incoming traffic from anywhere except whitelisted subnets. Implements automatic update of the whitelist. Implements fault detection and recovery. Uses iptables.

The ip list is fetched from RIPE - regional Internet registry for Europe, the Middle East and parts of Central Asia. RIPE appears to store ip lists for countries in other regions as well, so currently this can be used for any country in the world.

Intended use case is a server/computer that needs to be publically accessible only in a certain country or countries.

**TL;DR**

Recommended to read the NOTES section below.

**To install:**
1) Install prerequisites. On Debian and derivatives run: sudo apt install ipset jq wget grepcidr
2) Download the latest realease:
https://github.com/blunderful-scripts/geoblocker_bash/releases
3) Put *all* scripts in this suite into the same folder
4) Use the check_ip_in_ripe script to make sure that your public ip address is included in the list fetched from RIPE, so you do not get locked out of your server.
- example: _'bash check_ip_in_ripe.sh -c DE -i <your_public_ip_address>' (for Germany)_
5) Once verified that your public ip address is included in the list, run 'sudo bash geoblocker_bash-install -c "<country_code> [country_code] ... [country_code]"'
- example: _'sudo bash geoblocker_bash-install -c DE' (for Germany)_
- example: _'sudo bash geoblocker_bash-install -c "DE NL"' (for Germany and Netherlands)_
 (when specifying multiple countries, put the list in double quotes)
 
**To manage:**
- run 'sudo geoblocker_bash-manage -a <add|remove|schedule> [-c "country_code country_code ... country_code"]'
- example (to add whitelists for Germany and Netherlands): _'sudo geoblocker_bash-manage -a add -c "DE NL"'_
- example (to remove whitelist for Germany): _'sudo geoblocker_bash-manage -a remove -c DE'_
- example (to change periodic cron job schedule): _'sudo geoblocker_bash-manage -a schedule -s "1 4 * * *"_
 
**To uninstall:**
- run 'sudo geoblocker_bash-uninstall'

**Prerequisites**:
- Linux running systemd (tested on Debian and Mint, should work on any Debian derivative, may require modifications to work on other distributions)
- Root access
- iptables (default firewall management utility on most linux distributions)
- standard GNU utilities including awk, sed, grep, bc

additional mandatory prerequisites: to install, run 'sudo apt install ipset wget jq grepcidr'
- wget (or alternatively curl) is used by the "fetch" and "check_ip_in_ripe" scripts to download lists from RIPE
- ipset utility is a companion tool to iptables (used by the "apply" script to create an efficient iptables whitelist rule)
- jq - Json processor (used to parse lists downloaded from RIPE)
- grepcidr - filters ip addresses matching CIDR patterns (used by check_ip_in_ripe.sh to check if an ip address belongs to a subnet from a list of subnets)

**NOTES**

1) Changes applied to iptables are made persistent via cron jobs: a periodic job running at a daily schedule (which you can optionally change when running the install script), and a job that runs at system reboot (after 30 seconds delay).

2) You can specify a custom schedule for the periodic cron job by passing an argument to the install script. Run it with the '-h' option for more info.

3) **Note** that cron jobs **will be run as root**.

4) To test before deployment, you can run the install script with the "-n" option to apply all actions except actually blocking incoming connections (will NOT set INPUT chain policy to DROP). This way, you can make sure no errors are encountered, and check resulting iptables config before commiting to actual blocking. To enable blocking later, reinstall without the "-n" option.

5) To test before deployment, you can run the install script with the "-s disable" option to skip creating cron jobs. This way, a simple server restart will undo all changes made to the firewall. To enable persistence later, install again without the "-s disable" option or run 'geoblocker_bash-manage -a schedule -s <"your_cron_schedule">'.

6) The run, fetch and apply scripts write to syslog in case an error occurs. The run script also writes to syslog upon success. To verify that cron jobs ran successfully, on Debian and derivatives run 'sudo cat /var/log/syslog | grep geoblocker_bash'

7) I will appreciate a report of whether it works or doesn't work on your system (please specify which), or if you find a bug. If you have a suggestion for code improvement, please let me know as well. You can use the "Discussions" or "Issues" tab for that.

**Detailed description**

The suite currently includes 11 scripts:
1. geoblocker_bash-install
2. geoblocker_bash-uninstall
3. geoblocker_bash-fetch
4. geoblocker_bash-apply
5. geoblocker_bash-run
6. geoblocker_bash-manage
7. geoblocker_bash-cronsetup
8. geoblocker_bash-backup
9. geoblocker_bash-common
10. validate_cron_schedule.sh
11. check_ip_in_ripe.sh

The scripts intended as user-facing are the -install, -uninstall, -manage and check-ip-in-ripe scripts. All the otherscripts are there to support the user-facing scripts, although they can be run by the user as well.

**The -install script**
- Creates system folder structure for scripts, config and data.
- Copies all scripts included in this suite to /usr/local/bin
- Creates backup of pre-install policies for INPUT and FORWARD chains
- Calls geoblocker_bash-manage to set up geoblocker and then call the -fetch and -apply scripts.
- If an error occurs during the installation, calls the uninstall script to revert any changes made to the system.
- Accepts optional custom cron schedule expression as an argument. Default cron schedule is "0 4 * * *" - at 4:00 [am] every day.

**The -uninstall script**
- Deletes associated cron jobs
- Restores pre-install state of default policies for INPUT and FORWARD chains
- Deletes associated iptables rules and removes the whitelist ipset
- Deletes scripts' data folder /var/lib/geoblocker_bash
- Deletes the scripts from /usr/local/bin

**The -manage script**: provides an interface to configure geoblocking.

Supported actions: add, remove, schedule

'geoblocker_bash-manage -a add|remove -c <country_code>' :
* Adds or removes the specified country codes (tld's) to/from the config file
* Calls the -run script to fetch and apply the ip lists
* Calls the -backup script to create a backup of current config, ipsets and iptables state.

'geoblocker_bash-manage -a schedule -s <"schedule_expression">' : enables persistence and configures the schedule for the periodic cron job.

'geoblocker_bash-manage -a schedule -s disable' : disables persistence.

**The -run script**: Serves as a proxy to call the -fetch, -apply and -backup scripts with arguments required for each action.

'geoblocker_bash-run -a add -c <"country_codes">' : Fetches iplists and loads ipsets and iptables rules for specified countries.

'geoblocker_bash-run -a remove -c <"country_codes">' : Removes iplists, ipsets and iptables rules for specified countries.

 'geoblocker_bash-run -a update' : intended for triggering from periodic cron jobs. Updates the ipsets for all country codes that had been previously configured. Also used by the reboot cron job to implement persistence.

**The -fetch script**
- Fetches ipv4 subnets list for a given country code from RIPE.
- Parses, validates, compiles the downloaded list, and saves to a file.

**The -apply script**:  Creates or removes ipsets and iptables rules for specified country codes.

'geoblocker_bash-apply -a add -c <"country_codes">' :
- Loads an ip list file for specified countries into ipsets and sets iptables rules to only allow connections from the local subnet and from subnets included in the ipsets.

'geoblocker_bash-apply -a remove -c <"country_codes">' :
- removes ipsets and associated iptables rules for specified countries.

**The -backup script**: Creates a backup of the current iptables state and geoblocker-associated ipsets, or restores them from backup.

'geoblocker_bash-backup -a backup' : Creates a backup of the current iptables state and geoblocker-associated ipsets.

'geoblocker_bash-backup -a restore' : Used for automatic recovery from fault conditions (should not happen but implemented just in case)
- Restores ipsets and iptables state from backup
- If restore from backup fails, assumes a fundamental issue and disables geoblocking entirely

**The -common script:** : Stores common functions and variables for geoblocker_bash suite. Does nothing if called directly.

**The validate_cron_schedule.sh script** is used by the -manage script. It accepts cron schedule expression and attempts to make sure that it complies with the format that cron expects. Used to validate optionally user-specified cron schedule expression.

**The check_ip_in_ripe.sh script** can be used to verify that a certain ip address belongs to a subnet found in RIPE's records for a given country. It is not called from other scripts.

**Additional comments**
- All scripts (except -common) display "usage" when called with the "-h" option. You can find out about some additional options specific for each script by running it with the "-h" option.
- All scripts accept the "-d" option for debug
- The fetch script can be easily modified to get the lists from another source instead of RIPE, for example from ipdeny.com
- If you live in a small country, the fetched list may be shorter than 100 subnets. If that's the case, the fetch and check_ip_in_ripe scripts will assume that the download failed and refuse to work. You can change the value of the "min_subnets_num" variable in both scripts to work around that.
- If you remove your country's whitelist using the -manage script, you will probably get locked out of your remote server.
