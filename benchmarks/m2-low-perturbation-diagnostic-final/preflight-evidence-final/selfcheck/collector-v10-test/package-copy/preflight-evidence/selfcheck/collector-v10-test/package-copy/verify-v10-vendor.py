#!/usr/bin/env python3
"""Verify vendored v10 parity except the declared exact-endpoint delta."""
import argparse
import hashlib
import pathlib


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--reference", required=True)
    parser.add_argument("--vendor", required=True)
    args = parser.parse_args()
    reference = pathlib.Path(args.reference)
    vendor = pathlib.Path(args.vendor)
    ref_paths = {p.relative_to(reference).as_posix() for p in reference.rglob("*")
                 if p.is_file()}
    got_paths = {p.relative_to(vendor).as_posix() for p in vendor.rglob("*")
                 if p.is_file()}
    if ref_paths != got_paths:
        raise SystemExit("verify-v10-vendor: path closure")
    for relative in sorted(ref_paths - {"collect-v10.py"}):
        if digest(reference / relative) != digest(vendor / relative):
            raise SystemExit("verify-v10-vendor: drift: %s" % relative)
    original = (reference / "collect-v10.py").read_text()
    current = (vendor / "collect-v10.py").read_text()
    if original == current or "def exact_endpoint(command):" not in current:
        raise SystemExit("verify-v10-vendor: missing declared delta")
    if 'subprocess.run(["pgrep"' in current or \
            'os.environ["ENDPOINT_PATTERN"]' in current:
        raise SystemExit("verify-v10-vendor: regex endpoint remains")
    print("v10_vendor_other_files=%d" % (len(ref_paths) - 1))
    print("collect_v10_original_sha256=%s" %
          digest(reference / "collect-v10.py"))
    print("collect_v10_exact_sha256=%s" % digest(vendor / "collect-v10.py"))
    print("verify-v10-vendor: PASS")


if __name__ == "__main__":
    main()

