#!/bin/bash

# validate_cron_schedule.sh

#    Checks a cron schedule expression to ensure that it's formatted properly.  Expects standard cron notation of
#       min hr dom mon dow
#    where min is 0-59, hr 0-23, dom is 1-31, mon is 1-12 (or names) and dow is 0-7 (or names).  Fields can have ranges (a-e), lists
#    separated by commas (a,c,z), or an asterisk. Note that the step value notation of Vixie cron is not supported (e.g., 2-6/2).
#
#    Based on prior "verifycron" script circulating on the internets
#    This is a simplified version, adapted to receive one cron schedule expression in an argument.

me=$(basename "$0")

#### USAGE

usage() {
    cat <<EOF

    Checks a cron schedule expression to ensure that it's formatted properly.  Expects standard cron notation of
       min hr dom mon dow
    where min is 0-59, hr 0-23, dom is 1-31, mon is 1-12 (or names) and dow is 0-7 (or names).  Fields can have ranges (a-e), lists
    separated by commas (a,c,z), or an asterisk. Note that the step value notation of Vixie cron is not supported (e.g., 2-6/2).

    Usage: $me -x "expression" [-h]

    Options:
    -x "expression"    : crontab schedule expression ***in double quotes***, example: "0 4 * * 6"

    -h                 : This help

EOF
}

#### Parse arguments

while getopts "x:h" opt; do
	case $opt in
	x) sourceline=$OPTARG;;
	h) usage; exit 0;;
	\?) usage; exit 1;;
	esac
done
shift $((OPTIND -1))


#### Functions

validNum() {
# return 0 if valid, 1 if not. Specify number and maxvalue as args
	num=$1; max=$2
	if [ "$num" = "X" ] ; then
		return 0
	elif [ -n "$(echo $num | sed 's/[[:digit:]]//g')" ] ; then
		return 1
	elif [ "$num" -lt 0 ] || [ "$num" -gt "$max" ] ; then
		return 1
	else
		return 0
	fi
}

validDay() {
# return 0 if a valid dayname, 1 otherwise
	case $(echo "$1" | tr '[:upper:]' '[:lower:]') in
		sun|mon|tue|wed|thu|fri|sat) return 0 ;;
		X) return 0    ;; # special case - it's an "*"
		*) return 1
	esac
}

validMon() {
# return 0 if a valid month name, 1 otherwise
	case $(echo "$1" | tr '[:upper:]' '[:lower:]') in
		jan|feb|mar|apr|may|jun|jul|aug) return 0;;
		sep|oct|nov|dec) return 0;;
		X) return 0;; # special case, it's an "*"
		*) return 1;;
	esac
}

fixvars() {
# translate all '*' into 'X' to bypass shell expansion hassles

	min=$(echo "$min" | tr '*' 'X')
	hour=$(echo "$hour" | tr '*' 'X')
	dom=$(echo "$dom" | tr '*' 'X')
	mon=$(echo "$mon" | tr '*' 'X')
	dow=$(echo "$dow" | tr '*' 'X')
}

echo ""

#### Initialize variables

errors=0
exitstatus=0


#### Main

echo "Validating cron schedule \"$sourceline\" ..."

## Parse and check arguments for sanity

read -r min hour dom mon dow extra <<< "$sourceline"

if [ -n "$extra" ]; then
	echo ""
	echo "Error: Too many fields in schedule expression! I don't know what to do with \"$extra\"!" >&2
	echo "Use double braces around your expression!" >&2
	echo "You entered: \"$sourceline\"" >&2
	echo "Valid example: \"0 4 * * 6\"" >&2
	echo ""
	exit 1;
fi

if [ -z "$min" ] || [ -z "$hour" ] || [ -z "$dom" ] || [ -z "$mon" ] || [ -z "$dow" ]; then
# if some arguments are missing
	echo ""
	echo "Not enough fields in schedule expression!"
	echo "This script requires crontab schedule line as an argument!" >&2
	echo "Use double braces around your expression!" >&2
	echo "You entered: \"$sourceline\"" >&2
	echo "Valid example: \"0 4 * * 6\"" >&2
	echo ""
	exit 1
fi


#### Main

## Breaks the input into fields, replaces all '*' with 'X', stores results in global variables
fixvars

# minute check
for minslice in $(echo "$min" | sed 's/[,-]/ /g') ; do
	if ! validNum "$minslice" 60 ; then
		echo "Invalid minute value \"$minslice\"" >&2
		errors="$(( $errors + 1 ))"
	fi
done

# hour check

for hrslice in $(echo "$hour" | sed 's/[,-]/ /g') ; do
	if ! validNum "$hrslice" 24 ; then
		echo "Invalid hour value \"$hrslice\"" >&2
		errors="$((errors + 1))"
	fi
done

# day of month check

for domslice in $(echo "$dom" | sed 's/[,-]/ /g') ; do
	if ! validNum "$domslice" 31 ; then
		echo "Invalid day of month value \"$domslice\"" >&2
		errors="$((errors + 1))"
	fi
done

# month check

for monslice in $(echo "$mon" | sed 's/[,-]/ /g') ; do
	if ! validNum "$monslice" 12 ; then
		if ! validMon "$monslice" ; then
			echo "Invalid month value \"$monslice\"" >&2
			errors="$((errors + 1))"
		fi
	fi
done

# day of week check

for dowslice in $(echo "$dow" | sed 's/[,-]/ /g') ; do
	if ! validNum "$dowslice" 7 ; then
		if ! validDay "$dowslice" ; then
			echo "Invalid day of week value \"$dowslice\"" >&2
			errors="$((errors + 1))"
		fi
	fi
done

if [ $errors -gt 0 ] ; then
	exitstatus=1
	echo ""
	echo "You entered: \"$sourceline\"" >&2
	echo "Valid example: \"0 4 * * 6\"" >&2
else
	echo "Successfully validated cron schedule."
fi
echo ""

exit $exitstatus
