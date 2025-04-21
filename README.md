#ipv4
sh ddns v4 token v4name#mydomain.com auto
#ipv6
sh ddns v6 token v6name#mydomain.com auto auto
#ipv4 and ipv6
sh ddns v4v6 token v46name#mydomain.com auto auto
#cname
sh ddns CNAME token cname#mydomain.com www.google.com
#txt
sh ddns TXT token ctxt#mydomain.com "Welcome to my txt record"
