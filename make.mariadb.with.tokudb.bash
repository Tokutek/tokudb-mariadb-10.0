#!/bin/bash

function usage() {
    echo "make.mariadb.with.tokudb.bash mariadb-10.0.14 tokudb-7.5.1"
}

# download a github repo as a tarball and expand it in a local directory
# arg 1 is the github repo owner
# arg 2 is the github repo name
# arg 3 is the github commit reference
# the local directory name is the same as the github repo name
function get_repo() {
    local owner=$1; local repo=$2; local ref=$3

    curl -L https://api.github.com/repos/$owner/$repo/tarball/$ref --output $repo.tar.gz
    if [ $? -ne 0 ] ; then test 1 = 0; return; fi
    mkdir $repo
    if [ $? -ne 0 ] ; then test 1 = 0; return; fi
    tar --extract --gzip --directory $repo --strip-components 1 --file $repo.tar.gz
    if [ $? -ne 0 ] ; then test 1 = 0; return; fi
    rm -rf $repo.tar.gz
}

function get_source_from_repos() {
    local mariadbserver=$1; local tokudb=$2; local buildtype=$3

    # get percona server source
    get_repo Tokutek mariadb-10.0 $mariadbserver
    if [ $? -ne 0 ] ; then test 1 = 0; return; fi
    mv mariadb-10.0 $mariadbserver

    get_repo Tokutek tokudb-engine $tokudb
    if [ $? -ne 0 ] ; then test 1 = 0; return; fi
    mv tokudb-engine/storage/tokudb $mariadbserver/storage
    rm -rf tokudb-engine

    get_repo Tokutek ft-index $tokudb
    if [ $? -ne 0 ] ; then test 1 = 0; return; fi
    mv ft-index $mariadbserver/storage/tokudb
}

function build_tarballs_from_source() {
    local mariadbserver=$1; local tokudb=$2; local buildtype=$3

    # build
    mkdir $mariadbserver-$buildtype
    pushd $mariadbserver-$buildtype
    if [ $? -ne 0 ] ; then test 1 = 0; return; fi
    cmake_args="-DBUILD_CONFIG=mysql_release"
    if [ $buildtype = "release" ] ; then 
        cmake_args="$cmake_args -DCMAKE_BUILD_TYPE=RelWithDebInfo"
    fi
    if [ $buildtype = "debug" ] ; then
        cmake_args="$cmake_args -DCMAKE_BUILD_TYPE=Debug"
    fi
    cmake_args="$cmake_args -DWITH_JEMALLOC=no"
    if [ $buildtype != "release" ] ; then
        cmake_args="$cmake_args -DEXTRA_VERSION=-$tokudb-$buildtype"
    else
        cmake_args="$cmake_args -DEXTRA_VERSION=-$tokudb"
    fi
    cmake $cmake_args ../$mariadbserver
    if [ $? -ne 0 ] ; then test 1 = 0; return; fi
    make -j8 package
    if [ $? -ne 0 ] ; then test 1 = 0; return; fi
    for x in *.gz; do
        md5sum $x >$x.md5
    done
    popd
}

function make_target() {
    local mariadbserver=$1; local tokudb=$2; local buildtype=$3

    local builddir=$mariadbserver-$tokudb-$buildtype
    rm -rf $builddir
    mkdir $builddir
    if [ $? -ne 0 ] ; then test 1 = 0; return; fi
    pushd $builddir
    get_source_from_repos $mariadbserver $tokudb $buildtype
    if [ $? -ne 0 ] ; then test 1 = 0; return; fi
    build_tarballs_from_source $mariadbserver $tokudb $buildtype
    if [ $? -ne 0 ] ; then test 1 = 0; return; fi
    popd
    mv $builddir/$mariadbserver-$buildtype/*.gz* .
    # rm -rf $builddir
}

if [ $# -lt 2 ] ; then usage; exit 1; fi
mariadbserver=$1
tokudb=$2
buildtype=
if [ $# -eq 3 ] ;then buildtype=$3; fi

if [ -z "$buildtype" -o "$buildtype" = release ] ; then make_target $mariadbserver $tokudb release; fi
if [ -z "$buildtype" -o "$buildtype" = debug ] ; then make_target $mariadbserver $tokudb debug; fi
if [ -z "$buildtype" -o "$buildtype" = debug-valgrind ] ; then make_target $mariadbserver $tokudb debug-valgrind; fi
