#!/bin/bash
# Sets owner of domain argument
domain_owner=$(/scripts/whoowns $1)

# Backs up zone
cp /var/named/${1}.db{,.$(date +%s).bak}

# Finds line number of default._domainkey line
dkim_line=$(egrep -n "^default._domainkey\s" /var/named/$1.db | cut -d: -f1)

create_dkim() {
openssl genrsa -out /var/cpanel/domain_keys/private/$1 2048 && \
openssl rsa -in /var/cpanel/domain_keys/private/$1 -pubout -out \
/var/cpanel/domain_keys/public/$1
dkim_record="v=DKIM1;  k=rsa; p="$(awk '$0 !~ / KEY/{printf $0 }' /var/cpanel/domain_keys/public/$1 )\"
}

zone_edit_call() {
cpapi2 --user=$domain_owner \
ZoneEdit edit_zone_record \
Line=$dkim_line \
domain=$1 \
name='default._domainkey' \
type=TXT \
txtdata=$2 \
ttl=14400 \
class=IN
}

create_dkim $1

# split dkim into dkim 1 and 2 here

zone_edit_call $1 #put dkim chunk 1 here

dkim_line=$[dkim_line+1]

zone_edit_call $1 #put dkim chunk 2 here
