## **In detail**
The suite currently includes 12 scripts:
1. geoblocker-bash-install
2. geoblocker-bash-uninstall
3. geoblocker-bash-manage
4. geoblocker-bash-run
5. geoblocker-bash-fetch
6. geoblocker-bash-apply
7. geoblocker-bash-cronsetup
8. geoblocker-bash-backup
9. geoblocker-bash-common
10. geoblocker-bash-reset
11. validate-cron-schedule.sh
12. check-ip-in-registry.sh

The scripts intended as user interface are **-install**, **-uninstall**, **-manage** and **check-ip-in-registry.sh**. All the other scripts are intended as a back-end, although they can be run by the user as well (I don't recommend that). If you just want to install and move on, you only need to run the -install script, specify mode with the -m option and specify country codes with the "-c" option. Provided you are not missing any pre-requisites, it should be as easy as that.
After installation, the user interface is provided by simply running "geoblocker-bash", which is a symlink to the -manage script.

**The -install script**
- Creates system folder structure for scripts, config and data.
- Copies all scripts included in this suite to /usr/local/bin
- Creates backup of pre-install policies for INPUT and FORWARD chains
- Calls geoblocker-bash-manage to set up geoblocker and then call the -fetch and -apply scripts.
- If an error occurs during the installation, calls the uninstall script to revert any changes made to the system.
- Accepts optional custom cron schedule expression for autoupdates as an argument with the '-s' option. Default cron schedule is "0 4 * * *" - at 4:00 [am] every day. 'disable' instead of the schedule will disable autoupdate.
- Accepts the '-n' option to disable persistence (reboot cron job won't be created so after system reboot, there will be no more geoblocking - although if you have an autoupdate cron job then it will eventually kick in and re-activate geoblocking)

**The -uninstall script**
- Doesn't require any arguments
- Deletes associated cron jobs
- Restores pre-install state of default policies for INPUT and FORWARD chains
- Deletes geoblocking iptables rules and removes the associated ipsets
- Deletes scripts' data folder /var/lib/geoblocker-bash
- Deletes the scripts from /usr/local/bin

**The -manage script**: serves as the main user interface to configure geoblocking after installation. You can also call it by simply typing geoblocker-bash (as during installation, a symlink is created to allow that). As most scripts in this suite, you need to use it with 'sudo' because root privileges are required to access the firewall.

```geoblocker-bash <add|remove> [-c <country_code>]``` :
* Adds or removes the specified country codes to/from the config file
* Calls the -run script to fetch and apply the ip lists
* After successful firewall config changes, calls the -backup script to create a backup of current config, ipsets and iptables state.

```geoblocker-bash status```
* Displays information on the current state of geoblocking

```geoblocker-bash-manage schedule -s <"schedule_expression">``` : enables automatic ip lists update and configures the schedule for the periodic cron job which implements this feature.

```geoblocker-bash-manage schedule -s disable``` : disables ip lists autoupdate.

**The -run script**: Serves as a proxy to call the -fetch, -apply and -backup scripts with arguments required for each action.

```geoblocker-bash-run add -c <"country_codes">``` : Fetches iplists and loads ipsets and iptables rules for specified countries.

```geoblocker-bash-run remove -c <"country_codes">``` : Removes iplists, ipsets and iptables rules for specified countries.

```geoblocker-bash-run update``` : intended for triggering from periodic cron jobs. Updates the ipsets for all country codes that had been previously configured. Also used by the reboot cron job to implement persistence.

**The -fetch script**
- Fetches ipv4 subnets lists for given country codes from the regional internet registry (automatically selected based on the country).
- Parses, validates, compiles the downloaded lists, and saves each list to a separate file.
- Implements extensive sanity checks at each stage (fetching, parsing, validating and saving) and handles errors if they occur.
- If a "soft" error is encountered (mostly a temporary network error), retries the download up to 3 times.

**The -apply script**:  directly interfaces with the firewall. Creates or removes ipsets and iptables rules for specified country codes.

```geoblocker-bash-apply add -c <"country_codes">``` :
- Loads an ip list file for specified countries into ipsets and sets iptables rules to only allow connections from the local subnet and from subnets included in the ipsets.

```geoblocker-bash-apply remove -c <"country_codes">``` :
- removes ipsets and associated iptables rules for specified countries.

**The -cronsetup script** manages all the cron-related logic in one place. Called by the -manage script. Cron jobs are created based on the settings stored in the config file.

**The -backup script**: Creates a backup of the current iptables state and geoblocker-associated ipsets, or restores them from backup.

```geoblocker-bash-backup create-backup``` : Creates a backup of the current iptables state and geoblocker-associated ipsets.

```geoblocker-bash-backup restore``` : Used for automatic recovery from fault conditions (should not happen but implemented just in case)
- Restores ipsets and iptables state from last known good backup
- If restore from backup fails, either gives up (default behavior) or (if you ran the -install script with the -e option for Emergency Deactivation) deactivates geoblocking entirely

**The -reset script** is called by the *install script to clean up previous geoblocking rules in the firewall and reset the config (just in case you install again without uninstalling first)

**The -common script** : Stores common functions and variables for the geoblocker-bash suite. Does nothing if called directly. Most other scripts won't work without it.

**The validate-cron-schedule.sh script** is used by the -cronsetup script. It accepts a cron schedule expression and attempts to make sure that it conforms to the crontab format.

**The check-ip-in-registry.sh script** can be used to verify that a certain ip address belongs to a subnet found in regional registry's records for a given country. It is intended for manual use and is not called from other scripts.
