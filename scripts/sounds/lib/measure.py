"""STUB (red phase): loudness / analysis."""

MONO_CONVENTION = ""


def read_audio(path):
    raise NotImplementedError


def lufs(x, rate):
    raise NotImplementedError


def median_short_term(x, rate):
    raise NotImplementedError


def true_peak_db(x, rate):
    raise NotImplementedError


def ffmpeg_loudness(path):
    raise NotImplementedError


def max_quiet_run_s(x, rate):
    raise NotImplementedError


def seam_metrics(x, rate):
    raise NotImplementedError


def binaural_separation_db(x, rate):
    raise NotImplementedError
