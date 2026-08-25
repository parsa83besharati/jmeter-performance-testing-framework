# Contributing to JMeter Performance Testing Framework

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing.

## How to Contribute

### Reporting Bugs

1. Check if the bug has already been reported in [Issues](https://github.com/pouya-besharati/jmeter-performance-testing-framework/issues)
2. If not, create a new issue with:
   - Clear title and description
   - Steps to reproduce
   - Expected vs actual behavior
   - JMeter version and OS information

### Suggesting Enhancements

1. Check existing issues for similar suggestions
2. Create a new issue with the `enhancement` label
3. Describe the use case and expected behavior

### Submitting Changes

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes following the code standards below
4. Test your changes with at least the smoke test
5. Commit with a clear message: `git commit -m "Add: description of change"`
6. Push to your fork: `git push origin feature/my-feature`
7. Create a Pull Request

## Code Standards

### JMX Files

- **Never duplicate samplers** - Use `IncludeController` to reference `reqres-api-samplers.jmx`
- **Always include assertions** - Every sampler must have response code assertions
- **Use parameterization** - Reference variables via `${VAR_NAME}` syntax
- **Consistent naming** - Use descriptive `testname` attributes

### Scripts

- **Cross-platform** - Provide both `.bat` and `.sh` versions
- **Error handling** - Check for required environment variables
- **Clear output** - Use consistent echo messages and formatting
- **Quoting** - Always quote file paths that may contain spaces

### Configuration

- **Externalize secrets** - Never hardcode API keys in JMX files
- **Use `__P()` function** - Allow runtime property overrides
- **Document defaults** - Every property should have a default value

## Testing Your Changes

Before submitting a PR, ensure:

1. **Smoke test passes**: `./scripts/run-test.sh smoke`
2. **All scripts are executable**: `chmod +x scripts/*.sh`
3. **No XML syntax errors**: Open modified JMX files in JMeter GUI
4. **Cross-platform**: Test on both Windows and Linux/Mac if possible

## Pull Request Checklist

- [ ] Code follows existing style conventions
- [ ] Changes are documented in README (if applicable)
- [ ] No hardcoded secrets or credentials
- [ ] Test plans use `IncludeController` for samplers
- [ ] All samplers have assertions
- [ ] Scripts handle errors gracefully
- [ ] PR description explains the change

## Development Setup

1. Install JMeter 5.6+
2. Set `JMETER_HOME` environment variable
3. Clone the repository
4. Run smoke test to verify setup: `./scripts/run-test.sh smoke`

## Questions?

Feel free to open an issue for any questions about contributing.
