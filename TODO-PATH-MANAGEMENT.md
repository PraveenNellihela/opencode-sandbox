# Design Decision: PATH Management

## Decision
The install.sh script does NOT automatically add ~/bin to the user's PATH.
Instead, it prints a command for the user to copy-paste and run manually.

## Rationale
- Users should explicitly approve PATH changes to their shell config
- Avoids unexpected modifications to .bashrc/.zshrc
- Clearer for users to understand what was changed

## What install.sh does
- Checks if ~/bin is already in shell config
- If not, prints the exact command to run (echo export... >> ~/.zshrc)
- Also prints "source ~/.zshrc" to activate immediately

## What uninstall.sh does
- Prints the sed command to remove the PATH line from shell config
- Ends with reminder: "Remember to remove the PATH entry from your shell config"

## Status
Implemented 2026-07-24
