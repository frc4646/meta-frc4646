# cargo_common emits [source.bitbake] that duplicates the source tree's
# [source.vendored-sources] — both bind vendor/. Strip it and add an explicit
# redirect since CARGO_HOME blocks discovery of the source tree's config.
CARGO_DISABLE_BITBAKE_VENDORING = "1"

cargo_common_do_configure:append() {
    sed -i '/^\[source\.bitbake\]/,/^\s*directory\s*=/d' ${CARGO_HOME}/config.toml

    cat >> ${CARGO_HOME}/config.toml <<TEGRA_CARGO_VENDOR

# Redirect crates-io at vendor/ shipped in rustc-1.94.1-src; CARGO_HOME blocks
# the source tree's own .cargo/config.toml from being discovered.
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "${CARGO_VENDORING_DIRECTORY}"
TEGRA_CARGO_VENDOR
}
