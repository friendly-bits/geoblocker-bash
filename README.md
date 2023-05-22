# geoblocker_bash
Automatic geoip blocker for Linux based on a whitelist for a specific country.

Fetches, parses and validates an ipv4 subnets whitelist for a given country, then blocks incoming traffic from anywhere except whitelisted subnets. Uses iptables. Collection of bash scripts with easy install and uninstall.

Subnets list is fetched from RIPE - regional Internet registry for Europe, the Middle East and parts of Central Asia.

Intended use case is a server that needs to be publically accessible in your country but does not need to be internationally accessible. For example, a server you run your CRM application on.

**TL;DR**

Recommended to read the NOTES section below before deployment in a production environment.

To install:
1) Install prerequisites. On Debian and derivatives run: sudo apt install ipset jq wget
2) Download *all* scripts in this collection into the same folder
3) run "sudo bash geoblocker_bash-install -c [country_code]"
 
 To uninstall:
 run "sudo geoblocker_bash-uninstall"

**Detailed description**

The collection includes 6 scripts:
1. geoblocker_bash-install
2. geoblocker_bash-uninstall
3. geoblocker_bash-run
4. geoblocker_bash-fetch
5. geoblocker_bash-apply
6. validate_cron_schedule.sh

**The install script**:
- Checks for prerequisites
- Copies the scripts (including itself) into /usr/local/bin
- Creates system folder for scripts' data in /var/lib/geoblocker_bash. Data consists of a file storing pre-install iptables policies for the INPUT and FORWARD chains (for backup), and fetched subnet lists from RIPE.
- Calls geoblocker_bash-run that, in turn, calls geoblocker_bash-fetch and geoblocker_bash-apply to immediately fetch and apply new firewall config.
- Verifies that crond service is enabled. Enables it if not.
- Calls validate_cron_schedule.sh to verify optionally user-specified cron schedule expression (if not specified then uses default schedule "0 4 * * *" (at 4:00 [am] every day).
- Creates periodic cron task based on that and a reboot task. Both cron tasks call the geoblocker_bash-run script with the necessary arguments.

**The uninstall script**:
- Removes associated iptables rules
- Removes the associated ipset
- Restores pre-install iptables policies for INPUT and FORWARD chains from backup
- Deletes scripts' data folder /var/lib/geoblocker_bash
- Deletes the scripts from /usr/local/bin

**The run script** simply calls the fetch script, then calls the apply script, passing required arguments.

**The fetch script** is based on a prior script by @mivk, called get-ripe-ips, located here:
https://github.com/mivk/ip-country/blob/master/get-ripe-ips
So it's basically a fork.
It can be used separately from this collection, as it does its own pre-requisite checks and input validation and accepts arguments.
- Fetches ipv4 subnets from RIPE for a given country, validates them and compiles them into a list
- Attempts to determine local ipv4 subnet for the main network interface and adds that to the end of the list
- Writes the resulting list to a plaintext file

**The apply script**:
- Creates or updates a named ipset from a user-specified file (which should contain a plain ipv4 subnets list).
- Sets default policy on INPUT and FORWARD iptables chains to DROP
- Then creates iptables rules that allow connection from subnets included in the ipset.

It also can be used separately from this collection, as it does its own pre-requisite checks and input validation and accepts arguments.

**The validate_cron_schedule script** is used by the install script. It accepts cron schedule expression and attempts to make sure that it complies with the format that cron expects.

**Prerequisites**:
- Linux running systemd (tested on Debian, should work on any Debian derivative, may or may not work on other distributions)
- Root access
- iptables (default firewall on most linux distributions)
- standard linux tools including awk, sed, grep
- either curl or wget
- ipset (install it with 'apt install ipset' or similar)
- jq - Json processor (install it with 'apt install jq' or similar)
- RIPE having lists for your country (if not, you may need to fetch from elsewhere and modify the scripts accordingly)

**NOTES**:

- Since these scripts are intended to be used on servers (including on my own server), much effort has gone into ensuring reliability and error handling. Yet, I can not guarantee that they will work as intended (or at all...) in your environment. You should test by yourself.

- If accessing your server remotely, make sure that you do not lock yourself out by using this script! Meaning, verify that your ipv4 subnet is indeed included in the list that the script receives from RIPE. You can do that by running the "fetch" script separately and then simply checking inside the output file (by default, it should be found in /var/lib/geoblocker_bash/ip_lists/).

- Changes applied to iptables are made persistent via cron jobs: a periodic job running at a daily schedule (which you can optionally change when running the install script), and a job which runs at system reboot (after 30 seconds delay).

- To test before deployment, you can install with the "-n" switch to avoid creating cron jobs. This way, a simple server restart will undo all changes made to the firewall. To enable persistence later, simply uninstall with "bash geoblocker_bash-uninstall" and install again without the "-n" switch.

- Most scripts accept the -d switch for debug (in case troubleshooting is needed).

- The run, fetch and apply scripts write to syslog in case critical errors occur. The run script also writes a syslog line upon success.

- **Note** that the install script creates cron jobs that **will be run as root**. Make appropriate security arrangements to prevent it from getting modified by unauthorized third parties.

- I will be interested to hear your feedback, for example whether it works or doesn't work on your system (please specify which), or if you find a bug, or would like to suggest code improvements. You can use the "Discussions" or "Issues" tab for that.
