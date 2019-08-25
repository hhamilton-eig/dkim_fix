#!/bin/bash
# Sets owner of domain argument
domain_owner=$(/scripts/whoowns ${1})

# Backs up zone + removes existing DKIM
sed -i.$(date +%s).bak '/default._domainkey\s/d' /var/named/${1}.db

create_dkim() {
openssl genrsa -out /var/cpanel/domain_keys/private/${1} 2048 && \
openssl rsa -in /var/cpanel/domain_keys/private/${1} -pubout -out \
/var/cpanel/domain_keys/public/${1}
dkim_record="v=DKIM1; k=rsa; p="$(awk '$0 !~ / KEY/{printf $0 }' /var/cpanel/domain_keys/public/$1 )""
}

zone_edit_call() {
cpapi2 --user=$domain_owner \
ZoneEdit add_zone_record \
domain=$1 \
name='default._domainkey' \
type=TXT \
txtdata=$2 \
ttl=14400 \
class=IN
}

urlencodepipe() {
  local LANG=C; local c; while IFS= read -r c; do
    case $c in [a-zA-Z0-9.~_-]) printf "$c"; continue ;; esac
    printf "$c" | od -An -tx1 | tr ' ' % | tr -d '\n'
  done <<EOF
$(fold -w1)
EOF
  echo
}
urlencode() { printf "$*" | urlencodepipe ;}

# split dkim into dkim 1 and 2 here
create_dkim $1 &>/dev/null
dkim_chunk_1=${dkim_record:0:249}
dkim_chunk_2=${dkim_record:250}

# URL encodes dkim chunks
dkim_chunk_1=$(urlencode $dkim_chunk_1)
dkim_chunk_2=$(urlencode $dkim_chunk_2)

# Pops dkim chunk 1 into zone file
zone_edit_call $1 $dkim_chunk_1 &>/dev/null

# Pops dkim chunk 2 into zone file below chunk 1
zone_edit_call $1 $dkim_chunk_2 &>/dev/null
