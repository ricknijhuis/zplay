# About the Project

`zplay` is a game development framework written from scratch in Zig. The primary goal of this framework is to provide a simple and explicit API for creating games. It offers developers fine-grained control over aspects like rendering and window management, including support for multiple windows.

When reviewing pull requests, please keep the project's philosophy of simplicity and explicitness in mind.

## Folder structures
- `src/`: Contains the main source code of the framework.
- `examples/`: Contains example projects demonstrating how to use the framework.
- `.github/`: Contains GitHub-specific files, including issue and pull request templates.
- `build.zig`: The build script for the project.
- `build.zig.zon`: Containing the dependencies of the project, version, name and other metadata.

## Code Review Guidelines

### 1. Code Style and Conventions

- **Zig Standard Formatting**: All code must adhere to the standard Zig formatting conventions. Please flag any deviations from `zig fmt`.
- **Naming Conventions**: Ensure that variable names, function names, and type definitions are clear, descriptive, and follow Zig's `snake_case` for variables/functions and `PascalCase` for types.
- **Clarity and Readability**: The code should be easy to understand. Prefer clear and straightforward implementations over overly complex or "clever" solutions.

### 2. Spelling and Grammar

- Please check for and correct any spelling or grammatical errors in code comments, documentation, and user-facing strings.

### 3. Testing

- **Unit Tests**: All new logic, where feasible, should be accompanied by unit tests. We recognize that testing platform-specific code (like windowing or GPU rendering) can be challenging.
- **Testable Logic**: For code that is not platform-specific (e.g., math utilities, data structures, algorithms), tests are expected. If a pull request adds such logic without tests, please suggest adding them.
- **Pragmatism**: If testing a piece of code is genuinely impractical, that's acceptable. However, the default assumption should be that new code is tested.

### 4. API Design

- **Simplicity**: The public API should remain simple and intuitive. When reviewing changes to the API, consider if they make the framework easier or harder to use for its intended purpose.
- **Explicitness**: The framework favors explicitness. APIs should make it clear what they do, avoiding "magic" or hidden behavior. For example, resource management should be explicit.
- **Control**: Changes should empower the user by giving them more control over the framework's features, especially concerning rendering and windowing.

### 5. Documentation

- **Public API**: All public API functions, types, and variables must have clear and concise documentation comments.
- **Examples**: When new features are added, it is highly encouraged to add or update examples to demonstrate their usage.
