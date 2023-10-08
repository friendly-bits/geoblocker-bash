#!/bin/bash

# check_ip_in_registry.sh

# For each of the specified ip addresses, checks whether it belongs to one of the subnets
#      in the list fetched from a regional internet registry for a given country code.

# Based on a prior script by mivk, called get-ripe-ips.

me=$(basename "$0")


#### USAGE

usage() {
    cat <<EOF

$me
    For each of the specified ip addresses, checks whether it belongs to one of the subnets
          in the list fetched from a regional internet registry for a given country code.

Requires "jq" and "grepcidr" utilities.
Requires GNU 'grep' and 'awk' utilities (most Linux distributions include these by default).

Usage: $me -c <country_code> -i <"ip [ip ... ip]"> [-d] [-h]

Options:
    -c <country_code>    : tld/country code
    -i <"ip_addresses">  : ipv4 addresses to check
                           - if specifying multiple addresses, use double quotes

    -d                   : Debug
    -h                   : This help

EOF
}


#### Functions

die() {
	echo -e "\n$@\n" >&2
	exit 1
}

process_grep_results() {
# takes grep return value $1 and grep output string $2,
# converts these results into a truth table,
# then calculates the validation result based on the truth table sum
# the idea is to cross-reference both values in order to avoid erroneous validation results

	grep_rv="$1"
	grep_output="$2"

	# convert 'grep return value' and 'grep output value' resulting value into truth table inputs
	[ "$grep_rv" -ne 0 ] && rv1=1 || rv1=0
	[ "$grep_output" = "" ] && rv2=10 || rv2=0

	# calculate the truth table sum
	truth_table_result=$(( 2#$rv1 + 2#$rv2))
	return "$truth_table_result"
}

parse_arin() {
	# basically:
	# 1) grep the fetched list to extract this:
	# 	'subnet|ip_addresses_count'
	#	(because this is the data in the ARIN file, don't ask me why they don't just use CIDR instead of ip_addresses_cnt)
	# 2) tr replaces '|' delimiter with ' ' delimiter. now we have 'subnet ip_address_count'
	# 3) awk uses the $cidr_lookup_table to replace ip_addr_count with matching CIDR pattern
	# 	(e.g. '256' gets replaced by '/24')
	#	(awk wants files for its input but we want to avoid creating yet more intermediate files, so we use the <() construct instead)
	# 4) now we have 'subnet /CIDR'
	# 5) tr deletes the ' '
	# 6) finally, we have 'subnet/CIDR' (e.g. 217.10.224.0/24)
	# 7) we write that into $parsed_file which we can use as input to grepcidr
	#
	# slightly crazy? yes. do you have a simpler solution? then please, do let me know.

	awk 'NR==FNR {a[$1] = $2; next} {$2 = a[$2]} 1' <(echo "$cidr_lookup_table") \
		<(grep -oP "(?<=arin\|$tld\|ipv4\|).*?(?=\|[0-9]*?\|allocated)" < "$fetched_file" | tr "|" " ") | \
		tr -d " " > "$parsed_file"

	# check that $parsed_file is non-empty
	[ -s "$parsed_file" ] && rv=0 || rv=1
	return "$rv"
}

parse_ripe() {
	jq -r ".data.resources.$family | .[]" "$fetched_file" > "$parsed_file"; rv=$?
	[[ "$rv" -ne 0 || ! -s "$parsed_file" ]] && rv=1
	return "$rv"	
}


#### Parse arguments

while getopts ":c:i:dh" opt; do
	case $opt in
	c) tld=$OPTARG;;
	i) arg_ipv4s=$OPTARG;;
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

# color escape codes
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
purple='\033[0;35m'
no_color='\033[0m'

# convert to upper case
tld="${tld^^}"

arin_url="https://ftp.arin.net/pub/stats/arin/delegated-arin-extended-latest"
ripe_url="https://stat.ripe.net/data/country-resource-list/data.json?v4_format=prefix&resource=$tld"

## only parsing the ipv4 section at this time
family="ipv4"

# using Perl regex syntax because grep is faster with it than with native grep syntax
# regex compiled from 2 suggestions found here:
# https://stackoverflow.com/questions/5284147/validating-ipv4-addresses-with-regexp
ipv4_regex='^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}'
mask_regex='(/([01]?\d\d?|2[0-4]\d|25[0-5]))$'
subnet_regex="${ipv4_regex}${mask_regex}"

curl_command="curl --retry 8 --fail-early --connect-timeout 5 --progress-bar"
wget_command="wget --tries=8 --timeout=5 --show-progress"

fetch_retries=3

validated_ipv4s=""
invalid_ipv4s=""
ip_check_rv=0

# trim extra whitespaces
arg_ipv4s="$(awk '{$1=$1};1' <<< "$arg_ipv4s")"

cidr_lookup_table=$(cat <<EOF
1 /32
2 /31
4 /30
8 /29
16 /28
32 /27
64 /26
128 /25
256 /24
512 /23
1024 /22
2048 /21
4096 /20
8192 /19
16384 /18
32768 /17
65536 /16
131072 /15
262144 /14
524288 /13
1048576 /12
2097152 /11
4194304 /10
8388608 /9
16777216 /8
33554432 /7
67108864 /6
EOF
)


#### Checks

[ -z "$tld" ] && { usage; die "Specify country with \"-c <country>\"!"; }

case "$tld" in
	AI|AQ|AG|BS|BB|BM|BV|CA|KY|DM|GD|GP|HM|JM|MQ|MS|PR|BL|SH|KN|LC|PM|VC|MF|TC|US|UM|VG|VI )
		registry="ARIN"
		url="$arin_url"
	;;
	* ) registry="RIPE"
		url="$ripe_url"
	;;
esac

# make sure that we have ip addresses to check
[ -z "$arg_ipv4s" ] &&	{ usage; die "Specify the ip addresses you want to check with \"-i <ip>\"!"; }

# check for awk
if ! command -v awk &> /dev/null; then
	die "Error: Cannot find awk. Install it with 'sudo apt install gawk' or similar."
fi

# check for grep
if ! command -v grep &> /dev/null; then
	die "Error: Cannot find grep. Install it with 'sudo apt install grep' or similar."
fi

# check for curl
command -v "curl" &> /dev/null && curl_exists="true"

# check for wget
command -v "wget" &> /dev/null && wget_exists="true"

[[ ! "$curl_exists" && ! "$wget_exists" ]] && die "Error: Neither curl nor wget found."

# check for jq
if ! command -v jq &> /dev/null; then
	die "Error: Cannot find the jq Json processor. Install it with 'sudo apt install jq' or similar."
fi

# check for grepcidr
if ! command -v grepcidr &> /dev/null; then
	die "Error: Cannot find grepcidr. Install it with 'sudo apt install grepcidr' or similar."
fi


#### Main

echo

for arg_ipv4 in $arg_ipv4s; do
	# validate the ip address by grepping it with the pre-defined validation regex
	validated_ipv4=$(echo "$arg_ipv4" | grep -P "$ipv4_regex\$"); rv=$?

	# process grep results
	process_grep_results "$rv" "$validated_ipv4"; true_grep_rv=$?

	case "$true_grep_rv" in
		0) validated_ipv4s="$validated_ipv4s $validated_ipv4" ;;
		1) die "${red}Error${no_color}: grep reported an error but returned a non-empty '\$validated_ipv4'. Something is wrong." ;;
		2) die "${red}Error${no_color}: grep didn't report any error but returned an empty '\$validated_ipv4'. Something is wrong." ;;
		3) echo -e "\nError: '$arg_ipv4' does not appear to be a valid ipv4 address."
			invalid_ipv4s="$invalid_ipv4s $arg_ipv4" ;;
		*) die "${red}Error${no_color}: unexpected \$true_grep_rv: '$true_grep_rv'. Something is wrong." ;;
	esac
done

# trim extra whitespaces
validated_ipv4s="$(awk '{$1=$1};1' <<< "$validated_ipv4s")"
invalid_ipv4s="$(awk '{$1=$1};1' <<< "$invalid_ipv4s")"

# if $validated_ipv4 is empty then validation of all ip's failed
if [ -z "$validated_ipv4s" ]; then
	echo
	die "Error: all ipv4 addresses failed validation."
fi

fetched_file=$(mktemp "/tmp/fetched-$country-XXXX")

if [ "$wget_exists" ]; then
	fetch_command="$wget_command $url -O $fetched_file"
elif [ "$curl_exists" ]; then
	fetch_command="$curl_command $url -o $fetched_file"
fi

# reset variables
retry_cnt=1
tld_status="unknown"
validated_subnets_cnt=0
failed_subnets_cnt=0
parsed_subnets_cnt=0


# Make $fetch_retries attempts to fetch the list (or until successful fetch and no validation errors)
while true; do
	echo -e "Fetching subnets list for country ${yellow}'$tld'${no_color} from ${yellow}$registry${no_color}...\n"
	$fetch_command; rv=$?

	if [[ $rv -ne 0 || ! -s "$fetched_file" ]; then
		rm "$fetched_file" &>/dev/null
		echo "Failed to fetch subnets list from $registry for country '$tld'." >&2
		[ "$debug" ] && echo -e "\nDebug: Error $rv when running '$fetch_command'." >&2
		tld_status="failed"
		[ "$retry_cnt" -ge "$fetch_retries" ] && break
	else
		echo "Fetch successful."

		# Parse the fetched file
		echo -n "Parsing... "

		parsed_file=$(mktemp "/tmp/parsed-$tld-XXXX.list")

		case "$registry" in
			ARIN ) parse_arin; rv=$? ;;
			RIPE ) parse_ripe; rv=$? ;;
			* ) parse_ripe; rv=$? ;;
		esac
		rm "$fetched_file" &>/dev/null

		if [ "$rv" -ne 0 ]; then
			rm "$parsed_file" &>/dev/null
			tld_status="failed"
			echo -e "\nError: failed to parse the fetched file for country '$tld'." >&2
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
	retry_cnt=$(( retry_cnt + 1 ))
	echo -e "\nRetrying fetch (attempt $retry_cnt of $fetch_retries)...\n" >&2
done

echo

if [[ "$tld_status" = "Ok" || "$tld_status" = "partial" ]] && [ "$validated_subnets_cnt" -eq 0 ]; then
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
	failed ) rm "$validated_file" &>/dev/null; die "Failed to check the ip address in $registry for country '$tld'." ;;
	* ) rm "$validated_file" &>/dev/null; die "Error: unrecognized \$tld_status '$tld_status'. Failed to check the ip address in $registry for country '$tld'." ;;
esac

echo -e "\nValidated subnets count for country '$tld': $validated_subnets_cnt.\n"

for validated_ipv4 in $validated_ipv4s; do
	filtered_ipv4="$(echo "$validated_ipv4" | grepcidr -f "$validated_file")"; rv=$?

	# validate grep results
	process_grep_results "$rv" "$filtered_ipv4"; true_grep_rv=$?

	case "$true_grep_rv" in
		0) echo -e "Result: '$validated_ipv4' ${green}*BELONGS*${no_color} to a subnet in ${registry}'s list for country '$tld'." ;;
		1) echo -e "${red}Error${no_color}: grepcidr reported an error but returned a non-empty '\$filtered_ipv4'. Something is wrong."
			fatal_error="true" ;;
		2) echo -e "${red}Error${no_color}: grepcidr didn't report any error but returned an empty '\$filtered_ipv4'. Something is wrong."
			fatal_error="true" ;;
		3) echo -e "Result: '$validated_ipv4' ${red}*DOES NOT BELONG*${no_color} to a subnet in ${registry}'s list for country '$tld'." ;;
		*) echo -e "${red}Error${no_color}: unexpected \$truth_table_result: '$truth_table_result'. Something is wrong."
			fatal_error="true" ;;
	esac

	[ "$grepcidr_error" = true ] && { rm "$validated_file" &>/dev/null; die "Failed to process grepcidr results."; }

	# increment the return value if matching didn't succeed for any reason
	[ "$truth_table_result" -ne 0 ] && ip_check_rv=$(( ip_check_rv + 1 ))
done


if [ -n "$invalid_ipv4s" ]; then
	echo -e "${red}Invalid${no_color} ipv4 addresses: '$invalid_ipv4s'"
	ip_check_rv=$(( ip_check_rv + 1 ))
fi

rm "$validated_file" &>/dev/null

echo

[ "$ip_check_rv" -gt 0 ] && exit 1 || exit 0
