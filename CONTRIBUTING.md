# Contributing to CallFlowEngine

Thank you for considering contributing to CallFlowEngine! We welcome contributions from everyone.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Documentation](#documentation)
- [Community](#community)

---

## 🤝 Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inspiring community for all. Please be respectful and constructive in your interactions.

### Expected Behavior

- ✅ Be respectful and inclusive
- ✅ Welcome newcomers
- ✅ Accept constructive criticism
- ✅ Focus on what's best for the community

### Unacceptable Behavior

- ❌ Harassment or discrimination
- ❌ Trolling or insulting comments
- ❌ Personal or political attacks
- ❌ Publishing others' private information

---

## 🎯 How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues. When creating a bug report, include:

- **Clear title** - Descriptive and specific
- **Steps to reproduce** - Detailed reproduction steps
- **Expected behavior** - What you expected to happen
- **Actual behavior** - What actually happened
- **Environment** - OS, Elixir version, etc.
- **Logs** - Relevant error messages or logs

**Example:**

```markdown
### Bug: Event processor crashes on invalid JSON

**Environment:**
- OS: Ubuntu 22.04
- Elixir: 1.15.7
- CallFlowEngine: v0.2.0

**Steps to reproduce:**
1. Send malformed JSON to ARI connection
2. Observe crash in logs

**Expected:** Graceful error handling
**Actual:** Process crash

**Logs:**
```
[error] Event processing failed: invalid JSON
```

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. Include:

- **Use case** - Why is this enhancement needed?
- **Proposed solution** - How should it work?
- **Alternatives** - Other solutions considered?
- **Additional context** - Screenshots, examples, etc.

### Pull Requests

We actively welcome your pull requests:

1. Fork the repo and create your branch from `main`
2. If you've added code, add tests
3. If you've changed APIs, update the documentation
4. Ensure the test suite passes
5. Make sure your code follows the style guidelines
6. Issue the pull request

---

## 💻 Development Setup

### Prerequisites

- **Elixir** 1.14+ and **Erlang/OTP** 25+
- **PostgreSQL** 12+
- **Git**
- **Docker** (optional, for integration tests)

### Local Setup

```bash
# 1. Fork and clone the repository
git clone https://github.com/YOUR_USERNAME/call-flow-engine.git
cd call_flow_engine

# 2. Install dependencies
mix deps.get

# 3. Setup database
mix ecto.create
mix ecto.migrate

# 4. Run tests to verify setup
mix test

# 5. Start the development server
mix phx.server
```

### Docker Setup (Alternative)

```bash
# Start all services
docker-compose up -d

# Run tests in container
docker-compose exec app mix test

# Access IEx shell
docker-compose exec app iex -S mix
```

---

## 🔄 Pull Request Process

### 1. Create a Branch

```bash
# Feature branch
git checkout -b feature/your-feature-name

# Bug fix branch
git checkout -b fix/bug-description

# Documentation branch
git checkout -b docs/what-you-updated
```

### 2. Make Your Changes

- Write clear, concise code
- Add tests for new functionality
- Update documentation as needed
- Follow the coding standards (see below)

### 3. Test Your Changes

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run code formatter
mix format

# Run static analysis
mix credo --strict

# Run dialyzer (optional, takes time)
mix dialyzer
```

### 4. Commit Your Changes

Use clear, descriptive commit messages:

```bash
# Good commit messages
git commit -m "Add circuit breaker for Bitrix client"
git commit -m "Fix race condition in call creation"
git commit -m "Update README with performance benchmarks"

# Bad commit messages
git commit -m "fix bug"
git commit -m "update"
git commit -m "wip"
```

**Commit message format:**

```
<type>: <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Example:**

```
feat: Add circuit breaker for external API calls

Implement circuit breaker pattern using :fuse library to prevent
cascading failures when Bitrix24 is unavailable.

- Add :fuse dependency
- Wrap BitrixClient calls in circuit breaker
- Add tests for circuit breaker behavior
- Update documentation

Closes #123
```

### 5. Push and Create Pull Request

```bash
# Push your branch
git push origin feature/your-feature-name

# Create PR on GitHub
# Fill out the PR template
```

### 6. PR Review Process

- Maintainers will review your PR
- Address any requested changes
- Once approved, your PR will be merged

**PR checklist:**
- [ ] Tests pass locally
- [ ] Code follows style guidelines
- [ ] Documentation updated
- [ ] Changelog updated (for significant changes)
- [ ] No merge conflicts

---

## 📏 Coding Standards

### Elixir Style Guide

We follow the [Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide):

**Do:**
```elixir
# Clear, descriptive function names
def process_call_event(%CallEventPayload{} = payload) do
  # Implementation
end

# Pattern matching in function heads
def handle_event(%{event_type: "stasis_start"} = event), do: create_call(event)
def handle_event(%{event_type: "stasis_end"} = event), do: finish_call(event)

# Pipe operator for data transformation
payload
|> normalize_event()
|> persist_to_database()
|> emit_telemetry()
```

**Don't:**
```elixir
# Vague function names
def process(x) do
  # ...
end

# Deep nesting
def handle(event) do
  if event.type == "start" do
    if event.valid do
      if event.caller do
        # ...
      end
    end
  end
end
```

### Code Formatting

```bash
# Format code before committing
mix format

# Check formatting in CI
mix format --check-formatted
```

### Code Quality

```bash
# Run Credo for static analysis
mix credo --strict

# Run Dialyzer for type checking
mix dialyzer
```

---

## 🧪 Testing Guidelines

### Test Structure

```elixir
defmodule CallFlowEngine.MyModuleTest do
  use CallFlowEngine.DataCase, async: true
  
  alias CallFlowEngine.MyModule
  
  describe "my_function/1" do
    test "handles valid input" do
      # Given
      input = %{valid: true}
      
      # When
      result = MyModule.my_function(input)
      
      # Then
      assert {:ok, _} = result
    end
    
    test "handles invalid input" do
      # Given
      input = %{valid: false}
      
      # When
      result = MyModule.my_function(input)
      
      # Then
      assert {:error, _} = result
    end
  end
end
```

### Test Coverage

- **New features:** Must have >80% test coverage
- **Bug fixes:** Must include regression test
- **Refactoring:** Maintain existing coverage

```bash
# Check coverage
mix test --cover

# Coverage report in cover/
open cover/excoveralls.html
```

### Test Types

**Unit Tests:**
- Test individual functions
- Mock external dependencies
- Fast execution

**Integration Tests:**
- Test component interactions
- Use test database
- Realistic scenarios

**End-to-End Tests:**
- Test full workflows
- Minimal mocking
- Production-like environment

---

## 📚 Documentation

### Code Documentation

```elixir
@moduledoc """
Brief module description.

More detailed explanation of what this module does,
its responsibilities, and how to use it.

## Examples

    iex> MyModule.my_function(arg)
    {:ok, result}
"""

@doc """
Brief function description.

## Parameters

- `arg1` - Description of first argument
- `arg2` - Description of second argument

## Returns

- `{:ok, result}` - Success case
- `{:error, reason}` - Failure case

## Examples

    iex> my_function(:valid_input)
    {:ok, :result}
    
    iex> my_function(:invalid)
    {:error, :invalid_input}
"""
@spec my_function(atom()) :: {:ok, atom()} | {:error, atom()}
def my_function(arg) do
  # Implementation
end
```

### README Updates

When adding features, update relevant sections in:
- `README.md` (English)
- `README.ru.md` (Russian)
- `ARCHITECTURE.md` (if architecture changed)
- `PERFORMANCE.md` (if performance affected)

### Changelog

Update `CHANGELOG.md` for significant changes:

```markdown
## [Unreleased]

### Added
- New feature X with Y capability

### Changed
- Improved performance of Z by 2x

### Fixed
- Bug in A that caused B

### Deprecated
- Feature C will be removed in v1.0
```

---

## 👥 Community

### Communication Channels

- **GitHub Issues** - Bug reports, feature requests
- **GitHub Discussions** - General questions, ideas
- **Pull Requests** - Code contributions

### Getting Help

- Read the [Documentation](INDEX.md)
- Check [existing issues](https://github.com/mostachev/call-flow-engine/issues)
- Ask in [Discussions](https://github.com/mostachev/call-flow-engine/discussions)

### Recognition

Contributors will be:
- Listed in `CONTRIBUTORS.md`
- Mentioned in release notes
- Acknowledged in relevant documentation

---

## 🏆 Good First Issues

Looking to contribute but not sure where to start? Check issues labeled:

- `good first issue` - Beginner-friendly
- `help wanted` - We need your help!
- `documentation` - Improve docs

---

## 📋 PR Template

```markdown
## Description
Brief description of what this PR does.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Tests pass locally
- [ ] Added new tests
- [ ] Updated existing tests

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-reviewed my code
- [ ] Commented hard-to-understand areas
- [ ] Updated documentation
- [ ] No new warnings
- [ ] Added tests that prove fix/feature works
- [ ] New and existing tests pass

## Related Issues
Fixes #(issue number)
```

---

## 🙏 Thank You!

Your contributions make CallFlowEngine better for everyone. We appreciate your time and effort!

---

**Questions?** Open a [Discussion](https://github.com/mostachev/call-flow-engine/discussions)

**Found a security issue?** Email security@yourdomain.com (Do NOT create public issue)

---

**Happy Contributing!** 🚀
