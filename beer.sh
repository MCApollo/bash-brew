#!/usr/bin/env bash
set -e
set -o pipefail

cfversion='1561.00'

function download() {
    local TEMP=$(mktemp)
    curl https://formulae.brew.sh/api/formula.json --progress-bar > ${TEMP}

    cat ${TEMP} | jq '[ .[] |
    {
        name: .name,
        version: .versions.stable,
        description: .desc,
        homepage: .homepage,
        depends: .dependencies,
        conflicts: .conflicts_with,
        build_dependencies: .build_dependencies
    } ]
    ' > ${ROOT}/small-db.json
    echo "Updated small-db.json."
}

function directory() {
    local name version description
    while read -r name version description; do
        [[ -d "${name}" && ! -f "${name}"/.beer ]] && continue
        # Version check
        if test -d "${name}" && dpkg --compare-versions $(cat "${name}"/_metadata/version) lt ${version} &>/dev/null; then
            echo "Updating ${name} to ${version}"
            echo "${version}" > "${name}"/_metadata/version
            (
              cd "${name}"
              rm -f ./*.{tar.{gz,xz,bz2,lz},tgz} ./*.zip || :
              grab "${name}" # Download tar
            )
        fi

        # Hack to remove qoutes from the input:
        description="${description%\"}"
        description="${description#\"}"
        # Create a new formula.
        echo -ne "==> ${name}\r"
        # Gen. basic things.
        mkdir -p "${name}"/_metadata
        printf "${name}" > "${name}"/_metadata/name
        printf "${version}" > "${name}"/_metadata/version
        printf "${description}" > "${name}"/_metadata/description
        touch "${name}"/.beer
        # Clear line.
        echo -ne "$(tput el || echo '\E[K')"
    done <<< $(cat ${ROOT}/small-db.json | jq -r '.[] | "\(.name) \(.version) \"\(.description)\""')
}

function grab() {
    local regex url line name TEMP depends
    regex='(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'
    name="${1:-$(realpath .)}"
    name="${name##*/}"

    TEMP=$(mktemp)
    curl https://raw.githubusercontent.com/Homebrew/homebrew-core/master/Formula/${name}.rb --progress-bar > ${TEMP}

    while read -r line; do
        [[ "${line}" = \#* || -n ${url} ]] && continue
        if [[ -z ${url} && ${line} == url* ]]; then
            url=( ${line} )
            url="${url[1]//\"}"
        fi
    done < ${TEMP}

    if [[ ${url} =~ ${regex} ]]; then
        (
        [[ -d "${name}" ]] && cd "${name}"
        curl -L -O "${url}" 2>/dev/null
        )
    else
        echo "Unable to vaildate URL!" 1>&2
        return 1
    fi

    [[ ! -f ${PWD}/.beer ]] && return
    if [[ ! -f _metadata/section ]]; then
      if grep 'library' _metadata/description &>/dev/null; then
        printf "Development" > _metadata/section
        printf "purpose::library" > _metadata/tags
      elif grep 'network' _metadata/description &>/dev/null; then
        printf "Networking" > _metadata/section
        printf "purpose::console" > _metadata/tags
      else
        printf "Utilities" > _metadata/section
        printf "purpose::console" > _metadata/tags
      fi
    fi
    # Check for files and create them
    [[ ! -f _metadata/role ]] && echo "hacker" > _metadata/role
    [[ ! -f _metadata/in.* ]] && touch _metadata/in.${cfversion}
    ${ROOT:-.}/beverage.py ${TEMP} # -> will check for make.sh

    depends=( $(cat ${ROOT}/small-db.json | jq -r ".[] | select(.name == \"${name}\") | .depends | @sh") )
    depends=( ${depends[@]//\'} )
    for d in ${depends[@]}; do
        if [[ -d ../${d} ]]; then
            ln -rs ../${d} _metadata/${d}.dep
        else
            [[ -f _metadata/depends ]] && continue
            echo "Can't find depend ${d}." 1>&2
            echo "${d}" >> _metadata/depends
        fi
    done

}

function urlopen() {
    local name url
    name=${1:-$(realpath .)}
    name=${name##*/}
    url=https://github.com/Homebrew/homebrew-core/blob/master/Formula/${name}.rb 
    uiopen ${url} || xdg-open ${url} || open ${url} || \
    {
        echo "Failed to open URL!"
        return 1
    }
}

if (( !$# )); then
    cat <<EOF 
Usage:  download    : Update the db.json.
        directory   : Update or create directories.
        grab <name> : Grab the recent tar.
        urlopen <name> : Open a formula in browser.
EOF
    exit 1
fi

func="$1"; shift
if ! declare -f ${func} &>/dev/null; then
    echo "Unknown knowns." 1>&2
    exit 1
fi

export ROOT=$(dirname $(realpath ${0}))
${func} "$@"