#! /bin/bash

# Copyright 2015 tsuru authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

test -d tmp || mkdir tmp
git clone https://github.com/tsuru/tsuru.git tmp/tsuru
pushd tmp/tsuru
git checkout $COMMIT
pip install -r requirements.txt
popd
pushd tmp/tsuru/docs
make html
popd
test -d $VERSION || mkdir $VERSION
cp -rp tmp/tsuru/docs/_build/html/ $VERSION
