# Build notes — v0.1.9

This package is intentionally self-consistent. Do not mix individual files from
older 0.1.4–0.1.8 revisions.

The GitHub Actions workflow validates the v0.1.9 control version, preference
keys, dynamic-color implementation, PreferenceBundle metadata, and the absence
of the unsafe long-press hooks before compiling.

The workflow installs `ldid` and `dpkg` explicitly and clones RootHide Theos
directly to avoid the previous `api.github.com` install-theos failure.
