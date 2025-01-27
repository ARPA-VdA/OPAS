#!/usr/bin/python3
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#
#   Script Name : config.py
#        Author : Ecometer s.n.c.
#          Date : 2024-09-30
#   Description : Configuration file
#
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
import sys
import platform
"""
    Application settings
"""
# cannot be run directly
if __name__ == '__main__':
    sys.exit(0)

# main config
IPR = {
    'idrete'   : 1,   # 1 ArpaVDA RMQA
    'idregione': '02' # id infoaria
}

# server database
PGCNF = {
    'host'    : '',
    'port'    : 6432,
    'user'    : '',
    'password': '',
    'database': 'opas_ispra',
    'appname' : '',
}

# server ftp
FTPCNF = {
    'host': '',
    'port': 21,
    'user': '',
    'pass': '',
    'path': '',
    'pasv': True
}

# server HTTP
HTTP = {
    'url': ''
}
