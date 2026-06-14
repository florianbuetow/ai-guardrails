#!/bin/bash

set -e  # Exit on error

echo ""
echo "Setting up AI project template aliases..."
echo ""

# Repository configuration
REPO_URL="https://github.com/florianbuetow/ai-guardrails.git"
TEMPLATES_DIR="$HOME/scripts/ai-guardrails"
SETUP_DIR="$TEMPLATES_DIR/project-setup"

# Alias name -> setup script (one entry per supported language)
ALIASES=(
  "newpy:setup-project-python-claude.sh"
  "newjava:setup-project-java-claude.sh"
  "newgo:setup-project-go-claude.sh"
  "newcpp:setup-project-cpp-claude.sh"
  "newelixir:setup-project-elixir-claude.sh"
  "newrust:setup-project-rust-claude.sh"
  "newkotlin:setup-project-kotlin-claude.sh"
)
UPDATE_ALIAS="alias update-templates='cd ~/scripts/ai-guardrails && git pull && cd - > /dev/null'"

# Create ~/scripts directory if it doesn't exist
echo "Creating ~/scripts directory..."
mkdir -p ~/scripts
echo "✓ Directory created/verified: ~/scripts"
echo ""

# Clone or update the repository
if [ -d "$TEMPLATES_DIR/.git" ]; then
  echo "Updating existing ai-guardrails repository..."
  cd "$TEMPLATES_DIR"
  git pull --quiet
  echo "✓ Repository updated"
  echo ""
else
  echo "Cloning ai-guardrails repository to ~/scripts/ai-guardrails..."
  git clone --quiet "$REPO_URL" "$TEMPLATES_DIR"
  echo "✓ Repository cloned"
  echo ""
fi

# Verify every setup script exists, then make it executable
for entry in "${ALIASES[@]}"; do
  script_name="${entry#*:}"
  script_path="$SETUP_DIR/$script_name"
  if [ ! -f "$script_path" ]; then
    echo "✗ Error: $script_name not found in cloned repository"
    exit 1
  fi
  chmod +x "$script_path"
done

# Detect the user's shell
USER_SHELL=$(basename "$SHELL")
echo "Detected shell: $USER_SHELL"
echo ""

# Determine the correct RC file based on shell
RC_FILE=""
case "$USER_SHELL" in
  zsh)
    RC_FILE="$HOME/.zshrc"
    ;;
  bash)
    # Prefer .bashrc, fall back to .bash_profile
    if [ -f "$HOME/.bashrc" ]; then
      RC_FILE="$HOME/.bashrc"
    else
      RC_FILE="$HOME/.bash_profile"
    fi
    ;;
  fish)
    RC_FILE="$HOME/.config/fish/config.fish"
    ;;
  *)
    echo "✗ Unsupported shell: $USER_SHELL"
    echo "Please manually add the following aliases to your shell configuration:"
    echo ""
    for entry in "${ALIASES[@]}"; do
      alias_name="${entry%%:*}"
      script_name="${entry#*:}"
      echo "alias $alias_name='~/scripts/ai-guardrails/project-setup/$script_name'"
    done
    echo "$UPDATE_ALIAS"
    echo ""
    exit 1
    ;;
esac

echo "Using RC file: $RC_FILE"
echo ""

# Collect the aliases that are not already present in the RC file
missing=()
for entry in "${ALIASES[@]}"; do
  alias_name="${entry%%:*}"
  if grep -q "alias $alias_name=" "$RC_FILE" 2>/dev/null; then
    echo "⚠ Alias '$alias_name' already exists in $RC_FILE — skipping"
  else
    missing+=("$entry")
  fi
done

need_update_alias=true
if grep -q "alias update-templates=" "$RC_FILE" 2>/dev/null; then
  echo "⚠ Alias 'update-templates' already exists in $RC_FILE — skipping"
  need_update_alias=false
fi

if [ ${#missing[@]} -eq 0 ] && [ "$need_update_alias" = false ]; then
  echo ""
  echo "✓ All aliases already present — nothing to add."
else
  # Ensure the file ends with a newline before appending
  if [ -f "$RC_FILE" ] && [ -n "$(tail -c 1 "$RC_FILE")" ]; then
    echo "" >> "$RC_FILE"
  fi
  echo "# Aliases for AI project templates" >> "$RC_FILE"
  for entry in ${missing[@]+"${missing[@]}"}; do
    alias_name="${entry%%:*}"
    script_name="${entry#*:}"
    echo "alias $alias_name='~/scripts/ai-guardrails/project-setup/$script_name'" >> "$RC_FILE"
    echo "✓ Added alias '$alias_name'"
  done
  if [ "$need_update_alias" = true ]; then
    echo "$UPDATE_ALIAS" >> "$RC_FILE"
    echo "✓ Added alias 'update-templates'"
  fi
  echo ""
fi

echo "================================================"
echo "Setup complete!"
echo "================================================"
echo ""
echo "To start using the aliases:"
echo ""
echo "  1. Reload your shell configuration:"
echo "     source $RC_FILE"
echo ""
echo "  2. Create a new project (one alias per language):"
echo "     newpy my-project        # Python"
echo "     newjava my-project      # Java"
echo "     newgo my-project        # Go"
echo "     newcpp my-project       # C++"
echo "     newelixir my-project    # Elixir"
echo "     newrust my-project      # Rust"
echo "     newkotlin my-project    # Kotlin"
echo ""
echo "  3. Update templates to latest version:"
echo "     update-templates"
echo ""
echo "Or simply open a new terminal window."
echo ""
