#!/bin/bash

set -e

if [ ! -e "openssl.conf" ]; then
  >&2 echo "The configuration file 'openssl.conf' doesn't exist in this directory"
  exit 1
fi

certs_dir=/certs
usercerts_dir=/usercerts
ca_dir=/trust-anchors

rm -rf "${certs_dir}"
mkdir -p "${certs_dir}"
rm -rf "${usercerts_dir}"
mkdir -p "${usercerts_dir}"
rm -rf "${ca_dir}"
mkdir -p "${ca_dir}"

export CA_NAME=igi_test_ca
export X509_CERT_DIR="${ca_dir}"

make_ca.sh

# Create server certificates
for c in opa-pull_test_example opa-push_test_example nginx_test_example; do
  make_cert.sh ${c}
  cp igi_test_ca/certs/${c}.* "${certs_dir}"
done

chmod 600 "${certs_dir}"/*.cert.pem
chmod 400 "${certs_dir}"/*.key.pem
chmod 600 "${certs_dir}"/*.p12
chown 1000:1000 "${certs_dir}"/*

# Create user certificates
make_cert.sh test0
cp igi_test_ca/certs/test0.* "${usercerts_dir}"

chmod 600 "${usercerts_dir}"/*.cert.pem
chmod 400 "${usercerts_dir}"/*.key.pem
chmod 600 "${usercerts_dir}"/*.p12
chown 1000:1000 "${usercerts_dir}"/*

make_crl.sh
install_ca.sh igi_test_ca "${ca_dir}"

# Create a volume for igi-test-ca + system certificates bundle
ca_bundle=/etc/pki/tls/certs
echo -e "\n# igi-test-ca" >> "${ca_bundle}"/ca-bundle.crt
cat "${ca_dir}"/igi_test_ca.pem >> "${ca_bundle}"/ca-bundle.crt

buffer_bundle=/custom-ssl
mkdir -p "${buffer_bundle}"
cp "${ca_bundle}"/ca-bundle.crt "${buffer_bundle}"/ca-bundle.crt
cp "${ca_bundle}"/ca-bundle.crt "${buffer_bundle}"/ca-certificates.crt

