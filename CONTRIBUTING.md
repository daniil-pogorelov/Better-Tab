# Contributing to BetterTab

## A Note on Contributions

BetterTab is primarily a solo-developed project. While I (Daniil Pogorelov) am the main contributor and intend to do most of the development, I am open to high-quality contributions that align with the project's vision and roadmap.

If you have an idea for a significant improvement or a new feature, please **start by opening an issue to discuss it first.** This helps ensure that your efforts are well-aligned with the project's direction and avoids duplicated work. All contributions, especially code changes, will be thoroughly reviewed for quality, security (e.g., checking for backdoors), and overall fit.

Thank you for your understanding and interest in BetterTab!

---

First off, thank you for considering contributing to BetterTab! It's people like you that make open source software such a great community.

We welcome any type of contribution, not only code. You can help with:

* **Reporting a bug**
* **Discussing the current state of the code**
* **Submitting a fix (after discussion)**
* **Proposing new features (please discuss first)**
* **Improving documentation**

## How to Contribute

There are several ways you can contribute to BetterTab:

### Reporting Bugs

If you find a bug, please ensure the bug was not already reported by searching on GitHub under [Issues](https://github.com/daniil-pogorelov/Better-Tab/issues).

If you're unable to find an open issue addressing the problem, [open a new one](https://github.com/daniil-pogorelov/Better-Tab/issues/new). Be sure to include a **title and clear description**, as much relevant information as possible, and a **code sample or an executable test case** demonstrating the expected behavior that is not occurring.

Provide information about your environment:
* macOS version
* BetterTab version
* Xcode version (if building from source)
* Any relevant hardware information

### Suggesting Enhancements

If you have an idea for a new feature or an improvement to an existing one, **please open an issue to discuss it first.** This is crucial to ensure your ideas can be integrated smoothly.

When suggesting an enhancement:
* Clearly describe the proposed enhancement and its benefits.
* Explain how it would work or what it would look like.
* If possible, provide examples or mockups.
* Be prepared for a discussion about how it fits into the project.

### Pull Requests

Pull requests for bug fixes or approved features are welcome. **Please ensure you have discussed your planned changes in an issue before submitting a large PR.**

1.  **Fork the repository** to your own GitHub account.
2.  **Clone your fork** to your local machine: `git clone https://github.com/YOUR_USERNAME/Better-Tab.git`
3.  **Create a new branch** for your changes: `git checkout -b feature/your-feature-name` or `fix/your-bug-fix-name`.
4.  **Make your changes** and **commit them** with clear and descriptive commit messages.
5.  **Ensure your code builds and all tests pass.**
6.  **Push your changes** to your fork: `git push origin feature/your-feature-name`.
7.  **Open a pull request** from your fork to the `main` branch of the `daniil-pogorelov/Better-Tab` repository.
    * Ensure the PR description clearly describes the problem and solution. Include the relevant issue number.
    * Be prepared for a thorough code review.

## Development Setup

To get started with developing BetterTab:

1.  **Clone the repository** (or your fork):
    ```bash
    git clone [https://github.com/daniil-pogorelov/Better-Tab.git](https://github.com/daniil-pogorelov/Better-Tab.git)
    cd BetterTab
    ```
2.  **Open `BetterTab.xcodeproj` in Xcode.**
3.  **Requirements:**
    * macOS 14.0 or later
    * Xcode 16 or later (as specified in your `README.md` and GitHub Actions workflows) [cite: uploaded:daniil-pogorelov/Better-Tab/Better-Tab-2a131efbffc0bd48bf12b71306f8ada0cf042c1a/README.md, uploaded:daniil-pogorelov/Better-Tab/Better-Tab-2a131efbffc0bd48bf12b71306f8ada0cf042c1a/.github/workflows/swift_t.yml, uploaded:daniil-pogorelov/Better-Tab/Better-Tab-2a131efbffc0bd48bf12b71306f8ada0cf042c1a/.github/workflows/swift.yml]

You can find more details on building from source in the [README.md](./README.md#building-from-source) file. [cite: uploaded:daniil-pogorelov/Better-Tab/Better-Tab-2a131efbffc0bd48bf12b71306f8ada0cf042c1a/README.md]

## Coding Standards

While we don't have a strict set of coding standards enforced by a linter yet, please try to follow the existing code style. Some general guidelines:

* **Swift:** Follow standard Swift conventions and best practices.
* **Readability:** Write clear, concise, and well-commented code. Explain complex logic.
* **Logging:** Utilize `os.log` for logging, as seen in the existing codebase. Define a specific `OSLog` object for each class or major component. [cite: uploaded:daniil-pogorelov/Better-Tab/Better-Tab-2a131efbffc0bd48bf12b71306f8ada0cf042c1a/BetterTab/BetterTab/App Core/AppDelegate.swift, uploaded:daniil-pogorelov/Better-Tab/Better-Tab-2a131efbffc0bd48bf12b71306f8ada0cf042c1a/BetterTab/BetterTab/Switcher/AppSwitcherController.swift, uploaded:daniil-pogorelov/Better-Tab/Better-Tab-2a131efbffc0bd48bf12b71306f8ada0cf042c1a/BetterTab/BetterTab/Preferences/PreferencesManager.swift]
* **Error Handling:** Implement robust error handling.
* **Commit Messages:** Write clear and concise commit messages, explaining the "what" and "why" of your changes.

## Testing

* **Unit Tests:** We have a suite of unit tests located in `BetterTab/BetterTabTests/BetterTabTests.swift`. If you add new features or fix bugs, please add corresponding unit tests. [cite: uploaded:daniil-pogorelov/Better-Tab/Better-Tab-2a131efbffc0bd48bf12b71306f8ada0cf042c1a/BetterTab/BetterTabTests/BetterTabTests.swift]
* **Running Tests:** You can run tests using Xcode's Test navigator (`Cmd+U`) or via the command line as shown in the `.github/workflows/swift_t.yml` file: [cite: uploaded:daniil-pogorelov/Better-Tab/Better-Tab-2a131efbffc0bd48bf12b71306f8ada0cf042c1a/.github/workflows/swift_t.yml]
    ```bash
    xcodebuild \
      -project BetterTab/BetterTab.xcodeproj \
      -scheme BetterTab \
      -destination 'platform=macOS' \
      test \
      CODE_SIGNING_ALLOWED=NO \
      CODE_SIGNING_REQUIRED=NO \
      CODE_SIGN_IDENTITY=""
    ```
* **Manual Testing:** Thoroughly test your changes manually to ensure they work as expected and don't introduce regressions.

## Code of Conduct

This project and everyone participating in it is governed by the [BetterTab Code of Conduct](./CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to pogried@gmail.com.

## Questions?

If you have any questions, feel free to open an issue or reach out to the maintainers.

Thank you for contributing!
