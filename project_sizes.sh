#!/bin/bash

begin_notebook=$SECONDS

# number of commits
ncommits() { git rev-list --first-parent ${1:-HEAD} | wc -l; }
export -f ncommits
ncommitters() { git shortlog --first-parent -sc ${1:-HEAD} | wc -l; }
export -f ncommitters
nauthors() { git shortlog --first-parent -sa ${1:-HEAD} | wc -l; }
export -f nauthors

# interval between sampled commits
mod() { # how many commits do I skip to get $1 points?
    local npoints=${1:-1}  # default to every commit
    local ncmts=$(ncommits)
    echo $(( ncmts/npoints ))
}
export -f mod
# SHA1s of the sample commits
only-every() { awk "(NR-1)%$1 == 0"; }
export -f only-every
sample-revs() {
    git rev-list --first-parent --abbrev-commit --reverse $DEFAULT_BRANCH |  # listed from first to last
        only-every $(mod $1)
}
export -f sample-revs

# constants used elsewhere
set-globals() {
    export DEFAULT_BRANCH=$(basename $(git symbolic-ref --short refs/remotes/origin/HEAD))
    export FIRST_COMMIT=$(git rev-list --first-parent --reverse $DEFAULT_BRANCH | head -1)  # initialize per repo
    export NPOINTS=10
    export NPOINTS=1000
    export SPW=$(( 60*60*24*7 ))  # calculate and save seconds-per-week as a shell constant
}

# an absolute timestamp, in seconds-from-the-epoch
commit-time() { git log -1 --format=%ct $1; }
export -f commit-time
# seconds between the first commit and the second
seconds-between() { echo $(($(commit-time $2) - $(commit-time $1))); }
export -f seconds-between

# and finally, the function we need: seconds from the first commit.
timestamp() {
    seconds-between $FIRST_COMMIT $1
}
export -f timestamp

spw() { echo "scale=2; $1/$SPW" | bc; }
export -f spw
timestamp-in-weeks() {
    spw $(timestamp $1)
}
export -f timestamp-in-weeks

iterate-commits() {
    cd $DIR.$3
    local sampled_commits=$(sample-revs $1 | wc -l)
    local repo_window=$(($sampled_commits/($NREPOS-1)))
    local window_start=$(echo 1+'(('$3-1'))*'$repo_window | bc)
    local window_end=$(echo $repo_window+'(('$3-1'))'*$repo_window | bc)
    local commit_list=$(echo $(sample-revs $1) | sed -n "${window_start},${window_end}p")
    for commit in $commit_list; do
        echo $(timestamp-in-weeks $commit) ,$($2 $commit)
    done
}
export -f iterate-commits

# loop through sample revisions, calling a function for each,
# separate timestamp and week with a comma
run-on-timestamped-samples() {
    local npoints=1 # by default, do every commit
    if [ $# -eq 2 ]; then
        local npoints=$1
        shift # discard first argument
    fi
    local func=${1:-true}  # do nothing, i.e., only report the commit
    seq $NREPOS | parallel cd $DIR.{} ';' git checkout -qf $DEFAULT_BRANCH
    seq $NREPOS | parallel iterate-commits $npoints $func {}
}

# count the files in the named commit without checking them out
files() { git ls-tree -r --full-tree --name-only ${1:-HEAD}; }
export -f files
nfiles() { files $1 | wc -l; }
export -f nfiles
lines-and-characters() { git ls-files | grep -v ' ' | xargs -P 24 -L 1 wc | awk 'BEGIN{ORS=","} {lines+=$1; chars+=$3} END{print lines "," chars}'; } 2>/dev/null
export -f lines-and-characters
compressed-size() { tar --exclude-vcs -cf - . | zstd -c - | wc -c; }
export -f compressed-size
volumes() {
    git checkout -fq ${1:-HEAD}
    parallel ::: lines-and-characters compressed-size
}
export -f volumes

set-project() {
    export NREPOS=10
    # export DIR=$PWD/git
    # export REPO=https://github.com/git/git.git
    export DIR=$PWD/linux
    export REPO=https://github.com/torvalds/linux.git
    export OUTPUT=$PWD/sizes/$(basename $DIR)
    mkdir -p $OUTPUT
    [ -d $DIR.1 ] || git clone -q $REPO $DIR.1 # clone source-code repo if it's not already there
    seq 2 $NREPOS | parallel "[ -d $DIR.{} ] || git clone -q $DIR.1 $DIR.{}"
    cd $DIR.1 >/dev/null # and dive in
}

set-project
set-globals
time run-on-timestamped-samples $NPOINTS echo > $OUTPUT/sha1s.csv
time run-on-timestamped-samples $NPOINTS ncommits > $OUTPUT/ncommits.csv
time run-on-timestamped-samples $NPOINTS nauthors > $OUTPUT/nauthors.csv
time run-on-timestamped-samples $NPOINTS ncommitters > $OUTPUT/ncommitters.csv
time run-on-timestamped-samples $NPOINTS nfiles > $OUTPUT/nfiles.csv
time run-on-timestamped-samples $NPOINTS volumes > $OUTPUT/volumes.csv

seq $NREPOS | parallel cd $DIR.{} ';' git checkout -qf $DEFAULT_BRANCH # clean up after yourself

(( elapsed_seconds = SECONDS - begin_notebook ))
(( minutes = elapsed_seconds / 60 ))
seconds=$((elapsed_seconds - minutes*60))
printf "Total elapsed time %02d:%02d\n" $minutes $seconds
