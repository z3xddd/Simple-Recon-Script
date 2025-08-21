#!/bin/bash
#
# Author: Israel Comazzetto dos Reis

file=$1
current_dir=$(pwd)
checkpoint_dir="$current_dir/.recon_checkpoint"
mkdir -p "$checkpoint_dir"

AQUATONE_USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) Firefox/118.0"

if [ $# -eq 0 ]; then
    echo "Usage: ./recon.sh file"
    exit 1
fi

fetch_subdomains() {
    local domain=$1
    local outfile=$2
    tmpfile=$(mktemp)

    curl_sources=(
        "https://rapiddns.io/subdomain/$domain?full=1#result"
        "http://web.archive.org/cdx/search/cdx?url=*.$domain/*&output=text&fl=original&collapse=urlkey"
        "https://crt.sh/?q=%.$domain"
        "https://crt.sh/?q=%.%.$domain"
        "https://crt.sh/?q=%.%.%.$domain"
        "https://crt.sh/?q=%.%.%.%.$domain"
        "https://otx.alienvault.com/api/v1/indicators/domain/$domain/passive_dns"
        "https://www.threatcrowd.org/searchApi/v2/domain/report/?domain=$domain"
        "https://api.hackertarget.com/hostsearch/?q=$domain"
        "https://certspotter.com/api/v0/certs?domain=$domain"
        "https://spyse.com/target/domain/$domain"
        "https://tls.bufferover.run/dns?q=$domain"
        "https://dns.bufferover.run/dns?q=.$domain"
        "https://urlscan.io/api/v1/search/?q=$domain"
        "https://jldc.me/anubis/subdomains/$domain"
        "https://sonar.omnisint.io/subdomains/$domain"
        "https://riddler.io/search/exportcsv?q=pld:$domain"
        "https://securitytrails.com/list/apex_domain/$domain"
    )

    for src in "${curl_sources[@]}"; do
        curl -s -k --tcp-fastopen --tcp-nodelay "$src" >> "$tmpfile" &
    done
    wait

    grep -oE "[a-zA-Z0-9._-]+\.$domain" "$tmpfile" \
        | sed -e "s/\*\.$domain//g" -e "s/^\..*//g" \
        | sort -u \
        | anew "$outfile"

    rm -f "$tmpfile"
}

process_domain() {
    local domain=$1
    local output_prefix=$2
    echo "[*] Processando: $domain"

    assetfinder -subs-only "$domain" | anew "${output_prefix}_asset"
    subfinder -d "$domain" -silent -t 2000 | anew "${output_prefix}_sub"
    findomain -t "$domain" -q --threads 2000 | anew "${output_prefix}_find"
    fetch_subdomains "$domain" "${output_prefix}_curls"

    echo "$domain"
}

process_stage() {
    local stage_name=$1
    local input_file=$2
    local output_prefix=$3

    local progress_file="$checkpoint_dir/${stage_name}_progress"
    local done_file="$checkpoint_dir/${stage_name}_done"

    if [ -f "$done_file" ]; then
        echo "[!] Pulando $stage_name (jÃ¡ concluÃ­do)"
        return
    fi

    echo "## [+] $stage_name [+] ##"

    mapfile -t domains < <(awk '{print $1}' "$input_file")

    if [ -f "$progress_file" ]; then
        grep -vxFf "$progress_file" "$input_file" > "${input_file}.pending"
        mapfile -t domains < "${input_file}.pending"
    fi

    parallel -j 5 process_domain ::: "${domains[@]}" ::: "$output_prefix" | tee -a "$progress_file"

    if [[ $stage_name == "FIRST" ]]; then
        cat ${output_prefix}* | anew "${output_prefix}Total"
    else
        cat ${output_prefix}* "$input_file" | anew "${output_prefix}Total"
    fi

    touch "$done_file"
}

export -f fetch_subdomains
export -f process_domain
export AQUATONE_USER_AGENT
export current_dir

echo "###############################"
echo "####   RECON.SH STARTED   ####"
echo -e "###############################\n\n"

process_stage "FIRST" "$current_dir/$file" "domains_first"
process_stage "SECOND" "$current_dir/domains_firstTotal" "domains_second"
process_stage "FINAL" "$current_dir/domains_secondTotal" "domains_final"

echo "###############################"
echo "####   RECON.SH FINISHED   ####"
echo "###############################"
