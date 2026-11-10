"""STUB (red phase): manifest and source loading."""


class SourceHashMismatch(Exception):
    pass


def load_manifest(path=None):
    raise NotImplementedError


def verify_sha256(data, expected, label):
    return None
