#!/usr/bin/env sh
# FreeMyIp DNS support (https://freemyip.com/)
#
# FMIP_TOKEN="xxxx"  API token
#
####################  DOCUMENTATION  ####################
# This DNS API interfaces via query params. Each call to the API replaces the previous state and all subdomains share the same TXT pool.
# FreeMyIP requires a DNS update time of 60 seconds.
#
# LIMITATIONS
# - DNS alias is not supported
# - FreeMyIp supports a single TXT record. Wildcard certificates are not supported, as two concurrent TXT records are required
# - FreeMyIp shares all TXT records between all subdomains. Multiple subdomain registration is not supported. (Might be when multiple TXT records are supported)
#
# FreeMyIp is probably going to support multiple TXT records, registered by using multiple identical query params. Once the job is done, i'll update this script
#
####################  REQUIRED GITHUB FLAGS ####################
# TEST_DNS_NO_WILDCARD=1
# TEST_DNS_NO_SUBDOMAIN=1
# TEST_DNS_SLEEP=60
# TEST_DNS=dns_freemyip
####################  PUBLIC FUNCTIONS  ####################

# Usage: dns_freemyip_add  _acme-challenge.www.domain.com   "XKrxpRBosdIKFzxW_CT3KLZNf6q0HG9i01zxXp5CPBs"
# Used to add txt record
dns_freemyip_add() {
  fulldomain=$1
  txtvalue=$2

  _info "Using FreeMyIP"
  _debug fulldomain "$fulldomain"
  _debug txtvalue "$txtvalue"

  if ! _get_token; then
    _err "Unable to add TXT record"
    return 1
  fi

  #Get the TLD
  domain=_get_root "$fulldomain"
  if [ -z "$domain" ]; then
    _err "Invalid domain"
    return 1
  fi

  # TODO: Allow multiTXT adding old values
  # Get current txt status
  _answers="$(_ns_lookup "$domain" TXT)" #'"Answer":["name":"***","type":16,"TTL":62,"data":"\"myothertext\""]'

  # /TODO

  _set_txt_record "$FMIP_TOKEN" "$domain" "$txtvalue"

}

# Usage: dns_freemyip_rm fulldomain txtvalue
# Used to remove the txt record after validation
dns_freemyip_rm() {
  fulldomain=$1
  txtvalue=$2

  if ! _get_token; then
    _err "Unable to remove TXT record"
    return 1
  fi

  #Get the TLD
  domain=_get_root "$fulldomain"
  if [ -z "$domain" ]; then
    _err "Invalid domain"
    return 1
  fi

  # TODO: Allow multiTXT adding old values
  # Get current txt status
  _answers="$(_ns_lookup "$domain" TXT)" #'"Answer":["name":"***","type":16,"TTL":62,"data":"\"myothertext\""]'

  # /TODO

  _set_txt_record "$FMIP_TOKEN" "$domain" "NULL"

}
####################  PRIVATE FUNCTIONS  ####################

# Get the stored authentication token
# sets: FMIP_TOKEN
# returns: 1 if error, 0 if success
_get_token() {
  _info "Checking credentials"
  FMIP_TOKEN="${FMIP_TOKEN:-$(_readaccountconf_mutable FMIP_TOKEN)}"

  if [ -z "$FMIP_TOKEN" ]; then
    _err "You did not specify the FreeMyIp token yet."
    _err "Please export as FMIP_TOKEN and try again."
    return 1
  else
    #save the credentials to the account conf file.
    _saveaccountconf_mutable FMIP_TOKEN "$FMIP_TOKEN"
    return 0
  fi
}

# Set the TXT records in the FreeMyIp API. The API replaces all TXT records every call, so all records that should exist must be sent every call
# params: [$1]token [$2]domain [$3..$#]:TXT records
# returns: 1 if error, 0 if success
_set_txt_record() {
  token=$1
  domain=$2
  query="https://freemyip.com/update?token=$token&domain=$domain"

  txt=0 #Required so SPELLCHECK doesn't complain. Replaced by eval as per POSIX SH recomendations
  i=3
  while [ $i -le $# ]; do
    eval "txt=\$$i"
    query="${query}&txt=${txt}"
    i=$((i + 1))
  done

  _info "Setting TXT values for domain ${domain}"
  _debug "Full URL: ${query}"

  #Throttle queries until OK
  i=0
  while [ $i -le 5 ]; do
    _debug "Set attempt ${domain} $i/5"
    _get "${query}" | grep OK && return 0
    _sleep 1
    i=$((i + 1))
  done

  _err "Failed to set TXT value. Server does not say 'OK'"
  return 1
}

# params: [$1]domain
# All subdomains share the same TXT values, so we only need the root user domain
# params: [$1] fulldomain (ie:_acme-challenge.www.user.freemyip.com)
# returns: root domain (ie: user.freemyip.com)
_get_root() {
  return "$(echo "$1" | _egrep_o "[\w-]+[.]freemyip[.]com")"
}
