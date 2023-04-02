#! /usr/bin/env nix-shell
#! nix-shell -i bash -p nix-prefetch-github

RELEASES_DIR="$PWD/.releases"
printf "Saving releases to %s\n" "$RELEASES_DIR" 1>&2
mkdir -p $RELEASES_DIR

function github_curl() {
    curl \
	--header "Accept: application/vnd.github+json" \
	--header "X-GitHub-Api-Version: 2022-11-28" \
	"$@"
}

function fetch_release_tags() {
    local url="https://api.github.com/repos/rust-lang/rust-analyzer/releases?page=1"

    function next_page_url() {
	github_curl --silent --include --request HEAD "$@" \
	    | jq --raw-input --raw-output \
		 'capture("^link:.*?<(?<next>[^>]*?)>;\\s+rel=\"next\"") | .next'
    }

    while [[ -n "$url" ]];
    do
	printf "fetching '%s'\n" "$url" 1>&2 
	github_curl --silent "$url"
	url="$(next_page_url "$url")"
    done | jq --compact-output --raw-output '.[] | .tag_name'
}

function fetch_release() {
    local rev="$1"
    local release_file="${RELEASES_DIR}/${rev}.json"
    local url="https://github.com/rust-lang/rust-analyzer/archive/refs/tags/${rev}.zip"
    

    if [[ ! -f "$release_file" || "$rev" == "nightly"  ]];
    then
	printf "RELEASE %s ... FETCHING\n" "$rev" 1>&2

	nix store prefetch-file --json "$url" 2>/dev/null \
	    | jq --arg url "$url" --arg rev "$rev" '{ $url, $rev, hash }' > "$release_file"

	printf "RELEASE %s ... FETCHED\n" "$rev" 1>&2
    else
	printf "RELEASE %s ... FETCHED\n" "$rev" 1>&2
    fi
}

function fetch_releases() {
    while read -r rev
    do
	fetch_release "$rev" "$url" &

	[[ $(jobs | wc -l) -gt $(nproc) ]] && wait -n
    done

    wait
}


fetch_release_tags | fetch_releases
