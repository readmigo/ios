# Add Project Memory

This command adds a new memory to the project's CLAUDE.md file.

## Usage

```
/add-memory <memory content>
```

## Behavior

1. Read the current `.claude/CLAUDE.md` file
2. Add the memory as a bullet point in the appropriate section
3. Save the updated CLAUDE.md file
4. Confirm the memory has been added

## Examples

```
/add-memory Use SwiftUI @Observable instead of ObservableObject for new code
```

```
/add-memory Always validate deeplinks before processing
```
