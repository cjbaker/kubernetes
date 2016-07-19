#!/bin/bash

# Copyright 2015 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

KUBE_ROOT=$(dirname "${BASH_SOURCE}")/..
source "${KUBE_ROOT}/hack/lib/init.sh"

kube::golang::setup_env

function generate_version() {
  local group_version=$1
  local TMPFILE="/tmp/types_swagger_doc_generated.$(date +%s).go"

  echo "Generating swagger type docs for ${group_version}"

  sed 's/YEAR/2016/' hack/boilerplate/boilerplate.go.txt > "$TMPFILE"
  echo "package ${group_version##*/}" >> "$TMPFILE"
  cat >> "$TMPFILE" <<EOF

// This file contains a collection of methods that can be used from go-restful to
// generate Swagger API documentation for its models. Please read this PR for more
// information on the implementation: https://github.com/emicklei/go-restful/pull/215
//
// TODOs are ignored from the parser (e.g. TODO(andronat):... || TODO:...) if and only if
// they are on one line! For multiple line or blocks that you want to ignore use ---.
// Any context after a --- is ignored.
//
// Those methods can be generated by using hack/update-generated-swagger-docs.sh

// AUTO-GENERATED FUNCTIONS START HERE
EOF

  go run cmd/genswaggertypedocs/swagger_type_docs.go -s \
    "pkg/$(kube::util::group-version-to-pkg-path "${group_version}")/types.go" \
    -f - \
    >>  "$TMPFILE"

  echo "// AUTO-GENERATED FUNCTIONS END HERE" >> "$TMPFILE"

  gofmt -w -s "$TMPFILE"
  mv "$TMPFILE" "pkg/$(kube::util::group-version-to-pkg-path "${group_version}")/types_swagger_doc_generated.go"
}

GROUP_VERSIONS=(unversioned v1 authentication/v1beta1 authorization/v1beta1 autoscaling/v1 batch/v1 batch/v2alpha1 extensions/v1beta1 apps/v1alpha1 policy/v1alpha1 rbac/v1alpha1 certificates/v1alpha1)
# To avoid compile errors, remove the currently existing files.
for group_version in "${GROUP_VERSIONS[@]}"; do
  rm -f "pkg/$(kube::util::group-version-to-pkg-path "${group_version}")/types_swagger_doc_generated.go"
done
for group_version in "${GROUP_VERSIONS[@]}"; do
  generate_version "${group_version}"
done
