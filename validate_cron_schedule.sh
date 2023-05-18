#!/bin/bash

# verify_cron_expression - script checks a cron schedule expression to ensure
#    that it's formatted properly.  Expects standard cron notation of
#       min hr dom mon dow
#    where min is 0-59, hr 0-23, dom is 1-31, mon is 1-12 (or names)
#    and dow is 0-7 (or names).  Fields can have ranges (a-e), lists
#    separated by commas (a,c,z), or an asterisk. Note that the step
#    value notation of Vixie cron is not supported (e.g., 2-6/2).


#### Functions

validNum()
{
  # return 0 if valid, 1 if not. Specify number and maxvalue as args
  num=$1   max=$2

  if [ "$num" = "X" ] ; then
    return 0
  elif [ ! -z $(echo $num | sed 's/[[:digit:]]//g') ] ; then
    return 1
  elif [ $num -lt 0 -o $num -gt $max ] ; then
    return 1
  else
    return 0
  fi
}

validDay()
{
  # return 0 if a valid dayname, 1 otherwise

  case $(echo $1 | tr '[:upper:]' '[:lower:]') in
    sun|mon|tue|wed|thu|fri|sat) return 0 ;;
    X) return 0	;; # special case - it's an "*"
    *) return 1
  esac
}

validMon()
{
  # return 0 if a valid month name, 1 otherwise

   case $(echo $1 | tr '[:upper:]' '[:lower:]') in 
     jan|feb|mar|apr|may|jun|jul|aug) return 0		;;
     sep|oct|nov|dec)		     return 0		;;
     X) return 0 ;; # special case, it's an "*"
     *) return 1	;;
   esac
}

fixvars()
{
  # translate all '*' into 'X' to bypass shell expansion hassles
  # save original as "sourceline" for error messages

  sourceline="$min $hour $dom $mon $dow $extra"
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

echo "Validating cron schedule \"$@\" ..."

## Parse and check arguments for sanity

# check that we received exactly 1 argument
if [ $# -ne 1 ] ; then
	echo ""
	echo "Use double braces around your arguments!" >&2
	echo "Example: \"0 4 * * 6\"" >&2
	echo ""
	exit 1
fi

read min hour dom mon dow extra <<< "$@"

if [ ! -z "$extra" ]; then
        echo ""
	echo "Error: Too many arguments! I don't know what to do with \"$extra\"!"
        echo "Example: \"0 4 * * 6\"" >&2
        echo ""
	exit 1;
fi

if [ -z "$min" ]; then
# if there is nothing to check
        echo ""
	echo "This script requires crontab schedule line as an argument!" >&2
        echo "Example: \"0 4 * * 6\"" >&2
        echo ""
	exit 1
fi


#### Main

## Breaks the input into fields, replaces all '*' with 'X', stores results in global variables
fixvars

# minute check
  for minslice in $(echo "$min" | sed 's/[,-]/ /g') ; do
    if ! validNum $minslice 60 ; then
      echo "Invalid minute value \"$minslice\""
      errors="$(( $errors + 1 ))"
    fi
  done

# hour check

  for hrslice in $(echo "$hour" | sed 's/[,-]/ /g') ; do
    if ! validNum $hrslice 24 ; then
      echo "Invalid hour value \"$hrslice\"" 
      errors="$(( $errors + 1 ))"
    fi
  done

# day of month check

  for domslice in $(echo $dom | sed 's/[,-]/ /g') ; do
    if ! validNum $domslice 31 ; then
      echo "Invalid day of month value \"$domslice\""
      errors="$(( $errors + 1 ))"
    fi
  done

# month check

  for monslice in $(echo "$mon" | sed 's/[,-]/ /g') ; do
    if ! validNum $monslice 12 ; then
      if ! validMon "$monslice" ; then
        echo "Invalid month value \"$monslice\""
        errors="$(( $errors + 1 ))"
      fi
    fi
  done

# day of week check

  for dowslice in $(echo "$dow" | sed 's/[,-]/ /g') ; do
    if ! validNum $dowslice 7 ; then
      if ! validDay $dowslice ; then
        echo "Invalid day of week value \"$dowslice\""
        errors="$(( $errors + 1 ))"
      fi
    fi
  done

  if [ $errors -gt 0 ] ; then
	exitstatus=1
	echo "$sourceline"
  fi

echo "Successfully validated cron schedule."
echo ""

exit $exitstatus
