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
    #sed 's/$/\r/' <<<"HTTP/1.0 $*"$'\n'"$REPLY_HEADERS"
}

function bad_request {
    send_header 400 "Bad Request"
    exit
}

IFS=' ' read HTTP_METHOD URL_PATH HTTP_VER || bad_request
[[ GET == $HTTP_METHOD ]] || bad_request
URL_PATH="$DOCROOT$URL_PATH"

# If URL_PATH contains
#   leading "." in a component,
#   "%",
# or isn't set, return 400.
if [[ "$URL_PATH" == */.* || "$URL_PATH" == *%* || -z "${URL_PATH}" ]]; then
    bad_request
fi

# Check the URL requested.
# If it's a text file, serve it directly.
# If it's a binary file, base64 encode it first.
# If it's a directory, perform an "ls -la".
# Otherwise, return a 404.
if [ -f ${URL_PATH} -a -r ${URL_PATH} ]; then
    exec 3<"$URL_PATH"
    REPLY_HEADERS+=("Content-type: $(file --brief --mime-type "$URL_PATH")")
    REPLY_HEADERS+=("Content-length: $(stat -c%s "$URL_PATH")")
elif [ -f ${URL_PATH} -a ! -r ${URL_PATH} ]; then
    send_header 403 Forbidden
    exit
elif [ -d "${URL_PATH}" ]; then
    if [ ! -x "${URL_PATH}" ]; then
        send_header 403 Forbidden
        exit
    fi
    exec 3< <(ls -l "$URL_PATH")
    REPLY_HEADERS+=("Content-type: text/plain")
else
    send_header 404 "Not Found"
    exit
fi

send_header 200 OK
cat <&3
