#!/usr/bin/env python


RESET = "\033[0m"
GREEN = "\033[1;32m"
RED = "\033[1;31m"
YELLOW = "\033[1;33m"

def test(label, condition, ok_msg = "OK", fail_msg = "MISSING", warn = False):
    if condition:
        success(label, ok_msg)
    elif warn:
        warning(label, fail_msg)
    else:
        fail(label, fail_msg)

def title(label):
    print YELLOW + label + RESET

def success(label, result):
    print_result(label, GREEN + result + RESET)

def fail(label, result):
    print_result(label, RED + result + RESET)

def warning(label, result):
    print_result(label, YELLOW + result + RESET)

def print_result(label, result):
    print label,
    print "[  %s  ]".rjust(75 - len(label)) % result

