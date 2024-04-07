load("@bazel_mingw//:archives.bzl", "MINGW_ARCHIVES_REGISTRY")

def get_host_infos_from_rctx(os_name, os_arch):
    host_os = "linux"
    host_arch = "x86_64"

    if "windows" in os_name:
        host_os = "windows"
    elif "mac" in os_name:
        host_os = "osx"

    if "amd64" in os_arch:
        host_arch = "x86_64"
    elif "aarch64":
        host_arch = "arm64"

    return host_os, host_arch, "{}_{}".format(host_os, host_arch)

def _mingw_impl(rctx):
    host_os, host_cpu, host_name = get_host_infos_from_rctx(rctx.os.name, rctx.os.arch)
    registry = MINGW_ARCHIVES_REGISTRY[rctx.attr.version]

    base_id = rctx.attr.toolchain_identifier
    if base_id == "":
        base_id = "mingw_{}_{compiler_name}".format(host_name, compiler_name = "{}")

    print("host_name {}".format(host_name))

    target_compatible_with = rctx.attr.target_compatible_with
    if rctx.attr.use_host_constraint:
        target_compatible_with += [
            "@platforms//os:{}".format(host_os),
            "@platforms//cpu:{}".format(host_cpu)
        ]

    substitutions = {
        "%{toolchain_path_prefix}": "external/%s/" % rctx.name,
        "%{host_name}": host_name,
        
        "%{clang_id}": base_id.format("clang_{}".format(registry["details"]["clang_version"])),
        "%{clang_version}": registry["details"]["clang_version"],
        "%{gcc_id}": base_id.format("gcc_{}".format(registry["details"]["gcc_version"])),
        "%{gcc_version}": registry["details"]["gcc_version"],
        
        "%{target_compatible_with}": json.encode(target_compatible_with),
    }
    rctx.template(
        "BUILD",
        Label("//templates:BUILD.tpl"),
        substitutions
    )

    rctx.template(
        "utilities_action_names.bzl",
        Label("//templates:utilities_action_names.bzl.tpl"),
        substitutions
    )
    rctx.template(
        "utilities_cc_toolchain_config.bzl",
        Label("//templates:utilities_cc_toolchain_config.bzl.tpl"),
        substitutions
    )
    rctx.template(
        "utilities_config.bzl",
        Label("//templates:utilities_config.bzl.tpl"),
        substitutions
    )
    rctx.template(
        "utilities_toolchain_config_feature_legacy.bzl",
        Label("//templates:utilities_toolchain_config_feature_legacy.bzl.tpl"),
        substitutions
    )

    archive = registry["archives"][host_name]
    rctx.download_and_extract(archive["url"], sha256 = archive["sha256"], stripPrefix = archive["strip_prefix"])

_mingw_toolchain = repository_rule(
    attrs = {
        'version': attr.string(default = "latest"),
        'toolchain_identifier': attr.string(default = ""),
        'use_host_constraint': attr.bool(default = False),
        'target_compatible_with': attr.string_list(default = []),
    },
    local = False,
    implementation = _mingw_impl,
)

def mingw_toolchain(name, version = "latest"):
    toolchain_identifier = "mingw_{}"
    _mingw_toolchain(
        name = name,
        version = version,
        toolchain_identifier = toolchain_identifier
    )
    native.register_toolchains("@{}//:mingw_{}".format(name, toolchain_identifier.format("clang")))