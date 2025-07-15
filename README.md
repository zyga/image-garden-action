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

### spread-subdir

Optional sub-directory where `spread.yaml` is located.

## Usage

Follow the steps to get started:

1. Create a branch of your project where you plan to introduce integration testing.

    At the end of this process we will open a pull request that introduces both
    the defintion of the test and the CI/CD workflow that runs it.

2. Create the `.image-garden/README.md` file.

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
          - debian-cloud-12:
              username: root
              password: root
          - fedora-cloud-42:
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
    sudo snap install --edge image-garden
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
        debian-12:
            runs-on: ubuntu-latest
            steps:
                - name: Checkout code
                  uses: actions/checkout@v4
                  # This is essential for git restore-mtime to work correctly.
                  with:
                    fetch-depth: 0
                - name: Run integration tests
                  uses: zyga/image-garden-action@v0
                  with:
                    snapd-channel: latest/edge
                    image-garden-channel: latest/edge
                    garden-system: debian-cloud-12
        fedora-42:
            runs-on: ubuntu-latest
            steps:
                - name: Checkout code
                  uses: actions/checkout@v4
                  with:
                    fetch-depth: 0
                - name: Run integration tests
                  uses: zyga/image-garden-action@v0
                  with:
                    snapd-channel: latest/edge
                    image-garden-channel: latest/edge
                    garden-system: fedora-cloud-42
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

## Further reading

Consult documentation of [spread](https://github.com/canonical/spread) and
[image-garden](https://gitlab.com/zygoon/image-garden).
