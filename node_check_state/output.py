#!/usr/bin/env python


RESET = "\033[0m"
GREEN = "\033[1;32m"
RED = "\033[1;31m"
YELLOW = "\033[1;33m"

def test(label, condition):
    if condition:
        success(label)
    else:
        fail(label)

def title(label):
    print YELLOW + label + RESET

def success(label):
    print_result(label, GREEN + "OK" + RESET)

def fail(label):
    print_result(label, RED + "MISSING" + RESET)

def print_result(label, result):
    print label,
    print "[  %s  ]".rjust(70 - len(label)) % result

