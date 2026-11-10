"""STUB (red phase): asset checker. Reports no failures, so every 'detects X' test fails."""
from dataclasses import dataclass, field


@dataclass
class Finding:
    key: str
    check: str
    message: str = ""


@dataclass
class CheckResult:
    failures: list = field(default_factory=list)


def run_check(directory, *args):
    return CheckResult()


def run_check_against_today(directory, *args):
    return CheckResult()


def main(argv=None):
    return 0
