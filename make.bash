#! /bin/bash

# Copyright 2015 tsuru authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.


install () {
    test -d tmp || mkdir tmp
    git clone https://github.com/tsuru/tsuru.git tmp/tsuru
    pushd tmp/tsuru
    pip install -r requirements.txt
    popd
}

# generate version commit
generate () {
    version=$1
    commit=$2
    mkdir -p build

    pushd tmp/tsuru
    git checkout $commit
    popd
    pushd tmp/tsuru/docs
    make html
    popd
    cp -rp tmp/tsuru/docs/_build/html/ build/$version
    pushd tmp/tsuru/docs
    make clean
    popd
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
generate latest 0.13.0
generate stable 0.13.0
generate 0.13 0.13.0
generate 0.12 0.12.4
generate 0.11 0.11.3
generate 0.10 0.10.3
generate 0.9 0.9.1
generate 0.8 0.8.2
generate 0.7 0.7.2
generate 0.6 0.6.2
generate 0.5 0.5.3
generate 0.4 0.4
generate 0.3 0.3.12
generate 0.2 0.2.12
generate 0.1 0.1.0

copy_deploy_files

clean
