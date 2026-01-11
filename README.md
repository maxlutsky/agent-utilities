# agent-utilities
Small collection of skills and helpers for any coding agent.

## Included skills
- `commit-style` (local)

## Symlinked skills (Dimillian)
The following skills are symlinked from the Dimillian submodule:
- `swift-concurrency-expert`
- `swiftui-liquid-glass`
- `swiftui-performance-audit`
- `swiftui-ui-patterns`
- `swiftui-view-refactor`

## Setup
Clone with submodules:
```bash
git clone --recurse-submodules <repo-url>
```

If already cloned, initialize and update:
```bash
git submodule update --init --recursive
```

To pull the latest from the submodule default branch:
```bash
git submodule update --remote submodules/Dimillian/Skills
```

After updating the submodule, commit the updated submodule pointer in this repo.
