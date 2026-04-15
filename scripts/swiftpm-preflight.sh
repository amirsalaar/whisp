#!/bin/bash

swiftpm_can_load_scratch_package() {
  local scratch_dir

  scratch_dir=$(mktemp -d)
  if (
    cd "$scratch_dir" || exit 1
    swift package init --type executable >/dev/null 2>&1 || exit 1
    swift package dump-package >/dev/null 2>&1
  ); then
    rm -rf "$scratch_dir"
    return 0
  fi

  rm -rf "$scratch_dir"
  return 1
}

print_swiftpm_toolchain_error() {
  local manifest_output="$1"
  local developer_dir

  developer_dir=$(xcode-select -p 2>/dev/null || echo "unknown")

  echo "❌ Swift Package Manager could not evaluate Package.swift."
  echo ""
  echo "The active Apple toolchain is failing before VoiceFlow can build."
  echo "This machine cannot evaluate this manifest or a brand-new scratch package."
  echo ""
  echo "Active developer directory: $developer_dir"
  echo ""
  echo "Recommended fixes:"
  if [ "$developer_dir" = "/Library/Developer/CommandLineTools" ]; then
    echo "  1. Reinstall Command Line Tools:"
    echo "     sudo rm -rf /Library/Developer/CommandLineTools"
    echo "     xcode-select --install"
    echo "  2. Or install full Xcode and select it:"
    echo "     sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  else
    echo "  1. Reinstall or switch the active Xcode/Swift toolchain."
    echo "  2. Verify the toolchain with a scratch package:"
    echo "     swift package init --type executable"
    echo "     swift build"
  fi
  echo ""
  echo "Original SwiftPM error:"
  echo "$manifest_output" | sed -n '1,20p'
}

ensure_swiftpm_manifest_is_healthy() {
  local project_dir="${1:-$PWD}"
  local manifest_output

  if manifest_output=$(cd "$project_dir" && swift package dump-package 2>&1); then
    return 0
  fi

  if ! swiftpm_can_load_scratch_package; then
    print_swiftpm_toolchain_error "$manifest_output"
    return 1
  fi

  echo "$manifest_output"
  return 1
}
