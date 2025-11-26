# Tests

This directory contains tests for the repository scripts.

## Running Tests Locally

We use [Jest](https://jestjs.io/) to run TypeScript-based tests against the shell scripts.

### Prerequisites

1.  **Install Dependencies**:
    ```bash
    npm install
    ```

### Running

Run the tests from the repository root:

```bash
npm test
```

## How it works

The tests use `child_process` to execute functions from `entrypoint.sh` in a shell environment.
The `tests/entrypoint.test.ts` file contains a helper `runShellFunction` that:
1. Sources `entrypoint.sh` (with `SOURCED_FOR_TEST=true` to prevent main execution).
2. Executes the specific function with arguments.
3. Captures stdout, stderr, and exit code.
4. Optionally captures internal variables for assertion.
