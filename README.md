<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: Canonical Ltd.
-->

# Image Garden, Spread integration tests as GitHub Action

The `image-garden` GitHub action allows running full-system integration tests,
using `spread`, on vanilla images of Ubuntu, Debian, Fedora, CentOS, openSUSE,
Alma, Arch Linux, Rocky Linux, Oracle Linux and more as prepared by
`image-garden`.

You can test your application in the real environment it would be deployed in,
very rapidly, entirely under your control. The same test suite can run locally
on your computer and in CI, making the push-style development a thing of the
past.

Image Garden and Spread are a perfect for testing packaging, system integration
scripts, interaction with sandbox mechanism and anything else that requires a
full system with a real Linux kernel used by the target platform.

## Disclaimer

The action is in pre-release mode. You can see it in action at
https://github.com/canonical/snapd-smoke-tests/

## Inputs

### garden-system

Name of the image-garden system to test on, matching one of the systems in
`spread.yaml`. Required.

### spread-subdir

Optional sub-directory where `spread.yaml` is located.

### spread-artifacts

Optional directory where spread saves task artifacts. A non-empty value causes the
both collection of artifacts and uploading collected files to GitHub.

### spread-artifacts-suffix

Optional suffix used to disambiguate the GitHub artifacts of the action: spread
artifacts, the spread log and, when the job fails, the boot logs. When missing
the garden system name is used instead. Set it when several jobs of a workflow
test the same system.

### spread-variant

Optional variant of spread to use. Consult spread documentation for available variants.

### spread-live

Optional boolean flag to enable live mode for spread. When set to `"true"`, the `-live`
flag is passed to the spread command, allowing interactive control of the test execution.

**Constraint:** `spread-live` can only be used when `spread-variant` is set to `"plus"`.
The action will fail with an error if this constraint is violated.

Default: `"false"`

### pkgproxy-channel

Snap store channel of the pkgproxy snap, when the action installs it, such as
`latest/edge` to try a fix before it is released.

Default: `"latest/stable"`

### cache-prepared-images

Optional boolean flag to keep the project-specific virtual machine images,
prepared from `.image-garden.mk`, in the GitHub cache. This uses a lot of cache
storage and scales poorly with the number of systems.

Default: `"false"`

### save-cache

Which runs save the pkgproxy cache, see [Caching](#caching): `default-branch`,
`always` or `never`.

Default: `"default-branch"`

### cache-scope

Scope of the packages part of the pkgproxy cache: everything but the pristine
images, such as snaps and the apt, docker and LXD downloads of the virtual
machines. Jobs with the same scope share it. Give all the jobs of a matrix the
same scope, so that they share one copy of the packages instead of one per
system. See [Caching](#caching).

Default: `""`, the garden system

### save-package-cache

Whether this job saves the packages part of the pkgproxy cache. In a matrix
that shares a `cache-scope`, set it to `"false"` in all jobs but one, which
then keeps the shared cache. The pristine images of each job are saved either
way, as `save-cache` allows.

Default: `"true"`

### cache-key-prefix

Prefix of the GitHub cache keys of the pkgproxy cache. Change it to start from
an empty cache, as pkgproxy never deletes anything from its cache on its own.

Default: `"image-garden-pkgproxy-v1"`

## Outputs

### pkgproxy-mode

`snap` when the action installed the pkgproxy snap, `external` when it used a
pkgproxy that already listened on port 3142.

### images-cache-restored-key, package-cache-restored-key

Keys of the GitHub caches that the pristine images and the packages were
restored from. Empty on a cold start and in `external` mode.

### images-cache-saved, package-cache-saved

`true` when the action saved the pristine images, or the packages, to the
GitHub cache, otherwise `false`.

## Reading the job log

The action shapes its output for the GitHub job log:

- Each stage starts with a coloured heading, and its result is marked ✔ or ✘,
  with how long it took.
- Making the virtual machine image boots it for the first time, with its whole
  console in the output. That output is folded, and when making the image fails,
  its last lines are shown again after the fold.
- spread's output goes through `spread-output`. Allocating, connecting to and
  discarding systems are folded. Executing a task stands out, errors and the
  summary are coloured, and of the output of a failed script only the last 30
  lines are shown, with the earlier ones folded above them. `spread.log`, uploaded
  as an artifact, keeps spread's output unchanged.
- The pkgproxy cache is shown before and after the tests: the files and bytes
  of each kind of download, what the job added, and what pkgproxy served from
  its cache during the job. The job summary has the same table.
- When the job fails, the pkgproxy log follows: first only what went wrong
  (warnings and errors, such as who answered when an upstream answered with
  an error, requests that failed, and the service failing to start), then,
  folded, the whole log of the job, without the setup guidance pkgproxy
  prints each time it starts.

## Caching

The action uses [pkgproxy](https://gitlab.com/zygoon/pkgproxy) as its only
cache for downloads. Everything goes through it: the image-garden snap and its
components on the runner, the pristine images (by their checksum, with
`GARDEN_DL_PKGPROXY`), and the apt, snap and go downloads of the virtual
machines.

By default the action installs the pkgproxy snap and connects image-garden to
it (`snap set image-garden pkgproxy=snap`). The pkgproxy cache is restored from
the GitHub cache at the start of the job and, if the job added to it, saved at
the end, as archives that keep the extended attributes pkgproxy relies on.

The pkgproxy cache is kept as two GitHub caches:

- **images**: the pristine images that image-garden downloads, always one
  cache per `garden-system`;
- **packages**: everything else, such as the image-garden snap and the snaps,
  apt, docker and LXD downloads of the virtual machines, one cache per
  `cache-scope`, which is the garden system unless set.

Images prepared from `.image-garden.mk` are not part of either: see
`cache-prepared-images`.

### Behind a proxy

pkgproxy fetches through the proxy that snapd uses (`snap get system
proxy.http`, `proxy.https` and `proxy.no-proxy`), given to it as its own
`http-proxy`, `https-proxy` and `no-proxy` options. On runners with
[aproxy](https://github.com/canonical/aproxy), such as Canonical's self-hosted
runners, the egress proxy that aproxy forwards to (`snap get aproxy proxy`)
fills in either scheme that snapd named no proxy for, so pkgproxy asks the
egress proxy itself rather than going through aproxy. pkgproxy reads these
options from version 0.13, or `latest/edge` before then: see
`pkgproxy-channel`.

As in [setup-pkgproxy](https://github.com/zyga/setup-pkgproxy), only runs on
the default branch save the cache (`save-cache: default-branch`). Pull
requests and other branches restore the default branch's cache but never save
their own, which would only use up the repository's cache storage and evict
the default branch's cache. Make sure your workflow also runs on pushes to the
default branch, or nothing is ever saved. Failed and cancelled jobs save too:
whatever pkgproxy cached is valid.

Each part is saved only when the job added to it. When several jobs use the
same system, let one of them save and give the others `save-cache: never`.

### Caching a matrix

The systems of a matrix download a different image each, but mostly the same
snaps and packages. Give every job the same `cache-scope`, and let one job,
such as a canary that runs first, save the shared packages:

```yaml
jobs:
    canary:
        steps:
            - uses: zyga/image-garden-action@v0
              with:
                garden-system: ubuntu-cloud-24.04
                cache-scope: shared
    test:
        needs: canary
        strategy:
            matrix:
                garden-system: [debian-cloud-13, fedora-cloud-44]
        steps:
            - uses: zyga/image-garden-action@v0
              with:
                garden-system: ${{ matrix.garden-system }}
                cache-scope: shared
                save-package-cache: "false"
```

Every job then restores the shared packages and its own images, and saves its
own images when they change.

### Using setup-pkgproxy as well

If a pkgproxy already listens on port 3142 when the action starts, for example
because the job used [setup-pkgproxy](https://github.com/zyga/setup-pkgproxy)
first, the action uses that pkgproxy and does not install the snap.
Virtual machines then reach it at the address of the runner. The cache belongs
to setup-pkgproxy in that case, and this action neither restores nor saves
one, so there is still a single cache.

setup-pkgproxy must come **before** this action. Run after it, setup-pkgproxy
cannot listen on port 3142, which the pkgproxy snap already uses.

## Upgrading

- `cache-host-snaps` and `cache-pristine-images` are gone: pkgproxy caches
  both host snaps and pristine images. Remove them from your workflows.
- `cache-deb-packages` is gone: pkgproxy, which replaced apt-cacher-ng in
  image-garden, is always used.

## Usage

Follow the steps to get started:

1. Create a branch of your project where you plan to introduce integration testing.

    At the end of this process we will open a pull request that introduces both
    the defintion of the test and the CI/CD workflow that runs it.

2. Create the `.image-garden/README.md` and `.image-garden.mk` files.

    The presence of the `.image-garden/` directory instructs `image-garden` to
    store all temporary files in a sub-directory. This makes it much more tidy
    but we also need to create a file for `git` to keep the directory around.

    Please link to the documentation for both tools (image-garden and spread)
    for the benefit of your developers.

    ```markdown
    # Image Garden State Directory

    This directory is used by `image-garden` to store large temporary files.
    It should be ignored in `.gitignore` apart from this `README.md` file
    itself.

    Consult documentation of [spread](https://github.com/canonical/spread) and
    [image-garden](https://gitlab.com/zygoon/image-garden).
    ```

    `.image-garden.mk` file is used to expand the cloud-init user data template
    defined on image-garden. It can be left empty if no extra configuration is needed.

3. Create the `spread.yaml` file.

    This file defines how spread should allocate and discard virtual machines
    used for testing, which systems we are interested in testing and where to
    find the tests.

    Put the following content inside. Pay attention to formatting as YAML
    requires spaces for indentation.

    ```yaml
    project: demo
    path: /root/demo
    exclude:
      - .image-garden/
      - .git
    backends:
      garden:
        type: adhoc
        allocate: |
            if [ -n "${SPREAD_HOST_PATH-}" ]; then
                PATH="$SPREAD_HOST_PATH"
            fi
            exec image-garden allocate "$SPREAD_SYSTEM"."$(uname -m)"
        discard: |
            if [ -n "${SPREAD_HOST_PATH-}" ]; then
                PATH="$SPREAD_HOST_PATH"
            fi
            exec image-garden discard "$SPREAD_SYSTEM_ADDRESS"
        systems:
          - debian-cloud-13:
              username: root
              password: root
          - fedora-cloud-44:
              username: root
              password: root
    suites:
      tests/:
        summary: Integration test
    ```

4. Create the `tests/hello/task.yaml` file.

    This file defines the first test in our test suite.

    ```yaml
    summary: hello-world
    execute: |
        echo "Here you will invoke your program"
        # TODO: actually call my program
    ```

    Spread uses directory structure where test suites contain one or more tasks
    (tests and tasks are used interchangeably). The `tests/` directory here is the
    suite and `tests/hello` is the task.

5. Install the `image-garden` snap.

    ```sh
    sudo snap install image-garden
    ```

    Your system must support snap packages. In general see
    https://snapcraft.io/image-garden for installation instructions tailored to
    specific Linux distribution.

6. Use `spread` built into `image-garden`

    Image-garden snap contains a bundled copy of upstream `spread`. The snap
    sandbox makes using a bundled copy much easier than having to install and
    maintain a separate program.

    ```sh
    sudo snap alias image-garden.spread spread
    ```

    This will allow you to run `spread` to run the integration tests. Spread reads
    `spread.yaml` and the referenced `task.yaml` files and arranges to prepare,
    execute and restore each task.

7. Ensure you can use hardware-assisted virtualisation

    You must have the right to open `/dev/kvm`. On most systems this file is
    owned by the `kvm` group. You must be a member of this group. Use `groups`
    to see if you are already a member. If you are not run `sudo usermod -aG
    kvm $LOGNAME`.  For simplicity logout and log back in again and re-check
    that you are a member of the group.

    If your system does not have the `/dev/kvm` device then it does not offer
    hardware assisted virtualisation. Image garden will still work but
    everything will be much, much slower. This is typically encountered when
    system BIOS disables or does not allow enabling hardware virtualisation,
    inside virtual machines that do not support nested virtualisation and on
    specific CPU architectures where virtualisation is not yet supported (e.g.
    RISC-V and some older aarch64 systems).

8. Run `spread` locally

    Run `spread -v` to run the test for the first time. You will see that
    spread will allocate one instance of the two systems we've specified,
    connect to them, copy our project across, prepare each system by running
    project-specific logic, prepare each suite, prepare the task, execute the
    task and restore the task, suite and system.

    First run will be much slower, as image-garden will have to download
    pristine images for the operating systems you've selected for your tests,
    boot them once for preparation and save the result. Subsequent runs will be
    much faster.

    At this stage you can spend time to expand the test so that it does
    something useful.  Spread is typically used to build, install and see the
    software working in each system.  Your project-wide prepare may install
    compilation tools, configure, build and install your software. Your tasks
    may exercise distinct functionality of your software.

    Spread is heavily used within the Canonical/Ubuntu ecosystem, you may find
    projects using it to learn more this way.

9. Add the `image-garden-action` workflow.

    Create the file `.github/workflows/spread.yaml` with the following content:

    ```yaml
    name: spread
    on:
        push:
            branches: ["main"]
        pull_request:
    jobs:
        debian-13:
            runs-on: ubuntu-latest
            steps:
                - name: Checkout code
                  uses: actions/checkout@v6
                  # This is essential for git restore-mtime to work correctly.
                  with:
                    fetch-depth: 0
                - name: Run integration tests
                  uses: zyga/image-garden-action@v0
                  with:
                    garden-system: debian-cloud-13
        fedora-44:
            runs-on: ubuntu-latest
            steps:
                - name: Checkout code
                  uses: actions/checkout@v6
                  with:
                    fetch-depth: 0
                - name: Run integration tests
                  uses: zyga/image-garden-action@v0
                  with:
                    garden-system: fedora-cloud-44
    ```

10. Add new files to git

    ```sh
    git add .github/workflows/spread.yaml .image-garden/README.md spread.yaml tests/hello/task.yaml
    ```

    Note that this workflow is very basic. You most likely want to use matrix
    jobs to avoid repetition and test on more systems. You should also plan
    caching strategy and choose workers that are large enough to run your test
    workflows. The default workers from GitHub come with four cores and 16GB of
    RAM and support for kvm and should work great for small to medium sized
    projects.

    As you add use more and more test systems or run more and more tests, you
    will consume your quota of GitHub CI minutes. You may need to purchase
    more, or deploy and pay for self-hosted runners.

    Commit, push and open a pull request.

Please leave a GitHub star if you found this useful. Please feel free to open
issues, either on `image-garden-action`, `image-garden` or `spread`.

## Troubleshooting

This section lists common errors and how to resolve them.

### `error: nothing matches provider filter`

**Cause:**
The system specified in the workflow input does not exist in the `spread.yaml` configuration file.

**Resolution:**
Verify that the value of the `garden-system` input matches one of the systems defined in `spread.yaml`.

### `Cannot allocate garden:<system-name>: backend "garden" allocate must print ADDRESS=<SSH address> to stdout, got: ""`

**Cause:**
The requested operating system and architecture combination is not available in **image-garden**.

**Resolution:**
Confirm that the specified OS and architecture are supported by **image-garden**, and update your inputs as needed.

## Further reading

Consult documentation of [spread](https://github.com/canonical/spread) and
[image-garden](https://gitlab.com/zygoon/image-garden).
