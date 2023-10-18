## Prelude:
- Most scripts display "usage" when called with the "-h" option. You can find out about some additional options specific to each script by running it with that option.

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

The **-backup** script can be used individually. By default, it is launched by the -run script to create a backup of the firewall state and the geoblocking ipsets before every action you apply to the firewall. If you encounter issues, you can use the -backup script with the 'restore' command to restore the firewall to its previous state. It also restores the previous config.

**The -install script**
- Checks pre-requisites.
- Creates system folder structure for scripts, config and data.
- Scripts are then copied to ```/usr/local/bin```. Config goes in ```/etc/geoblocker-bash```. Data goes in ```/var/lib/geoblocker-bash```.
- Creates backup of pre-install policies for INPUT and FORWARD chains.
- Calls geoblocker-bash-manage to set up geoblocker. The -manage script, in turn, calls the -run script, which calls -backup, -fetch and -apply scripts to perform the requested actions. (there is a reason for this chain of execution: each script has its own purpose)
- If an error occurs during the installation, it is propagated back through the execution chain and eventually the -install script calls the -uninstall script to revert any changes made to the system.
- Required arguments are ```-c <"country_codes">``` and ```-m <whitelist|blacklist>```
- Accepts optional custom cron schedule expression for autoupdates as an argument with the '-s' option. Default cron schedule is "0 4 * * *" - at 4:00 [am] every day. 'disable' instead of the schedule will disable autoupdate.
- Accepts the '-n' option to disable persistence (reboot cron job won't be created so after system reboot, there will be no more geoblocking - although if you have an autoupdate cron job then it will eventually kick in and re-activate geoblocking)
- Acepts the '-o' option to disable automatic backups of the firewall state, ipsets and config before an action is executed (actions include those launched by the cron jobs to implement autoupdate and persistence, as well as any action launched manually which requires making changes to the firewall)

**The -uninstall script**
- Doesn't require any arguments
- Deletes associated cron jobs
- Restores pre-install state of default policies for INPUT and FORWARD chains
- Deletes geoblocking iptables rules and removes the associated ipsets
- Deletes scripts' data folder /var/lib/geoblocker-bash
- Deletes the config from /etc/geoblocker-bash
- Deletes the scripts from /usr/local/bin

**The -manage script**: serves as the main user interface to configure geoblocking after installation. You can also call it by simply typing geoblocker-bash (as during installation, a symlink is created to allow that). As most scripts in this suite, you need to use it with 'sudo' because root privileges are required to access the firewall.

```geoblocker-bash <add|remove> [-c <country_code>]``` :
* Adds or removes the specified country codes to/from the config file
* Calls the -run script to fetch and apply the ip lists

```geoblocker-bash status```
* Displays information on the current state of geoblocking

```geoblocker-bash schedule -s <"schedule_expression">``` : enables automatic ip lists update and configures the schedule for the periodic cron job which implements this feature.

```geoblocker-bash schedule -s disable``` : disables ip lists autoupdate.

**The -run script**: Serves as a proxy to call the -fetch, -apply and -backup scripts with arguments required for each action. Executes the requested actions, depending on the config set by the -install and -manage scripts, and the command line options. If persistence or autoupdates are enabled, the cron jobs call this script with the necessary options.

```geoblocker-bash-run add -c <"country_codes">``` : Fetches iplists and loads ipsets and iptables rules for specified countries.

```geoblocker-bash-run remove -c <"country_codes">``` : Removes iplists, ipsets and iptables rules for specified countries.

```geoblocker-bash-run update``` : intended for triggering from periodic cron jobs. Updates the ipsets for all country codes that had been previously configured. Also used by the reboot cron job to implement persistence.

**The -fetch script**
- Fetches ipv4 subnets lists for given country codes from the regional internet registry (automatically selected based on the country).
- Parses, validates, compiles the downloaded lists, and saves each list to a separate file.
- Implements extensive sanity checks at each stage (fetching, parsing, validating and saving) and handles errors if they occur.
- If a "soft" error is encountered (mostly a temporary network error), retries the download again.

**The -apply script**:  directly interfaces with the firewall. Creates or removes ipsets and iptables rules for specified country codes.

```geoblocker-bash-apply add -c <"country_codes">``` :
- Loads ip list files for specified countries into ipsets and sets iptables rules to only allow connections from the local subnet and from subnets included in the ipsets.

```geoblocker-bash-apply remove -c <"country_codes">``` :
- removes ipsets and associated iptables rules for specified countries.

**The -cronsetup script** manages all the cron-related logic in one place. Called by the -manage script. Cron jobs are created based on the settings stored in the config file.

**The -backup script**: Creates a backup of the current iptables state, current geoblocking config and geoblocker-associated ipsets, or restores them from backup. By default (if you didn't run the installation with the '-o' option), backup will be created before every action you apply to the firewall and also before automatic list updates are applied. Normally backups should not take much space, maybe a few megabytes if you have many ip lists. The -backup script also compresses them, so they take even less space. (and automatically extracts when restoring)

```geoblocker-bash-backup create-backup``` : Creates a backup of the current iptables state, geoblocking config and geoblocker-associated ipsets.

```geoblocker-bash-backup restore``` : Can be manually used for recovery from fault conditions (unlikely that anybody will ever need this but implemented just in case).
- Restores ipsets, iptables state and geoblocking config from last known good backup.

**The -reset script** is called by the *install script to clean up previous geoblocking rules in the firewall and reset the config (just in case you install again without uninstalling first)

**The -common script** : Stores common functions and variables for the geoblocker-bash suite. Does nothing if called directly. Most other scripts won't work without it.

**The validate-cron-schedule.sh script** is used by the -cronsetup script. It accepts a cron schedule expression and attempts to make sure that it conforms to the crontab format.

**The check-ip-in-registry.sh script** can be used to verify that a certain ip address belongs to a subnet found in regional registry's records for a given country. It is intended for manual use and is not called from other scripts.

