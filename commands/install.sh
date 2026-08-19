#!/bin/bash
CLAUDE_DIR="$HOME/.claude"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$CLAUDE_DIR/commands"

# Copy all .md files preserving directory structure
find "$SCRIPT_DIR" -name "*.md" | while IFS= read -r file; do
    rel="${file#$SCRIPT_DIR/}"
    dest="$CLAUDE_DIR/commands/$rel"
    mkdir -p "$(dirname "$dest")"
    cp "$file" "$dest"
done

echo "✅ Claude commands instalados en $CLAUDE_DIR/commands"
echo "Comandos disponibles:"
find "$CLAUDE_DIR/commands" -name "*.md" | sort