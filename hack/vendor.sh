#!/bin/bash

set -e

modules=". testutils"

echo "Updating dependencies for all modules in workspace"

go work use -r .

# Pass 1: tidy all modules
echo "Running go mod tidy for all modules (pass 1)..."
for module in ${modules}; do
  if [ -f "$module/go.mod" ]; then
    echo "Tidying $module"
    (cd "$module" && go mod tidy)
  fi
done

# Sync: propagate highest require versions across all modules
echo "Syncing Go workspace..."
go work sync

# Pass 2: re-tidy after sync may have bumped versions
echo "Running go mod tidy for all modules (pass 2)..."
for module in ${modules}; do
  if [ -f "$module/go.mod" ]; then
    echo "Tidying $module"
    (cd "$module" && go mod tidy)
  fi
done

# Verify all modules
echo "Verifying all modules..."
for module in ${modules}; do
  if [ -f "$module/go.mod" ]; then
    echo "Verifying $module"
    (cd "$module" && go mod verify)
  fi
done

# Create the unified workspace vendor directory and the module-local vendor
# directory used by the testutils tool entrypoints.
echo "Creating unified vendor directory..."
go work vendor -v

echo "Creating testutils vendor directory..."
(cd testutils && GOWORK=off go mod vendor)

# These upstream documentation files contain trailing whitespace (and, for
# recvcheck, no final newline). Normalize the generated copies so they satisfy
# this repository's whitespace checks and repeated vendoring is deterministic.
normalized_files=(
  vendor/github.com/go-openapi/jsonpointer/README.md
  vendor/github.com/dlclark/regexp2/v2/README.md
  vendor/github.com/pelletier/go-toml/v2/README.md
  vendor/github.com/pelletier/go-toml/v2/test-go-versions.sh
  vendor/github.com/raeperd/recvcheck/README.md
  vendor/github.com/ryancurrah/gomodguard/v2/README.md
  vendor/github.com/alecthomas/chroma/v2/lexers/embedded/lilypond.xml
  testutils/vendor/github.com/go-openapi/jsonpointer/README.md
  testutils/vendor/github.com/go-openapi/swag/mangling/BENCHMARK.md
  testutils/vendor/github.com/dlclark/regexp2/v2/README.md
  testutils/vendor/github.com/pelletier/go-toml/v2/README.md
  testutils/vendor/github.com/pelletier/go-toml/v2/test-go-versions.sh
  testutils/vendor/github.com/raeperd/recvcheck/README.md
  testutils/vendor/github.com/ryancurrah/gomodguard/v2/README.md
  testutils/vendor/github.com/alecthomas/chroma/v2/lexers/embedded/lilypond.xml
  testutils/vendor/go.uber.org/zap/CHANGELOG.md
)
for normalized_file in "${normalized_files[@]}"; do
  if [[ -f "${normalized_file}" ]]; then
    sed -i -e 's/[[:blank:]]*$//' "${normalized_file}"
  fi
done

# A few newly vendored documentation/schema files end with an extra blank line.
trimmed_files=(
  vendor/charm.land/lipgloss/v2/.goreleaser.yml
  vendor/github.com/alecthomas/chroma/v2/lexers/embedded/lilypond.xml
  vendor/k8s.io/api/lifecycle/v1alpha1/generated.proto
  vendor/k8s.io/api/scheduling/v1alpha3/generated.proto
  vendor/k8s.io/api/storagemigration/v1/generated.proto
  testutils/vendor/charm.land/lipgloss/v2/.goreleaser.yml
  testutils/vendor/github.com/alecthomas/chroma/v2/lexers/embedded/lilypond.xml
  testutils/vendor/k8s.io/api/lifecycle/v1alpha1/generated.proto
  testutils/vendor/k8s.io/api/scheduling/v1alpha3/generated.proto
  testutils/vendor/k8s.io/api/storagemigration/v1/generated.proto
  testutils/vendor/k8s.io/api/storagemigration/v1beta1/generated.proto
)
for trimmed_file in "${trimmed_files[@]}"; do
  if [[ -f "${trimmed_file}" ]]; then
    sed -i -e '${/^$/d;}' "${trimmed_file}"
  fi
done

# Preserve the upstream Markdown heading while avoiding a seven-equals line
# that git mistakes for a merge-conflict marker in a newly vendored file.
sed -i -e 's/^=======$/======/' vendor/github.com/stretchr/testify/internal/spew/README.md
sed -i -e 's/^=======$/======/' testutils/vendor/github.com/stretchr/testify/internal/spew/README.md

# Normalize mixed space/tab indentation in the vendored help transcript.
sed -i -e 's/^    \t/        /' vendor/github.com/ryancurrah/gomodguard/v2/README.md
sed -i -e 's/^    \t/        /' testutils/vendor/github.com/ryancurrah/gomodguard/v2/README.md
