# GitHub Copilot Instructions for image-garden-action

## Project Overview

This repository contains a **GitHub composite action** that enables running full-system integration tests using `spread` on vanilla images of various Linux distributions (Ubuntu, Debian, Fedora, CentOS, openSUSE, Alma, Arch Linux, Rocky Linux, Oracle Linux, etc.) as prepared by `image-garden`.

The action allows developers to test their applications in real deployment environments very rapidly, entirely under their control. The same test suite can run locally on developers' computers and in CI, facilitating efficient testing workflows.

## Technology Stack

- **GitHub Actions**: Composite action (using `runs.using: composite`)
- **Shell scripting**: Bash scripts for action steps
- **Snap packages**: Uses snapd, image-garden, and core24 snaps
- **Virtualization**: QEMU/KVM for virtual machine management
- **Testing framework**: Spread for integration testing
- **Cloud-init**: For VM configuration and provisioning
- **YAML**: Action configuration and workflow definitions

## Code Style and Standards

### YAML Files
- Use **2 spaces** for indentation (never tabs)
- Follow the existing `.yamlfmt.yaml` configuration
- Format YAML files using `yamlfmt`: Run `make fmt-yaml`
- Lint YAML files before committing: Run `make check-yamlfmt`

### Shell Scripts
- Follow **POSIX-compatible** shell scripting practices where possible
- Use `bash` explicitly for bash-specific features
- Format shell scripts using `shfmt`: Run `make fmt-sh`
- Lint shell scripts using `shellcheck`: Run `make check-shellcheck`
- All shell scripts must pass both `shfmt` and `shellcheck` validation

### Documentation
- Include SPDX license headers in all files:
  ```
  # SPDX-License-Identifier: Apache-2.0
  # SPDX-FileCopyrightText: Canonical Ltd.
  ```
- Keep `README.md` updated with accurate usage instructions
- Use markdown comments for meta-information in markdown files
- Ensure all files comply with REUSE specification: Run `make check-reuse`

### GitHub Actions Best Practices
- **Use explicit versions** for third-party actions (e.g., `actions/checkout@v4`, not `@main`)
- **Group related output** using `::group::` and `::endgroup::` for better log readability
- **Use composite actions** efficiently by defining reusable steps
- **Handle secrets carefully**: Never log or expose sensitive information
- **Provide clear input descriptions** with sensible defaults
- **Use conditional execution** (`if:`) appropriately to skip unnecessary steps
- **Leverage caching** strategically to improve performance without bloating storage
- **Clean up resources** properly to avoid leaving artifacts or processes running
- **Support matrix builds** where appropriate for testing across multiple systems
- **Use `shell: bash` explicitly** in composite actions for consistency

## Architecture and Structure

### Key Files
- **`action.yaml`**: Main action definition with inputs, outputs, and steps
- **`snap-install`**: Bash script for installing snap packages with caching support
- **`README.md`**: Comprehensive documentation for users
- **`Makefile`**: Defines linting, formatting, and checking tasks
- **`.gitignore`**: Excludes temporary files and build artifacts
- **`.yamlfmt.yaml`**: YAML formatting configuration

### Action Inputs
All inputs should have:
- Clear, descriptive names using kebab-case
- Detailed descriptions explaining purpose and usage
- Sensible default values where applicable
- Proper type indication (though YAML doesn't enforce this, documentation should be clear)

### Action Steps
- Each step should have a clear, descriptive `name`
- Use `shell: bash` for all shell commands in composite actions
- Group verbose output for readability
- Handle errors gracefully with appropriate error messages
- Consider performance implications (caching, parallelization, etc.)

## Development Workflow

### Before Making Changes
1. **Understand the context**: Read related documentation and existing code
2. **Check existing issues**: Review open issues and PRs for related work
3. **Plan minimal changes**: Think through the smallest change that addresses the need

### Making Changes
1. **Follow existing patterns**: Maintain consistency with current codebase style
2. **Update documentation**: Keep README.md and comments synchronized with code changes
3. **Add SPDX headers**: Ensure all new files include proper license headers
4. **Test locally when possible**: Use the action in test workflows
5. **Format and lint**: Run `make fmt` and `make check` before committing

### Quality Checks
Run these commands before finalizing changes:
```bash
make check-shellcheck  # Lint shell scripts
make check-shfmt       # Check shell script formatting
make check-yamlfmt     # Check YAML formatting
make check-reuse       # Verify license compliance
make check             # Run all checks
```

## Boundaries and Restrictions

### DO NOT:
- **Change action behavior** without updating documentation
- **Remove or modify existing inputs** that users may depend on (breaking changes)
- **Add dependencies** unnecessarily (keep the action lightweight)
- **Expose secrets or sensitive data** in logs or outputs
- **Hardcode system-specific paths** that may not exist in all environments
- **Skip error handling** for operations that can fail
- **Commit generated files** or build artifacts (check `.gitignore`)
- **Modify licensing information** without authorization
- **Break backward compatibility** without clear migration path and version bump

### DO:
- **Maintain backward compatibility** whenever possible
- **Provide clear error messages** that help users troubleshoot issues
- **Document breaking changes** clearly in commit messages and release notes
- **Test changes** with actual workflows when feasible
- **Consider performance** implications of caching and resource usage
- **Follow security best practices** for actions (least privilege, input validation, etc.)
- **Keep dependencies minimal** and up-to-date
- **Write clear commit messages** that explain the "why" behind changes

## Specific Guidelines for This Action

### Caching Strategy
- Host snaps should be cached for reusability
- Pristine images should be cached by system
- Prepared images caching is optional (scales poorly with many systems)
- Always exclude log files from caches

### Virtualization Support
- Assume `/dev/kvm` availability but handle gracefully if missing
- Make `/dev/kvm` more permissive (chmod 666) for snap access
- Document performance implications of missing hardware virtualization

### Spread Integration
- Support project subdirectories via `spread-subdir` input
- Handle artifact collection and upload correctly
- Rename artifacts to be GitHub-compatible (replace colons)
- Use spread from image-garden snap bundle

### Error Handling
- Provide clear troubleshooting guidance in documentation
- Include common error patterns and their resolutions in README
- Use appropriate exit codes and error messages

### User Experience
- Provide sensible defaults for all optional inputs
- Group verbose output for better log navigation
- Upload logs as artifacts on failure for debugging
- Document all inputs, outputs, and usage examples clearly

## Examples and Patterns

### Adding a New Input
```yaml
new-input:
    description: Clear description of what this input does and how to use it
    default: "sensible-default-value"
```

### Adding a New Step
```yaml
- name: Descriptive step name
  shell: bash
  run: |
    echo "::group::Descriptive group name"
    # Step implementation
    echo "::endgroup::"
```

### Conditional Step Execution
```yaml
- name: Conditional step
  if: ${{ fromJSON(inputs.some-boolean-input) }}
  shell: bash
  run: |
    # Step implementation
```

## Testing

### Local Testing
- Create a test workflow in a separate repository
- Reference this action using local path or branch
- Test with various input combinations
- Verify caching behavior and artifact uploads

### Integration Testing
- Test with actual spread.yaml configurations
- Verify VM allocation and deallocation
- Confirm artifact collection and upload
- Test failure scenarios and log uploads

## Security Considerations

- Validate all inputs before use
- Avoid command injection vulnerabilities in shell scripts
- Don't expose secrets in logs or error messages
- Use least privilege principle for operations
- Keep dependencies updated for security patches
- Follow GitHub Actions security best practices

## Version Management

- This action is currently in **pre-release mode** (v0)
- Breaking changes should be clearly documented
- Consider semantic versioning for future stable releases
- Maintain changelog for tracking changes between versions

## Additional Resources

- [Spread documentation](https://github.com/canonical/spread)
- [Image-garden documentation](https://gitlab.com/zygoon/image-garden)
- [GitHub Actions documentation](https://docs.github.com/en/actions)
- [Composite actions guide](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action)
- [REUSE specification](https://reuse.software/)
