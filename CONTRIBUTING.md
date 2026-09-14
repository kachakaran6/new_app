# Contributing to CountSend

Thank you for your interest in contributing to CountSend! We welcome pull requests, bug reports, and feature proposals to make the app more reliable and feature-complete.

---

## Getting Started

1. **Fork the Repository**:
   Click the **Fork** button on GitHub to create your own copy of the repository under your GitHub account.

2. **Clone Your Fork**:
   ```bash
   git clone https://github.com/kachakaran6/new_app.git
   cd new_app
   ```

3. **Set Up Development Environment**:
   - Ensure Flutter SDK `>=3.19.0` is installed (`flutter --version`).
   - Run `flutter pub get` to install project dependencies.
   - Connect an Android device or launch an Android emulator (`flutter devices`).

---

## Branch Naming Convention

Always create a new branch from `main` for your work. Use descriptive prefixes:

- `feature/<description>` — for new capabilities or enhancements (e.g., `feature/vibration-feedback`)
- `fix/<description>` — for bug fixes (e.g., `fix/send-coordinate-scaling`)
- `docs/<description>` — for documentation updates (e.g., `docs/add-screenshots`)
- `refactor/<description>` — for code refactoring without feature changes (e.g., `refactor/theme-tokens`)
- `chore/<description>` — for tooling, dependency bumps, or repository maintenance (e.g., `chore/bump-gradle`)

---

## Commit Message Convention

We strictly follow the **[Conventional Commits](https://www.conventionalcommits.org/)** specification. Every commit message must take the format:

```
type(scope): concise imperative description

[optional body providing technical context]

[optional footer(s), e.g., Closes #123]
```

### Allowed Types
- `feat`: A new feature or capability
- `fix`: A bug fix
- `docs`: Documentation changes
- `style`: Code formatting, missing semicolons, etc. (no code logic changes)
- `refactor`: Code restructuring without changing external behavior
- `test`: Adding or correcting automated tests
- `chore`: Maintenance tasks, dependency updates, configuration changes
- `ci`: CI/CD workflow updates (GitHub Actions, etc.)
- `build`: Build system or Android Gradle modifications

### Examples
- `feat(countdown): add live d/h/m/s calculation engine`
- `fix(accessibility): ignore left-side attachment buttons when searching for Send`
- `docs(readme): update build requirements and screenshots`
- `ci(actions): add flutter test and lint verification workflow`

---

## Code Quality & Standards

Before opening a pull request, ensure your code satisfies the following requirements:

1. **Code Formatting**:
   Format all Dart files using the standard formatter:
   ```bash
   dart format --set-exit-if-changed .
   ```

2. **Static Analysis**:
   Ensure zero errors, warnings, or lints:
   ```bash
   flutter analyze
   ```

3. **Automated Testing**:
   Run all widget and unit tests:
   ```bash
   flutter test
   ```

---

## Opening a Pull Request

1. Push your branch to your GitHub fork:
   ```bash
   git push -u origin feature/your-feature-name
   ```
2. Open a Pull Request against the `main` branch.
3. Fill out the provided **Pull Request Template** completely.
4. Ensure all GitHub Actions CI checks pass.
5. Participate in the code review process. Once approved, your PR will be merged into `main`.
