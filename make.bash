#!/usr/bin/env bash

# Copyright 2016 tsuru authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

set -e

RELEASES_FILE="tmp/releases.py"

install () {
    test -d tmp || mkdir tmp
    git clone https://github.com/tsuru/tsuru.git tmp/tsuru
    pushd tmp/tsuru
    pip install -r requirements.txt
    popd
    mkdir -p build
    mkdir -p tmp/tsuru/worktree
}

# generate version commit
generate () {
    version=$1
    commit=$2
    worktree="worktree/${version}_${commit}"
    releases_file="`pwd`/${RELEASES_FILE}"

    pushd tmp/tsuru
    if [[ $commit == "master" ]]; then
        ln -s `pwd` ${worktree}
    else
        git worktree add ${worktree} $commit
        cp -rf docs/theme/sphinx_rtd_theme_ext ${worktree}/docs/theme/
        cp -rf docs/conf.py ${worktree}/docs/
        cp -rf docs/handlers.yml ${worktree}/docs/
    fi
    cp -rf ${releases_file} ${worktree}/docs/
    sed -ie "s/^\(version \= \).*$/\1'${commit}'/" ${worktree}/docs/conf.py
    sed -ie "s/^\(release \= \).*$/\1'${commit}'/" ${worktree}/docs/conf.py
    popd

    build ${version} ${worktree} &
}

build () {
    version=$1
    worktree=$2

    pushd tmp/tsuru/${worktree}/docs
    make html
    popd
    cp -rp tmp/tsuru/${worktree}/docs/_build/html/ build/$version
}

function copy_deploy_files {
    cp nginx.conf build
    cp tsuru.yaml build
}

clean () {
    rm -rf tmp
}

install

pushd tmp/tsuru
GSORT="$(which gsort || which sort)"
sortedtags="$(git tag | ${GSORT} -V)"
popd

stable=""
latest=""
declare -A generate_versions
declare -a generate_keys

for t in ${sortedtags}; do
    is_rc="$([[ $t =~ .*-.+ ]] && echo true || echo '')"
    [[ $is_rc != true ]] && stable=$t
    normalized=$(echo $t | perl -pe 's/([0-9]+\.[0-9]+)\..*/\1/')
    [[ $normalized =~ .*-rc ]] && continue
    current=${generate_versions[$normalized]}
    if [[ $current != "" ]] && [[ $is_rc == true ]] && [[ ! $current =~ .*-.+ ]]; then
        continue
    fi
    generate_versions[$normalized]=$t
    latest=$t
done

for docv in "${!generate_versions[@]}"; do
    generate_keys+=($docv)
done

IFS=$'\n' sorted=($(${GSORT} -r -V <<<"${generate_keys[*]}"))
unset IFS
echo "RELEASES = [" > ${RELEASES_FILE}
for docv in ${sorted[*]}; do
    echo "\"$docv\"," >> ${RELEASES_FILE}
done
echo "]" >> ${RELEASES_FILE}

echo "Will generate master, tag: master"
echo "Will generate stable, tag: ${stable}"
echo "Will generate latest, tag: ${latest}"
for docv in ${sorted[*]}; do
    echo "Will generate $docv, tag: ${generate_versions[$docv]}"
done

generate master master
generate stable $stable
generate latest $latest
for docv in ${sorted[*]}; do
    generate $docv ${generate_versions[$docv]}
done

for job in `jobs -p`; do
    wait $job || exit 1
done

copy_deploy_files

clean
