#!/bin/bash

# CONFIGURATION
KEYTAB="/opt/kerberos/service_account.keytab"
PRINCIPAL="service_account@YOUR.DOMAIN.COM"
CCACHE="/tmp/krb5cc_service_account"
LIFETIME="10h"
RENEWABLE_LIFETIME="30d"
LOGFILE="/var/log/kerberos_renew.log"

# Ensure directory exists
mkdir -p "$(dirname "$CCACHE")"
mkdir -p "$(dirname "$LOGFILE")"

# Get new ticket if none exists or is expired
if ! klist -c "$CCACHE" -s; then
    echo "$(date) [INFO] Requesting new TGT" >> "$LOGFILE"
    kinit -k -t "$KEYTAB" -c "$CCACHE" -l "$LIFETIME" -r "$RENEWABLE_LIFETIME" "$PRINCIPAL"
else
    # Try renewing ticket
    echo "$(date) [INFO] Renewing TGT" >> "$LOGFILE"
    kinit -R -c "$CCACHE"
    if [ $? -ne 0 ]; then
        echo "$(date) [WARN] Renewal failed, requesting fresh TGT" >> "$LOGFILE"
        kinit -k -t "$KEYTAB" -c "$CCACHE" -l "$LIFETIME" -r "$RENEWABLE_LIFETIME" "$PRINCIPAL"
    fi
fi

# Make it executable:
# chmod +x /opt/kerberos/renew_kerberos.sh