#!/usr/bin/python3
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#
#   Script Name : log.py
#        Author : Ecometer s.n.c.
#          Date : 2024-09-30
#   Description : Logging file
#
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
"""
    Manage logging stuff
"""
import sys
import os
import logging
import logging.handlers

# cannot be run directly
if __name__ == '__main__':
    sys.exit(0)

# default level
LOG_LEVEL = logging.DEBUG

# path
logpath = os.path.join(os.path.dirname(os.path.realpath(__file__)), 'log')
if not os.path.exists(logpath):
    os.makedirs(logpath)

# script name
file_name = os.path.basename(sys.argv[0])

# log name
logdatafile = os.path.join(logpath, file_name + '.log')

# logging custom level
logging.VERBOSE = 5
logging.addLevelName(logging.VERBOSE, 'VERBOSE')
logging.Logger.verbose = lambda inst, msg, *args, **kwargs: inst.log(logging.VERBOSE, msg, *args, **kwargs)
logging.verbose = lambda msg, *args, **kwargs: logging.log(logging.VERBOSE, msg, *args, **kwargs)

# formatter
formatter = logging.Formatter('%(asctime)s-%(levelname)s: %(message)s')

# rotation -  max 100 MB
handler = logging.handlers.RotatingFileHandler(logdatafile, maxBytes=10*1024*1024, backupCount=100)
handler.setFormatter(formatter)
logging.getLogger(__name__).addHandler(handler)

# console
console = logging.StreamHandler()
# formatter
formatter_console = logging.Formatter('%(asctime)s-%(levelname)s: %(message)s')
#formatter_console = logging.Formatter('%(message)s')
console.setFormatter(formatter_console)
logging.getLogger(__name__).addHandler(console)

# set custom level
logging.getLogger(__name__).setLevel(LOG_LEVEL)
console.setLevel(LOG_LEVEL)

# set logging for suds
logging.getLogger('suds.client').setLevel(logging.WARNING)
logger = logging.getLogger(__name__)

# https://docs.python.org/3.4/library/logging.handlers.html?highlight=backupcount
# CRITICAL 50
# ERROR    40
# WARNING  30
# INFO     20
# DEBUG    10
# VERBOSE   5
# NOTSET    0

def set_log(log_level):
    # set custom level
    logging.getLogger(__name__).setLevel(log_level)
    console.setLevel(log_level)
