#!/bin/bash

# A simple HTTP server written in bash.
# Avleen Vig, 2012-09-13

if [ "$(id -u)" = "0" ]; then
   echo "Hold on, tiger! Don't run this as root, k?" 1>&2
   exit 1
fi


DOCROOT=${DOCROOT:-/var/www/html}

REPLY_HEADERS=(
  "Date: $(date --rfc-2822)"
  "Expires: $(date --rfc-2822 --date='+5 hours')"
  "Server: bashttpd"
  )

function send_header {
    echo "HTTP/1.0 $*"$'\r'
    for x in "${REPLY_HEADERS[@]}"; do
      echo "$x"$'\r'
    done
    echo $'\r'
}

function bad_request {
    send_header 400 "Bad Request"
    exit
}

IFS=' ' read HTTP_METHOD URL_PATH HTTP_VER || bad_request
[[ "x$HTTP_METHOD" == xGET && "x$URL_PATH" == x/* ]] || bad_request
URL_PATH="$DOCROOT$URL_PATH"

# If URL_PATH contains
#   leading "." in a component,
#   "%",
# or isn't set, return 400.
if [[ "$URL_PATH" == */.* || "$URL_PATH" == *%* || -z "${URL_PATH}" ]]; then
    bad_request
fi

if [ -f ${URL_PATH} ]; then
    # regular file
    if [ ! -r ${URL_PATH} ]; then
        # unreadable
        send_header 403 Forbidden
    else
        # readable: send contents
        REPLY_HEADERS+=("Content-type: $(file --brief --mime-type "$URL_PATH")")
        REPLY_HEADERS+=("Content-length: $(stat -c%s "$URL_PATH")")
        send_header 200 OK
        cat "$URL_PATH"
    fi
elif [ -d "${URL_PATH}" ]; then
    # directory
    if [ ! -x "${URL_PATH}" ]; then
        # non-listable
        send_header 403 Forbidden
    else
        REPLY_HEADERS+=("Content-type: text/plain")
        send_header 200 OK
        ls -l "$URL_PATH"
    fi
else
    send_header 404 "Not Found"
fi
