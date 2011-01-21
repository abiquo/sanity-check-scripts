#!/usr/bin/env python

"""Copyright (c) 2010 Abiquo Holdings

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
"""

__license__ = "MIT http://www.opensource.org/licenses/mit-license.php"
__author__ = "Ignasi Barrera (ignasi.barrera@abiquo.com)"
__version__ = "0.1"


RESET = "\033[0m"
GREEN = "\033[1;32m"
RED = "\033[1;31m"
YELLOW = "\033[1;33m"


def test(label, condition, ok_msg="OK", fail_msg="MISSING", warn=False):
    """Tests the condition and print the result"""
    if condition:
        success(label, ok_msg)
    elif warn:
        warning(label, fail_msg)
    else:
        fail(label, fail_msg)

def title(label):
    """Prints a title"""
    print YELLOW + label + RESET

def success(label, result):
    """Prints a success flag"""
    print_result(label, GREEN + result + RESET)

def fail(label, result):
    """Prints a failure flag"""
    print_result(label, RED + result + RESET)

def warning(label, result):
    """Prints a warning flag"""
    print_result(label, YELLOW + result + RESET)

def print_result(label, result):
    """Prints the result"""
    print label,
    print "[  %s  ]".rjust(75 - len(label)) % result

