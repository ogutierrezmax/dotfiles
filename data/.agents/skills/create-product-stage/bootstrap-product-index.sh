#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_PATH="${SCRIPT_DIR}/product-development-template.md"

BASE_DIR="${1:-$(pwd)}"

TARGET_DIR="${BASE_DIR}/docs/product"
TARGET_INDEX="${TARGET_DIR}/index.md"
TARGET_TEMPLATE_COPY="${TARGET_DIR}/product-development-template.md"

if [[ -f "${TARGET_INDEX}" ]]; then
  echo "'docs/produc/index.md' existe."
  exit 0
fi

if [[ ! -f "${TEMPLATE_PATH}" ]]; then
  echo "Template não encontrado em ${TEMPLATE_PATH}."
  exit 1
fi

mkdir -p "${TARGET_DIR}"
cp "${TEMPLATE_PATH}" "${TARGET_DIR}/"
mv "${TARGET_TEMPLATE_COPY}" "${TARGET_INDEX}"

echo "Criado ${TARGET_INDEX} a partir de ${TEMPLATE_PATH}."
