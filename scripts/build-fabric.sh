#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
framework_dir="$project_dir/.gradle/framework-source"
framework_commit=a323fb13e05f2bb91944824f429b171e622bdb78
mkdir -p "$project_dir/.gradle"

if [ ! -d "$framework_dir/.git" ]; then
    git clone --depth 1 --branch multiloader/26.3 \
        https://github.com/MrCrayfish/Framework.git "$framework_dir"
fi
if [ "$(git -C "$framework_dir" rev-parse HEAD)" != "$framework_commit" ]; then
    git -C "$framework_dir" fetch origin "$framework_commit"
    git -C "$framework_dir" checkout --detach "$framework_commit"
fi

patch_file="$project_dir/patches/framework-26.3.patch"
if git -C "$framework_dir" apply --reverse --check "$patch_file" 2>/dev/null; then
    : # Already patched by a previous build.
else
    git -C "$framework_dir" apply --check "$patch_file"
    git -C "$framework_dir" apply "$patch_file"
fi

# Upstream selects GitHub Packages whenever CI is set; publish only to our local repo.
(
    unset CI
    export TARGET_LOADER=fabric
    export LOCAL_MAVEN="$project_dir/.gradle/framework-maven"
    sh "$framework_dir/gradlew" -p "$framework_dir" \
        -Pmod_version=0.13.26-controllable.1 \
        :common:publish :fabric:publish
)

TARGET_LOADER=fabric sh "$project_dir/gradlew" -p "$project_dir" :fabric:build "$@"
mkdir -p "$project_dir/build/26.3-mods"
cp "$framework_dir/fabric/build/libs/framework-fabric-0.13.26-controllable.1+26.3.jar" \
    "$project_dir/build/26.3-mods/"
cp "$project_dir/fabric/build/libs/controllable-fabric-0.26.2-alpha.1+26.3.jar" \
    "$project_dir/build/26.3-mods/"

# Supply the complete patched dependency sources alongside redistributed binaries.
mkdir -p "$project_dir/build/26.3-sources"
tar -czf "$project_dir/build/26.3-sources/framework-0.13.26-controllable.1-source.tar.gz" \
    --exclude=.git --exclude=.gradle --exclude=build \
    -C "$framework_dir" .
