#!/bin/bash

# check-ip-in-source.sh

#### Initial setup
LC_ALL=C
export PATH="/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin:"

me=$(basename "$0")

suite_name="geoblocker-bash"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2015
[[ -n "$script_dir" ]] && cd "$script_dir" || { err="$me: Error: Couldn't cd into '$script_dir'."; echo "$err" >&2; exit 1; }

# shellcheck source=geoblocker-bash-common
source "$script_dir/${suite_name}-common" || { err="$me: Error: Can't source ${suite_name}-common."; echo "$err" >&2; exit 1; }

# **NOTE** that some functions and variables are sourced from the *common script


#### USAGE

usage() {
    cat <<EOF

$me
    For each of the specified ip addresses, checks whether it belongs to one of the subnets
          in the list fetched from a source (either RIPE or ipdeny) for a given country code.
    Accepts a mix of ipv4 and ipv6 addresses.

Requires the 'grepcidr' utility, '${suite_name}-fetch', '${suite_name}-common.sh', 'cca2.list'

Usage: $me -c <country_code> -i <"ip [ip ... ip]"> [-u ripe|ipdeny] [-d] [-h]

Options:
    -c <country_code>    : Country code (ISO 3166-1 alpha-2)
    -i <"ip_addresses">  : ip addresses to check
                           - if specifying multiple addresses, use double quotes
    -u <ripe|ipdeny>     : Source to check in. By default checks in RIPE.

    -d                   : Debug
    -h                   : This help

EOF
}


#### Parse arguments

while getopts ":c:i:u:dh" opt; do
	case $opt in
	c) ccode=$OPTARG ;;
	i) ips=$OPTARG ;;
	u) source_arg=$OPTARG ;;
	d) debugmode_args=true ;;
	h) usage; exit 0 ;;
	\?) usage; die "Unknown option: '$OPTARG'." ;;
	esac
done
shift $((OPTIND -1))

[[ -n "$*" ]] && {
	usage
	die "Error in arguments. First unrecognized argument: '$1'."
}

# get debugmode variable from either the args or environment variable, depending on what's set
debugmode="${debugmode_args:-$debugmode}"
# set env var to match the result
export debugmode="$debugmode"


#### Functions

die() {
	rm "$list_file" &>/dev/null
	rm "$status_file" &>/dev/null
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
	[[ "$grep_rv" -ne 0 ]] && rv1=1 || rv1=0
	[[ -z "$grep_output" ]] && rv2=10 || rv2=0

	# calculate the truth table sum
	truth_table_result=$(( 2#$rv1 + 2#$rv2))
	return "$truth_table_result"
}

validate_ip() {
	unset validated_ip
	grep -E "$ipv4_regex" <<< "$1" &>/dev/null; rv=$?
	if [[ "$rv" -eq 0 ]]; then families+="ipv4 "; validated_ip="$1"; validated_ipv4s+="$1 "; return 0
	else
		grep -E "$ipv6_regex" <<< "$1" &>/dev/null; rv=$?
		if [[ "$rv" -eq 0 ]]; then families+="ipv6 "; validated_ip="$1"; validated_ipv6s+="$1 "; return 0
		else return 1
		fi
	fi
}


#### Constants

export nolog=true


# regex patterns used for ip validation

# ipv4 regex regex taken from here and modified for ERE matching:
# https://stackoverflow.com/questions/5284147/validating-ipv4-addresses-with-regexp
# the longer ("alternative") ipv4 regex from the top suggestion performs about 40x faster with ERE grep than the shorter one
# ipv6 regex taken from the BanIP code and modified for ERE matching
# https://github.com/openwrt/packages/blob/master/net/banip/files/banip-functions.sh
ipv4_regex='^((25[0-5]|(2[0-4]|1[0-9]|[1-9]|)[0-9])\.){3}(25[0-5]|(2[0-4]|1[0-9]|[1-9]|)[0-9])'
ipv6_regex='^(([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}:?(\\/(1?[0-2][0-8]|[0-9][0-9]))?)'

fetch_script="${script_dir}/${suite_name}-fetch"

valid_sources="ripe ipdeny"
default_source="ripe"


#### Variables

source_arg="${source_arg,,}"

dl_source="${source_arg:-"$default_source"}"

# convert to upper case
ccode="${ccode^^}"

ip_check_rv=0


#### Checks

missing_deps="$(check_deps grepcidr)" || die "Error: missing dependencies: $missing_deps."

[[ -z "$ccode" ]] && { usage; die "Specify country code with '-c <country_code>'."; }
[[ $(wc -w <<< "$ccode") -gt 1 ]] && { usage; die "Specify only one country code."; }
validate_ccode "$ccode" "$script_dir/cca2.list" || { usage; die "Invalid country code: '$ccode'."; }

[[ $(wc -w <<< "$dl_source") -gt 1 ]] && { usage; die "Specify only one source."; }
[[ -z "$dl_source" ]] && die "Internal error: '\$dl_source' variable should not be empty!"
invalid_source="$(subtract_list_a_from_b "$valid_sources" "$dl_source")"
[[ -n "$invalid_source" ]] && { usage; die "Invalid source: $invalid_source"; }

# make sure that we have ip addresses to check
[[ -z "$ips" ]] &&	{ usage; die "Specify the ip addresses to check with '-i <\"ip_addresses\">'."; }

# check for *fetch
[[ ! -f "$fetch_script" ]] && die "Error: Can not find '$fetch_script'."

# convert ips to upper case and remove duplicates etc
ips="$(sanitize_string "${ips^^}")"

#### Main

echo

for ip in $ips; do
	# validate the ip address by grepping it with the pre-defined validation regex
	# also populates variables: $families, $validated_ipv4s, $validated_ipv6s
	validate_ip "$ip"; rv=$?

	# process grep results
	process_grep_results "$rv" "$validated_ip"; true_grep_rv=$?

	case "$true_grep_rv" in
		0) validated_ips+="$validated_ip " ;;
		1) die "${red}Error${no_color}: grep reported an error but returned a non-empty '\$validated_ip'. Something is wrong." ;;
		2) die "${red}Error${no_color}: grep didn't report any error but returned an empty '\$validated_ip'. Something is wrong." ;;
		3) invalid_ips+="'$ip' " ;;
		*) die "${red}Error${no_color}: unexpected \$true_grep_rv: '$true_grep_rv'. Something is wrong." ;;
	esac
done


# trim extra whitespaces
validated_ips="$(trim_spaces "$validated_ips")"
invalid_ips="$(trim_spaces "$invalid_ips")"
validated_ipv4s="$(trim_spaces "$validated_ipv4s")"
validated_ipv6s="$(trim_spaces "$validated_ipv6s")"
families="$(sanitize_string "$families")"

if [[ -z "$validated_ips" ]]; then
	echo
	die "Error: all ip addresses failed validation."
fi


### Fetch the ip list file

[[ -z "$families" ]] && die "Internal error: \$families variable is empty."

for family in $families; do
	case "$family" in
		ipv4 ) validated_ips="$validated_ipv4s" ;;
		ipv6 ) validated_ips="$validated_ipv6s" ;;
		* ) die "Internal error: unexpected family: '$family'." ;;
	esac

	list_id="${ccode}_${family}"
	status_file="/tmp/fetched-status-$list_id.tmp"

	list_file="/tmp/iplist-$list_id.tmp"

	bash "$fetch_script" -c "$ccode" -o "$list_file" -s "$status_file" -a "$family" -u "$dl_source"

	# read *fetch results from the status file
	failed_lists="$(getstatus "$status_file" "failed_lists")"; rv=$?
	rm "$status_file" &>/dev/null

	[[ "$rv" -ne 0 ]] && die "Error: Couldn't read value for 'failed_lists' from status file '$status_file'."

	[[ -n "$failed_lists" ]] && die "Error: ip list fetch failed."


	### Test the fetched list for specified ip's

	echo -e "\nChecking ip addresses..."

	for validated_ip in $validated_ips; do
		unset match
		filtered_ip="$(grepcidr -f "$list_file" <<< "$validated_ip")"; rv=$?
		[[ "$rv" -gt 1 ]] && die "Error: grepcidr returned error code '$grep_rv'."

		# process grep results
		process_grep_results "$rv" "$filtered_ip"; true_grep_rv=$?

		case "$true_grep_rv" in
			0) match="true" ;;
			1) die "${red}Error${no_color}: grepcidr reported an error but returned a non-empty '\$filtered_ip'. Something is wrong." ;;
			2) die "${red}Error${no_color}: grepcidr didn't report any error but returned an empty '\$filtered_ip'. Something is wrong." ;;
			3) ;;
			*) die "${red}Error${no_color}: unexpected \$true_grep_rv: '$true_grep_rv'. Something is wrong." ;;
		esac

		case "$family" in
			ipv4 ) if [[ "$match" ]]; then matching_ipv4s+="'$validated_ip' "; else non_matching_ipv4s+="'$validated_ip' "; fi ;;
			ipv6 ) if [[ "$match" ]]; then matching_ipv6s+="'$validated_ip' "; else non_matching_ipv6s+="'$validated_ip' "; fi ;;
		esac

		# increment the return value if matching didn't succeed
		[[ "$true_grep_rv" -ne 0 ]] && (( ip_check_rv++ ))
	done
	rm "$list_file" &>/dev/null
	rm "$status_file" &>/dev/null
done


matching_ipv4s="$(trim_spaces "$matching_ipv4s")"
matching_ipv6s="$(trim_spaces "$matching_ipv6s")"
non_matching_ipv4s="$(trim_spaces "$non_matching_ipv4s")"
non_matching_ipv6s="$(trim_spaces "$non_matching_ipv6s")"

echo -e "\nResults:"
[[ -n "$matching_ipv4s" ]] && echo -e "ip's $matching_ipv4s ${green}*BELONG*${no_color} to a subnet in source list for country '$ccode'."
[[ -n "$matching_ipv6s" ]] && echo -e "ip's $matching_ipv6s ${green}*BELONG*${no_color} to a subnet in source list for country '$ccode'."
[[ -n "$non_matching_ipv4s" ]] && echo -e "ip's $non_matching_ipv4s ${red}*DO NOT BELONG*${no_color} to a subnet in source list for country '$ccode'."
[[ -n "$non_matching_ipv6s" ]] && echo -e "ip's $non_matching_ipv6s ${red}*DO NOT BELONG*${no_color} to a subnet in source list for country '$ccode'."

if [[ -n "$invalid_ips" ]]; then
	echo -e "\n${red}Invalid${no_color} ip addresses:\n${invalid_ips}"
	(( ip_check_rv++ ))
fi

echo

[[ "$ip_check_rv" -gt 0 ]] && exit 1 || exit 0
