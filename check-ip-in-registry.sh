#!/bin/bash

# check_ip_in_registry.sh

# For each of the specified ip addresses, checks whether it belongs to one of the subnets
#      in the list fetched from a regional internet registry for a given country code.
# Currently supported regional registries: ARIN, RIPE

me=$(basename "$0")

suite_name="geoblocker-bash"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -n "$script_dir" ] && cd "$script_dir" || { err="$me: Error: Couldn't cd into '$script_dir'."; echo "$err" >&2; exit 1; }

source "$script_dir/${suite_name}-common" || { err="$me: Error: Can't source ${suite_name}-common."; echo "$err" >&2; exit 1; }

# **NOTE** that some functions and variables are sourced from the *common script


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
	echo -e "\n$*\n" >&2
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

export nolog=true

# color escape codes
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
purple='\033[0;35m'
no_color='\033[0m'

# convert to upper case
tld="${tld^^}"

## only parsing the ipv4 section at this time
family="ipv4"

# using Perl regex syntax because grep is faster with it than with native grep syntax
# regex compiled from 2 suggestions found here:
# https://stackoverflow.com/questions/5284147/validating-ipv4-addresses-with-regexp
ipv4_regex='^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}'
mask_regex='(/([01]?\d\d?|2[0-4]\d|25[0-5]))$'
subnet_regex="${ipv4_regex}${mask_regex}"

ip_check_rv=0


#### Checks

missing_deps="$(check_deps "curl|wget" jq)" || die "Error: missing dependencies: $missing_deps."

[ -z "$tld" ] && { usage; die "Specify country code with '-c <country_code>'."; }

# make sure that we have ip addresses to check
[ -z "$arg_ipv4s" ] &&	{ usage; die "Specify the ip addresses to check with '-i <\"ip_addresses\">'."; }

# check for *fetch
[ ! -f  "${script_dir}/${suite_name}-fetch" ] && die "Error: Can not find '${suite_name}-fetch'. Did you run the -install script?"


#### Main

echo

for arg_ipv4 in $arg_ipv4s; do
	# validate the ip address by grepping it with the pre-defined validation regex
	validated_arg_ipv4=$(grep -P "$ipv4_regex\$" <<< "$arg_ipv4"); rv=$?

	# process grep results
	process_grep_results "$rv" "$validated_arg_ipv4"; true_grep_rv=$?

	case "$true_grep_rv" in
		0) validated_arg_ipv4s="$validated_arg_ipv4s $validated_arg_ipv4" ;;
		1) die "${red}Error${no_color}: grep reported an error but returned a non-empty '\$validated_arg_ipv4'. Something is wrong." ;;
		2) die "${red}Error${no_color}: grep didn't report any error but returned an empty '\$validated_arg_ipv4'. Something is wrong." ;;
		3) echo -e "\nError: '$arg_ipv4' does not appear to be a valid ipv4 address."
			invalid_arg_ipv4s="$invalid_arg_ipv4s $arg_ipv4" ;;
		*) die "${red}Error${no_color}: unexpected \$true_grep_rv: '$true_grep_rv'. Something is wrong." ;;
	esac
done

# trim extra whitespaces
validated_arg_ipv4s="$(awk '{$1=$1};1' <<< "$validated_arg_ipv4s")"
invalid_arg_ipv4s="$(awk '{$1=$1};1' <<< "$invalid_arg_ipv4s")"

# if $validated_arg_ipv4 is empty then validation of all ip's failed
if [ -z "$validated_arg_ipv4s" ]; then
	echo
	die "Error: all ipv4 addresses failed validation."
fi


### Fetch the ip list file

status_file=$(mktemp "/tmp/status-XXXX")

list_file=$(mktemp "/tmp/iplist-$tld-XXXX")

bash "${script_dir}/${suite_name}-fetch" -c "$tld" -o "$list_file" -s "$status_file"

# read *fetch results from the status file
failed_tlds="$(getstatus "$status_file" "failed_tlds")" || { die "Error: Couldn't read value for 'tlds_to_update' from status file '$status_file'."; }
rm "$status_file"

[ -n "$failed_tlds" ] && { rm "$list_file"; die "Error: ip list fetch failed. Can not check ip's."; }


### Test the fetched list for specified ip's

echo -e "\nChecking ip addresses..."

for validated_arg_ipv4 in $validated_arg_ipv4s; do
	filtered_ipv4="$(grepcidr -f "$list_file" <<< "$validated_arg_ipv4")"; rv=$?

	# process grep results
	process_grep_results "$rv" "$filtered_ipv4"; true_grep_rv=$?

	case "$true_grep_rv" in
		0) echo -e "Result: '$validated_arg_ipv4' ${green}*BELONGS*${no_color} to a subnet in registry's list for country '$tld'." ;;
		1) echo -e "${red}Error${no_color}: grepcidr reported an error but returned a non-empty '\$filtered_ipv4'. Something is wrong."
			fatal_error="true" ;;
		2) echo -e "${red}Error${no_color}: grepcidr didn't report any error but returned an empty '\$filtered_ipv4'. Something is wrong."
			fatal_error="true" ;;
		3) echo -e "Result: '$validated_arg_ipv4' ${red}*DOES NOT BELONG*${no_color} to a subnet in registry's list for country '$tld'." ;;
		*) echo -e "${red}Error${no_color}: unexpected \$truth_table_result: '$truth_table_result'. Something is wrong."
			fatal_error="true" ;;
	esac

	[ "$grepcidr_error" = true ] && { rm "$list_file" &>/dev/null; die "Failed to process grepcidr results."; }

	# increment the return value if matching didn't succeed for any reason
	[ "$truth_table_result" -ne 0 ] && let ip_check_rv++
done


if [ -n "$invalid_arg_ipv4s" ]; then
	echo -e "${red}Invalid${no_color} ipv4 addresses: '$invalid_arg_ipv4s'"
	let ip_check_rv++
fi

rm "$list_file" &>/dev/null

echo

unset nolog

[ "$ip_check_rv" -gt 0 ] && exit 1 || exit 0
