#!/bin/bash

# check_ip_in_ripe.sh

# Checks whether a given IP address belongs to a subnet found in RIPE's records for a given country.
## For RIPE API, see https://stat.ripe.net/docs/data_api

# Based on a prior script by mivk, called get-ripe-ips.

me=$(basename "$0")


#### USAGE

usage() {
    cat <<EOF

$me
- Checks whether the specified IP adress belongs to one of the subnets in the list fetched from RIPE for a given country code.

Requires "jq" and "grepcidr" utilities. If you are on Debian or derivatives, install both with "apt install jq grepcidr".

Usage: $me -c <country> -i <ip> [-d] [-h]

Options:
    -c tld    : tld/country code
    -i ip     : ipv4 address to check

    -d        : Debug
    -h        : This help

EOF
}


#### Functions

die() {
	echo "$@" >&2
	echo
	exit 1
}


#### Parse arguments

while getopts ":c:i:dh" opt; do
	case $opt in
	c) tld=$OPTARG;;
	i) userip=$OPTARG;;
	d) debug=true;;
	h) usage; exit 0;;
	\?) usage; die "Unknown option: '$OPTARG'." ;;
	esac
done
shift $((OPTIND -1))

[ "$*" != "" ] && {
	usage
	die "Error in arguments. First unrecognized argument: '$1'."
}


#### Initialize variables
ripe_url="https://stat.ripe.net/data/country-resource-list/data.json?v4_format=prefix&resource="
url="$ripe_url$tld"
## only parsing the ipv4 section at this time
family="ipv4"

# using Perl regex syntax because grep is faster with it than with native grep syntax
# regex compiled from 2 suggestions found here:
# https://stackoverflow.com/questions/5284147/validating-ipv4-addresses-with-regexp
ip_regex='^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}'
mask_regex='(/([01]?\d\d?|2[0-4]\d|25[0-5]))$'
subnet_regex="${ip_regex}${mask_regex}"

curl_command="curl --retry 8 --fail-early --connect-timeout 7 --progress-bar"
wget_command="wget --tries=8 --timeout=7 --show-progress"

fetch_retries=3


#### Checks

if [ -z "$tld" ]; then
	usage
	echo
	die "Specify country with \"-c <country>\"!"
fi

# make sure that we have an ip address to check
if [ -z "$userip" ]; then
	usage
	echo
	die "Specify the ip address you want to check with \"-i <ip>\"!"
fi

# check for curl
command -v "curl" &> /dev/null && curl_exists="true"

# check for wget
command -v "wget" &> /dev/null && wget_exists="true"

[[ ! "$curl_exists" && ! "$wget_exists" ]] && die 1 "Error: Neither curl nor wget found."

# check that we have jq
if ! command -v jq &> /dev/null; then
	die "Error: Cannot find the jq Json processor. Install it with 'apt install jq' or similar. Exiting"
fi

# check that we have grepcidr
if ! command -v grepcidr &> /dev/null; then
	die "Error: Cannot find grepcidr. Install it with 'apt install grepcidr' or similar. Exiting"
fi


#### Main

echo

# validate the specified ip address
validated_ipv4=$(echo "$userip" | grep -P "$ip_regex\$")

# if $validated_ipv4 is empty then validation failed
if [ -z "$validated_ipv4" ]; then
	echo
	die "Error: '$userip' does not appear to be a valid ipv4 address. Exiting."
fi

fetched_file=$(mktemp "/tmp/fetched-$country-XXXX.json")

if [ "$wget_exists" ]; then
	fetch_command="$wget_command $url -O $fetched_file"
elif [ "$curl_exists" ]; then
	fetch_command="$curl_command $url -o $fetched_file"
fi

# reset variables
retry_cnt=0
tld_status="unknown"
validated_subnets_cnt=0
failed_subnets_cnt=0
parsed_subnets_cnt=0

echo -e "Fetching subnets list for country '$tld'...\n"

# Make $fetch_retries attempts to fetch the list (or until successful fetch and no validation errors)
while true; do
	retry_cnt=$(( retry_cnt + 1 ))

	$fetch_command; rv=$?

	if [ $rv -ne 0 ]; then
		rm "$fetched_file" &>/dev/null
		echo "Error when running '$fetch_command'."
		tld_status="failed"
		[ "$retry_cnt" -ge "$fetch_retries" ] && break
	else
		status=$(jq -r '.status' "$fetched_file")
		if [[ ! "$status" = "ok" || ! -s "$fetched_file" ]]; then
			echo "Fetch failed." >&2
			ripe_msg=$(jq -r -c '.messages' "$fetched_file")
			[ "$debug"] && echo -e "RIPE replied with message: '$ripe_msg'\n" >&2
			rm "$fetched_file" &>/dev/null
			tld_status="failed"
			[ "$retry_cnt" -ge "$fetch_retries" ] && break
		else
			echo "Fetch successful."

			parsed_file=$(mktemp "/tmp/parsed-$tld-XXXX.list")

			# Parse the fetched file
			echo -n "Parsing... "
			jq -r ".data.resources.$family | .[]" "$fetched_file" > "$parsed_file"; rv=$?
			rm "$fetched_file" &>/dev/null

			if [ "$rv" -ne 0 ]; then
				rm "$parsed_file" &>/dev/null
				tld_status="failed"
				echo "Error: failed to parse the fetched file for country '$tld'." >&2
				[ "$retry_cnt" -ge "$fetch_retries" ] && break
			else
				echo "Ok."
				# Validate the parsed file
				parsed_subnets_cnt=$(wc -l < "$parsed_file")

				echo -n "Validating... "
				validated_file=$(mktemp "/tmp/validated-$tld-XXXX.list")
				grep -P "$subnet_regex" "$parsed_file" > "$validated_file"
				rm "$parsed_file" &>/dev/null

				validated_subnets_cnt=$(wc -l < "$validated_file")

				failed_subnets_cnt=$(( parsed_subnets_cnt - validated_subnets_cnt ))
				if [ "$failed_subnets_cnt" -gt 0 ]; then
					echo "Note: Fetch attempt $retry_cnt: $failed_subnets_cnt subnets failed validation." >&2
					[ "$retry_cnt" -ge "$fetch_retries" ] && { tld_status="partial"; break; }
					rm "$validated_file" &>/dev/null
				else
					echo "Ok."
					tld_status="Ok"
					break
				fi
			fi
		fi
	fi
	echo -e "Retrying fetch...\n" >&2
done

echo

if [[ "$tld_status" = "Ok" && "$validated_subnets_cnt" -eq 0 ]]; then
	rm "$validated_file" &>/dev/null
	echo "Error: validated 0 subnets for country code '$tld'. Perhaps the country code is incorrect?" >&2
	tld_status="failed"
fi

# If we have a partial list, decide whether to consider it Ok or not
if [ "$tld_status" = "partial" ]; then
	echo "Warning: out of $parsed_subnets_cnt, $failed_subnets_cnt subnets for country '$tld' failed validation." >&2
	echo "Invalid subnets removed from the list." >&2

	echo -e "\n\nWarning: Ip list for country '$tld' has been fetched but may be incomplete."
	echo "Use the incomplete list anyway?"
	while true; do
		read -p "(Y/N) " -n 1 -r
		if [[ "$REPLY" =~ ^[Yy]$ ]]; then tld_status="Ok"; break
		elif [[ "$REPLY" =~ ^[Nn]$ ]]; then
			rm "$validated_file" &>/dev/null
			tld_status="failed"
		else echo -e "\nPlease press 'y/n'.\n"
		fi
	done
fi

case "$tld_status" in
	Ok ) ;;
	failed ) rm "$validated_file" &>/dev/null; die "Failed to check the ip address in RIPE for country '$tld'." ;;
	* ) rm "$validated_file" &>/dev/null; die "Error: unrecognized \$tld_status '$tld_status'. Failed to check the ip address in RIPE for country '$tld'." ;;
esac

echo -e "\nValidated subnets count for country '$tld': $validated_subnets_cnt.\n"

echo -e "Checking $userip...\n"

filtered_ip="$(echo "$userip" | grepcidr -f "$validated_file")"; rv=$?

# adapt the results for use in truth table
[ "$rv" -ne 0 ] && rv1=1 || rv1=0
[ "$filtered_ip" = "" ] && rv2=10 || rv2=0

red_code='\033[0;31m'
green_code='\033[0;32m'
no_color='\033[0m'

# check the result based on a truth table for $rv1, $rv2
truth_table_result=$(( 2#$rv1 + 2#$rv2))

case "$truth_table_result" in
	0) echo -e "Result: '$userip' ${green_code}*BELONGS*${no_color} to a subnet in RIPE's list for country '$tld'." ;;
	1) echo -e "${red_code}Error${no_color}: grepcidr reported an error but returned a non-empty '\$filtered_ip'. Something is wrong in the script code." ;;
	2) echo -e "${red_code}Error${no_color}: grepcidr didn't report any error but returned an empty '\$filtered_ip'. Something is wrong in the script code." ;;
	3) echo -e "Result: '$userip' ${red_code}*DOES NOT BELONG*${no_color} to a subnet in RIPE's list for country '$tld'." ;;
	*) echo -e "${red_code}Error${no_color}: unexpected \$truth_table_result: '$truth_table_result'." ;;
esac

rm "$validated_file" &>/dev/null

exit "$truth_table_result"
