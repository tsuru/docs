#!/bin/bash

# Copyright 2016 tsuru authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

set -e

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
    releases_file=`pwd`/releases.py

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

generate master master
generate latest 1.2.0
generate stable 1.2.0
generate 1.2.0 1.2.0
generate 1.1.1 1.1.1
generate 1.1.0 1.1.0
generate 1.0.1 1.0.1
generate 1.0.0 1.0.0
generate 0.13 0.13.0
generate 0.12 0.12.4
generate 0.11 0.11.3
generate 0.10 0.10.3
generate 0.9 0.9.1
generate 0.8 0.8.2
generate 0.7 0.7.2
generate 0.6 0.6.2
generate 0.5 0.5.3
generate 0.4 0.4.0
generate 0.3 0.3.12
generate 0.2 0.2.12
generate 0.1 0.1.0

for job in `jobs -p`; do
    wait $job || exit 1
done

copy_deploy_files

clean
