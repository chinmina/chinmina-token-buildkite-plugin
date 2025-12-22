#!/bin/bash
# Shared test helpers for chinmina-token-buildkite-plugin tests

# Helper: Create a stub bin directory and prepend to PATH
setup_stub_bin() {
  export STUB_BIN_DIR="${TMPDIR}/stub-bin"
  mkdir -p "${STUB_BIN_DIR}"
  export PATH="${STUB_BIN_DIR}:${PATH}"
}

# Helper: Add openssl stub that passes version checks and can encrypt/decrypt
add_openssl_stub() {
  local stub_script="${STUB_BIN_DIR}/openssl"

  cat > "${stub_script}" << 'STUB'
#!/bin/bash
# openssl stub for testing
if [[ "$1" == "version" ]]; then
  echo "OpenSSL 1.1.1 (stub)"
  exit 0
fi
# Encryption: openssl enc ... -out <file> -pass ...
# Find -out argument and write base64 encoded data there
if [[ "$1" == "enc" && "$2" != "-d" ]]; then
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == "-out" ]]; then
      shift
      base64 > "$1"
      exit 0
    fi
    shift
  done
fi
# Decryption: openssl enc -d ... -in <file> -pass ...
if [[ "$1" == "enc" && "$2" == "-d" ]]; then
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == "-in" ]]; then
      shift
      base64 -d < "$1"
      exit 0
    fi
    shift
  done
fi
exit 1
STUB
  chmod +x "${stub_script}"
}
