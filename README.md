# jami-build-runner

Builds the **stock Jami Android APK** from upstream
[`review.jami.net/jami-client-android`](https://review.jami.net/jami-client-android)
via GitHub Actions, applying a small set of patches that work around
upstream issues current as of Jami 4.0.0-4623 / commit `d0498a2`.

This repo contains **no Jami source** — Jami is fetched fresh at build
time. The repo's only purpose is to produce a working
`arm64-v8a` debug APK on a Linux runner with adequate RAM (working
around constraints on a local Mac).

## Run a build

1. **Automatic on push:** every push to `main` triggers the workflow.
2. **Manual:** Actions → "Build stock Jami Android APK" → Run workflow.
   You can optionally specify a Jami git ref (branch / tag / commit
   SHA); defaults to `master`.

When the run is green, the APK is under **Artifacts** at the bottom of
the run page, named `jami-stock-arm64-debug.apk`. Download, then:

```sh
adb install jami-stock-arm64-debug.apk
```

Repeat for the second phone.

## What it patches

The workflow applies three patches to the freshly cloned Jami tree
before building. See `patches/` for the details and the rationale per
patch. Summary:

| Patch | Why |
|---|---|
| `01-gradle-wrapper-stable.patch` | Jami pins `gradle-9.4.0-rc-1` (release candidate) which deadlocks Gradle's worker pool in AGP packaging. Downgrade to the AGP-minimum stable `9.3.1`. |
| `02-make-swig-module-flag.patch` | SWIG 4.4 doesn't parse `%module (directors="1") JamiService` and exits 1 silently. Add explicit `-module JamiService` to `make-swig.sh`. |
| `03-yaml-cpp-prebuild.sh` | Jami's contrib graph for Android doesn't trigger yaml-cpp despite `daemon/CMakeLists.txt` requiring it. Force-build it before the main gradle run. |

If/when Jami upstreams these, the patches will silently no-op (the
patch step is idempotent for already-fixed files) — or fail loudly, in
which case bump the workflow.

## Cost

Public repo on github.com: unlimited free Actions minutes. First build
takes 40–60 min (full contrib cross-compile, no cache); cached
subsequent builds 10–20 min.

## Not affiliated with Jami

The Jami project (https://jami.net, source under GPL-3.0) is upstream.
This repo is a CI runner that consumes their public source. All
modifications applied to Jami at build time are in `patches/` — public
and auditable.
