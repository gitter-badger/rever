"""Custom environment handling tools for rever."""
import re
from contextlib import contextmanager

from xonsh.environ import Ensurer, VarDocs
from xonsh.tools import (is_string, ensure_string, always_false, always_true,
                         is_string_set, csv_to_set, set_to_csv, is_nonstring_seq_of_strings)

from rever.logger import Logger


def to_logger(x):
    """If x is a string, this will be set as $LOGGER.filename and then returns $LOGGER.
    Otherwise, returns x if x is a Logger already.
    """
    if isinstance(x, Logger):
        rtn = x
    elif isinstance(x, str):
        rtn = $LOGGER
        rtn.filename = x
    else:
        raise ValueError("could not convert {x!r} to a Logger object.".format(x=x))
    return rtn


def detype_logger(x):
    """Returns the filename of the logger."""
    return  x.filename


def default_dag():
    """Creates a default activity DAG."""
    from rever.activities.changelog import Changelog
    from rever.activities.tag import Tag
    from rever.activities.version_bump import VersionBump
    dag = {
        'changelog': Changelog(),
        'tag': Tag(),
        'version_bump': VersionBump(),
    }
    return dag


def csv_to_list(x):
    """Converts a comma separated string to a list of strings."""
    return x.split(',')


def list_to_csv(x):
    """Converts a list of str to a comma-separated string."""
    return ','.join(x)


# key = name
# value = (default, validate, convert, detype, docstr)
ENVVARS = {
    'ACTIVITIES': ([], is_nonstring_seq_of_strings, csv_to_list, list_to_csv,
                   'Default list of activity names for rever to execute, if they have '
                   'not already been executed.'),
    re.compile('ACTIVITIES_\w*'): ([], is_nonstring_seq_of_strings, csv_to_list, list_to_csv,
                                   'A list of activity names for rever to execute for the entry '
                                   'point named after the first underscore.'),
    'DAG': (default_dag(), always_true, None, str,
                     'Directed acyclic graph of '
                     'activities as represented by a dict with str keys and '
                     'Activity objects as values.'),
    'LOGGER': (Logger('rever.log'), always_false, to_logger, detype_logger,
               "Rever logger object. Setting this variable to a string will "
               "change the filename of the logger."),
    'REVER_DIR': ('rever', is_string, str, ensure_string, 'Path to directory '
                  'used for storing rever temporary files.'),
    'REVER_VCS': ('git', is_string, str, ensure_string, "Name of version control "
                  "system to use, such as 'git' or 'hg'"),
    'RUNNING_ACTIVITIES': ([], is_nonstring_seq_of_strings, csv_to_list, list_to_csv,
                           'List of activity names that rever is actually executing.'),
    'VERSION': ('x.y.z', is_string, str, ensure_string, 'Version string of new '
                'version that is being released.'),
    }


def setup():
    for key, (default, validate, convert, detype, docstr) in ENVVARS.items():
        if key in ${...}:
            del ${...}[key]
        ${...}._defaults[key] = default
        ${...}._ensurers[key] = Ensurer(validate=validate, convert=convert,
                                        detype=detype)
        ${...}._docs[key] = VarDocs(docstr=docstr)


def teardown():
    for key in ENVVARS:
        ${...}._defaults.pop(key)
        ${...}._ensurers.pop(key)
        ${...}._docs.pop(key)
        if key in ${...}:
            del ${...}[key]


@contextmanager
def context():
    setup()
    yield
    teardown()
