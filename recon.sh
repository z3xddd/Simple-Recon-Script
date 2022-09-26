#!/bin/bash
#
# RECON.SH

DOMAIN=$1

if [ $# -eq 0 ]
  then
    echo "#### RECON.SH ####"
    echo "##################"
    echo "------ by: @z3xddd"
    echo "Usage: ./recon.sh domain.com"
    echo ""
else
    echo "## RECON.SH STARTING ##"
    assetfinder -subs-only $DOMAIN | anew domains_asset
    amass enum -d $DOMAIN -passive -config ~/.config/amass/config.ini | anew domains_amass_passive
    amass enum -d $DOMAIN -active -brute -w ~/Lists/SecLists/Discovery/DNS/deepmagic.com-prefixes-top50000.txt -config ~/.config/amass/config.ini | anew domains_amass_active
    subfinder -d $DOMAIN | anew domains_sub
    findomain -t $DOMAIN | anew domains_find
    echo "$DOMAIN" | haktrails subdomains | anew domains_hak
    chaos -d $DOMAIN | anew domains_chaos
    cat domains* | anew domainsTotal1.txt
    amass enum -nf domainsTotal1.txt -passive -config ~/.config/amass/config.ini | anew domains_amass_passive2
    amass enum -nf domainsTotal1.txt -active -brute -w ~/Lists/SecLists/Discovery/DNS/deepmagic.com-prefixes-top50000.txt -config ~/.config/amass/config.ini | anew domains_amass_active_2
    cat domains_amass_passive2 domains_amass_active_2 | anew domainsTotal2
    cat domainsTotal2 | haktrails subdomains | anew domains_hak2
    cat domainsTotal1.txt domainsTotal2 domains_hak2 | anew webTotal
fi
