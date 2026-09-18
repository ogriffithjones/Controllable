#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
target_loader=${TARGET_LOADER:-fabric}
case "$target_loader" in
    fabric|neoforge) ;;
    *) printf 'Unsupported loader: %s\n' "$target_loader" >&2; exit 1 ;;
esac
property() {
    sed -n "s/^$1=//p" "$project_dir/gradle.properties" | tr -d '\r'
}
minecraft_version=$(property minecraft_version)
mod_version=$(property mod_version)
framework_version=$(property framework_version)
neoforge_version=$(property neoforge_version)
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
    :
else
    git -C "$framework_dir" apply --check "$patch_file"
    git -C "$framework_dir" apply "$patch_file"
fi

(
    unset CI
    export TARGET_LOADER="$target_loader"
    export LOCAL_MAVEN="$project_dir/.gradle/framework-maven"
    sh "$framework_dir/gradlew" -p "$framework_dir" \
        -Pmod_version="$framework_version" -Pneoforge_version="$neoforge_version" \
        :common:publish ":$target_loader:publish"
)

TARGET_LOADER="$target_loader" sh "$project_dir/gradlew" -p "$project_dir" ":$target_loader:build" "$@"
output_dir="$project_dir/build/$minecraft_version-mods/$target_loader"
mkdir -p "$output_dir"
cp "$framework_dir/$target_loader/build/libs/framework-$target_loader-$framework_version+$minecraft_version.jar" "$output_dir/"
cp "$project_dir/$target_loader/build/libs/controllable-$target_loader-$mod_version+$minecraft_version.jar" "$output_dir/"

mkdir -p "$project_dir/build/$minecraft_version-sources"
tar -czf "$project_dir/build/$minecraft_version-sources/framework-$framework_version-source.tar.gz" \
    --exclude=.git --exclude=.gradle --exclude=build \
    -C "$framework_dir" .
