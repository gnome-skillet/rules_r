# Copyright 2019 The Bazel Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

RInfo = provider(
    doc = "Information about the system R installation.",
    fields = [
        # Command to invoke R.
        "r",
        # Command to invoke Rscript.
        "rscript",
        # Version to assert in build actions.
        "version",
        # Site-wide Makevars file.
        "makevars_site",
        # Additional tools to make available in PATH.
        "tools",
        # Additional files available to the build actions.
        "files",
        # Environment variables for build actions.
        "env_vars",
        # File for system state information.
        "state",
        # Whether to stamp builds.
        "stamp",
    ],
)

def _r_toolchain_impl(ctx):
    args = ctx.attr.args

    if not ctx.attr.r or not ctx.attr.rscript:
        fail("R or Rscript not specified")

    Rscript_args = ["--no-init-file"] + args
    R_args = ["--slave", "--no-restore"] + Rscript_args

    R = [ctx.attr.r] + R_args
    Rscript = [ctx.attr.rscript] + Rscript_args

    toolchain_info = platform_common.ToolchainInfo(
        RInfo = RInfo(
            env_vars = ctx.attr.env_vars,
            files = ctx.files.files,
            makevars_site = ctx.file.makevars_site,
            r = R,
            rscript = Rscript,
            state = ctx.file.system_state_file,
            tools = ctx.attr.tools,
            version = ctx.attr.version,
            stamp = ctx.attr.stamp,
        ),
    )
    return [toolchain_info]

_r_toolchain = rule(
    attrs = {
        "r": attr.string(
            default = "R",
            doc = ("Absolute path to R, or name of R executable; the search " +
                   "path will include the directories for tools attribute."),
        ),
        "rscript": attr.string(
            default = "Rscript",
            doc = ("Absolute path to Rscript, or name of Rscript executable; " +
                   "the search path will include the directories for tools " +
                   "attribute."),
        ),
        "version": attr.string(
            doc = ("If provided, ensure version of R matches this string in x.y form. " +
                   "This version check is performed in the `r_pkg` and `r_binary` " +
                   "(and by extension, `r_test` and `r_markdown`) rules. For stronger " +
                   "guarantees, perform this version check when generating the " +
                   "`system_state_file` (see attribute below)."),
        ),
        "args": attr.string_list(
            default = [
                "--no-save",
                "--no-site-file",
                "--no-environ",
            ],
            doc = ("Arguments to R and Rscript, in addition to " +
                   "`--slave --no-restore --no-init-file`"),
        ),
        "makevars_site": attr.label(
            allow_single_file = True,
            doc = "Site-wide Makevars file",
        ),
        "env_vars": attr.string_dict(
            doc = "Environment variables for BUILD actions",
        ),
        "tools": attr.label_list(
            allow_files = True,
            doc = "Additional tools to make available in PATH",
        ),
        "files": attr.label_list(
            allow_files = True,
            doc = "Additional files available to the BUILD actions",
        ),
        "system_state_file": attr.label(
            allow_single_file = True,
            doc = ("A file that captures your system state. " +
                   "Use it to rebuild all R packages whenever the contents of this file change. " +
                   "This is ideally generated by a repository_rule with `configure = True`, " +
                   "so that a call to `bazel sync --configure` resets this file."),
        ),
        "stamp": attr.bool(
            mandatory = True,
            doc = "Global on/off for stamping builds; default value uses --stamp flag",
        ),
    },
    provides = [platform_common.ToolchainInfo],
    implementation = _r_toolchain_impl,
)

def r_toolchain(**kwargs):
    if kwargs.get("stamp") == None:
        _r_toolchain(stamp = select({
            "@com_grail_rules_r//R/internal/toolchains:stamp": True,
            "//conditions:default": False,
        }), **kwargs)
    else:
        _r_toolchain(**kwargs)
