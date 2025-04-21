#!/bin/bash
get_wan_ip(){
    ip4=$(curl -s -m 5 -4 http://api64.ipify.org/)
    echo $ip4 | grep -F "." >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo $ip4
    else
        echo ""
    fi
}
get_wan_ip6(){
    ip6=$(curl -s -m 5 -6 http://api64.ipify.org/)
    echo $ip6 | grep -F ":" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo $ip6
    else
        echo ""
    fi
}
dns_isupdated(){
    dns_line=$(nslookup $domain2 lia.ns.cloudflare.com 2>/dev/null)
    for line in $dns_line
    do
        if [ "$line" = "$checkip" ]; then return 1; fi
    done
    return 0
}
func=$1 ; token=$2 ; domaininfo=$3 ; ip=$4 ; ipv6=$5
echo $domaininfo | grep -F "#" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    domain=$(echo $domaininfo | awk -F '#' '{print $NF}')
    domain2=$(echo $domaininfo | sed -e 's/#/./gi')
else
    domain=${domaininfo#*.}
    domain2=$domaininfo
fi
if [ "$func" = "" ]; then echo "wrong parameter (v4v6 token domain2 ip ipv6)" ; exit 1 ; fi
if [ "$ip" = "auto" ]; then ip=""; fi
if [ "$ipv6" = "auto" ]; then ipv6=""; fi
domain2=$(echo $domain2 | sed 's/@.//g')
types=""
proxied=false ; echo $func | grep -F "#" >/dev/null 2>&1
if [ $? -eq 0 ]; then proxied=true; fi
echo $func | grep -F "v4" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    htype=1
    if [ "$ip" = "" ]; then ip=$(get_wan_ip); fi
    if [ "$ip" != "" ]; then
        if [ "$proxied" = "true" ];then
            types=$types"A "
        else
            checkip=$ip
            if dns_isupdated ; then
                types=$types"A "
            else
                echo "$domain2 A Record is ready"
            fi
        fi
    fi
fi
echo $func | grep -F "v6" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    htype=1
    if [ "$ipv6" = "" ]; then ipv6=$(get_wan_ip6); fi
    if [ "$ipv6" != "" ]; then
        if [ "$proxied" = "true" ];then
            types=$types"AAAA "
        else
            checkip=$ipv6
            if dns_isupdated ; then
                types=$types"AAAA "
            else
                echo "$domain2 AAAA Record is ready"
            fi
        fi
    fi
fi
if [ "$types" = "" ] && [ "$htype" = "1" ]; then exit 0; fi
if [ "$types" = "" ]; then types=$(echo $func | sed -e 's/#//gi'); fi
html=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$domain" -H "Authorization: Bearer $token" -H "Content-Type:application/json")
zoneid=$(echo $html | sed -e 's/,"status":"/#\n/g' | grep -F "\"$domain\"" | awk -F '"id":"' 'NR==1{print $NF}' | cut -f 1 -d '"')
if [ "$zoneid" = "" ]; then echo "no zoneid" ; exit 2 ; fi
for type in $types
do
    newip=$ip;newinfo=""
    if [ "$type" = "AAAA" ]; then newip=$ipv6; fi
    if [ "$type" = "TXT" ]; then newip="\\\"$newip\\\""; fi
    html=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records?name=$domain2&type=$type" -H "Authorization: Bearer $token" -H "Content-Type:application/json")
    echo $html | grep -F "\"success\":true" | grep -v "grep" >/dev/null 2>&1
    if [ $? -ne 0 ]; then echo "no data" ; continue ; fi
    domain2id=$(echo $html | awk -F '"id":"' '{print $2}' | cut -f 1 -d '"')
    if [ "$domain2id" = "" ]; then
        html=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records" -H "Authorization: Bearer $token" -H "Content-Type:application/json" --data "{\"type\":\"$type\",\"name\":\"$domain2\",\"content\":\"$newip\",\"ttl\":1,\"proxied\":$proxied}")
    else
        ready=false
        echo $html | grep -F "\"content\":\"$newip\"" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo $html | grep -F "\"proxied\":$proxied" >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                ready=true
            fi
        fi
        if [ "$ready" = "true" ]; then
            html='"success":true' ; newinfo="(ready)"
        else
            html=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$domain2id" -H "Authorization: Bearer $token" -H "Content-Type:application/json" --data "{\"id\":\"$zoneid\",\"type\":\"$type\",\"name\":\"$domain2\",\"content\":\"$newip\",\"ttl\":1,\"proxied\":$proxied}")
        fi
    fi
    echo $html | grep -F "\"success\":true" | grep -v "grep" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "$domain2 $type Record $newip update fail"
        echo $html
    else
        echo "$domain2 $type Record $newip update$newinfo success"
    fi
done
