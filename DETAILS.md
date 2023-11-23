## **Prelude**
- This document mainly intends to give some info on the purspose and basic use cases of each script and how they work in tandem.
- Most scripts display "usage" when called with the "-h" option. You can find out about some additional options specific to each script by running it with that option.
- If you understand some shell code and would like to learn more about some of the scripts, you are most welcome to read the code. It has a lot of comments and I hope that it's fairly easily readable.

## **Overview**
The suite currently includes 13 scripts:
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
13. detect-local-subnets.sh

The scripts intended as user interface are **-install**, **-uninstall**, **-manage** and **check-ip-in-source.sh**. All the other scripts are intended as a back-end, although they can be run by the user as well (I don't recommend that). If you just want to install and move on, you only need to run the -install script, specify mode with the -m option and specify country codes with the "-c" option. Provided you are not missing any pre-requisites, it should be as easy as that.
After installation, the user interface is provided by simply running "geoblocker-bash", which is a symlink to the -manage script.

The **-backup** script can be used individually. By default, it is launched by the -run script to create a backup of the firewall state and the geoblocking ipsets before every action you apply to the firewall. If you encounter issues, you can use the -backup script with the 'restore' command to restore the firewall to its previous state. It also restores the previous config.

## **In detail**
**The -install script**
- Checks pre-requisites.
- Creates system folder structure for scripts, config and data.
- Scripts are then copied to ```/usr/local/bin```. Config goes in ```/etc/geoblocker-bash```. Data goes in ```/var/lib/geoblocker-bash```.
- Creates backup of pre-install policies for INPUT and FORWARD chains (the backup is used by the -uninstall script to restore the policies).
- Calls geoblocker-bash-manage to set up geoblocker. The -manage script, in turn, calls the -run script, which calls -backup, -fetch and -apply scripts to perform the requested actions.
- If an error occurs during the installation, it is propagated back through the execution chain and eventually the -install script calls the -uninstall script to revert any changes made to the system.
- Required arguments are ```-c <"country_codes">``` and ```-m <whitelist|blacklist>```
- Accepts optional custom cron schedule expression for autoupdate schedule with the '-s' option. Default cron schedule is "15 4 * * *" - at 4:15 [am] every day. 'disable' instead of the schedule will disable autoupdates.
- Accepts the '-u' option to specify source for fetching ip lists. Currently supports 'ripe' and 'ipdeny', defaults to ripe.
- Accepts the '-f' option to specify the ip protocol family (ipv4 or ipv6). Defaults to both.
- Accepts the '-n' option to disable persistence (reboot cron job won't be created so after system reboot, there will be no more geoblocking - although if you have an autoupdate cron job then it will eventually kick in and re-activate geoblocking)
- Accepts the '-o' option to disable automatic backups of the firewall state, ipsets and config before an action is executed (actions include those launched by the cron jobs to implement autoupdate and persistence, as well as any action launched manually and which requires making changes to the firewall)
- Accepts the '-p' option to skip setting the default firewall policies to DROP. This can be used if installing in the whitelist mode to check everything before commiting to actually blocking. Note that with this option, whitelist geoblocking will not be functional and to make it work, you'll need to re-install without it. This option does not affect the blacklist mode since in that mode, the default policies are not changed during installation.

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
* Calls the -run script to fetch and apply the ip lists for specified countries to the firewall (or to remove them)

```geoblocker-bash status```
* Displays information on the current state of geoblocking

```geoblocker-bash schedule -s <"schedule_expression">``` : enables automatic ip lists update and configures the schedule for the periodic cron job which implements this feature.

```geoblocker-bash schedule -s disable``` : disables ip lists autoupdate.

**The -run script**: Serves as a proxy to call the -fetch, -apply and -backup scripts with arguments required for each action. Executes the requested actions, depending on the config set by the -install and -manage scripts, and the command line options. If persistence or autoupdates are enabled, the cron jobs call this script with the necessary options.

```geoblocker-bash-run add -l <"list_id [list_id] ... [list_id]">``` : Fetches iplists and loads ipsets and iptables rules for specified list id's.
List id has the format of <country_code>_<family>. For example, ```US_ipv4``` and ```GB_ipv6``` are valid list id's.

```geoblocker-bash-run remove -l <"list_ids">``` : Removes iplists, ipsets and iptables rules for specified list id's.

```geoblocker-bash-run update``` : Updates the ipsets for list id's that had been previously configured. Intended for triggering from periodic cron jobs.

```geoblocker-bash-run apply``` : Skips the fetch script, calls the *apply script to restore ipsets and firewall rules as configured. Used by the reboot cron job to implement persistence.

**The -fetch script**
- Fetches ip lists for given list id's from RIPE or from ipdeny. The source is selected during installation. If you want to change the default which is RIPE, install with the ```-u ipdeny``` option.
- Parses, validates, compiles the downloaded lists, and saves each one to a separate file.
- Implements extensive sanity checks at each stage (fetching, parsing, validating and saving) and handles errors if they occur.

(for specific information on how to use the script, run it with the -h option)

**The -apply script**:  directly interfaces with the firewall. Creates or removes ipsets and iptables rules for specified country codes.

```geoblocker-bash-apply add -l <"list_ids">``` :
- Loads ip list files for specified list id's into ipsets and sets iptables rules required to implement geoblocking.

List id has the format of <country_code>_<family>. For example, ```US_ipv4``` and ```GB_ipv6``` are valid list id's.

```geoblocker-bash-apply remove -l <"list_ids">``` :
- removes ipsets and associated iptables rules for specified list id's.

**The -cronsetup script** manages all the cron-related logic and actions. Called by the -manage script. Cron jobs are created based on the settings stored in the config file.

(for specific information on how to use the script, run it with the -h option)

**The -backup script**: Creates a backup of the current iptables state, current geoblocking config and geoblocker-associated ipsets, or restores them from backup. By default (if you didn't run the installation with the '-o' option), backup will be created before every action you apply to the firewall and before automatic list updates are applied. Normally backups should not take much space, maybe a few megabytes if you have many ip lists. The -backup script also compresses them, so they take even less space. (and automatically extracts them when restoring). When creating a new backup, it overwrites the previous one, so only one backup copy is kept.

```geoblocker-bash-backup create-backup``` : Creates a backup of the current iptables state, geoblocking config and geoblocker-associated ipsets.

```geoblocker-bash-backup restore``` : Can be manually used for recovery from fault conditions (unlikely that anybody will ever need this but implemented just in case).
- Restores ipsets, iptables state and geoblocking config from the last backup.

**The -reset script** is called by the *install script to clean up previous geoblocking rules in the firewall and reset the config (just in case you install again without uninstalling first)

**The -common script** : Stores common functions and variables for the geoblocker-bash suite. Does nothing if called directly. Most other scripts won't work without it.

**The validate-cron-schedule.sh script** is used by the -cronsetup script. It accepts a cron schedule expression and attempts to make sure that it conforms to the crontab format. It can be used outside the suite as it doesn't depend on the -common script. This is a heavily modified and improved version of a prior 'verifycron' script I found circulating on the internets (not sure who wrote it so can't give them credit).

**The check-ip-in-source.sh script** can be used to verify that a certain ip address belongs to a subnet found in source records for a given country. It is intended for manual use and is not called from other scripts. It does depend on the *fetch script, and on the *common script (they just need to be in the same directory), and in addition, it requires the grepcidr utility installed in your system.

```bash check-ip-in-source.sh -c <country_code> -i <"ip [ip] [ip] ... [ip]"> [-u <source>]```

- Supported sources are 'ripe' and 'ipdeny'.
- Any combination of ipv4 and ipv6 addresses is supported.
- If passing multiple ip addresses, use double quotes around them.

**The detect-local-subnets-AIO.sh script** is the latest addition to the suite. It is a side project which I developed for the suite but, contrary to all other scripts in the suite, it doesn't require Bash, is portable and should work on most Unix-like machines, as long as they have the `ip` utility. By default, it outpus all found local ip addresses, both ipv4 (inet) and ipv6 (inet6), and then all subnets these ip addresses belong to.

```sh detect-local-subnets-AIO.sh [-f <inet|inet6>] [-s] [-d]```

Optional arguments:
- `-f <inet|inet6|"inet inet6">`: only detect subnets for the specified family. Also accepts the other notation for the same thing: `-f <ipv4|ipv6|"ipv4 ipv6">`
- `-s`: only output the subnets (doesn't output the ip addresses and the other text)
- `-d`: debug

This script is called by the -apply script when the suite is installed in whitelist mode. The reason for its existence is that in whitelist mode, all incoming connections are blocked, except what is explicitly allowed. Since this project doesn't aim to isolate your machine from your local network, but rather to block incoming connections from countries of your choosing, in whitelist mode it detects your local area networks and creates whitelist firewall rules for them, so they don't get blocked. If installed in blacklist mode, this script will not be called because whitelisting local networks is not required in that mode.

The script name has "AIO" suffix because it's an assembly made from 3 other scripts I developed: `trim-subnet.sh`, `aggregate-subnets.sh` and `detect-subnet.sh`. They have a separate repository here:

https://github.com/blunderful-scripts/subnet-tools
