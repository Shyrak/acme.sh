#!/usr/bin/env sh
# FreeMyIp DNS support (https://freemyip.com/)
# FMIP_TOKEN="API token"
#
####################  Constants ####################

FMIP_TXT_UPDATE_TIME=60 #Time in seconds required by FreeMyIp to update the TXT record. Provider recomends 60 seconds. (https://freemyip.com/help) 

####################  Public functions ####################

# Usage: dns_freemyip_add  _acme-challenge.www.domain.com   "XKrxpRBosdIKFzxW_CT3KLZNf6q0HG9i01zxXp5CPBs"
# Used to add txt record
dns_freemyip_add() {
  fulldomain=$1
  txtvalue=$2

  FMIP_TOKEN=_get_token

  if [ -z $FMIP_TOKEN ]; then
    _err "Unable to add TXT record"
    return 1
  fi

  #Get the TLD
  _get_root "$fulldomain"
  if [ -z "$_domain" ]; then
    _err "invalid domain"
    return 1
  fi

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
  _get_root "$fulldomain"
  if [ -z "$_domain" ]; then
    _err "invalid domain"
    return 1
  fi
}
####################  Private functions ####################

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

# usage: token domain value
# Empty value for clearing
_set_txt_record() {
  token=$1
  domain=$2
  txt=$3
  if [ -z "$txt" ]; then
    txt="NULL"
  fi

  _get "https://freemyip.com/update?token=$token&domain=$domain&txt=$txt"
}

# usage: domain
# All subdomains share the same TXT values, so we only need the root user domain
#_acme-challenge.www.user.freemyip.com
#returns
# _domain=user.freemyip.com
_get_root() {
  _domain="$(echo "$1" |_egrep_o "[\w-]+[.]freemyip[.]com")"
}