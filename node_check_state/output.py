#!/usr/bin/env python


RESET = "\033[0m"
BOLD = "\033[1;33m"
GREEN = "\033[1;32m"
RED = "\033[1;31m"

def bold(text):
    print BOLD + text + RESET

def test(condition):
    if condition:
        ok()
    else:
        fail()

def ok():
    __result(GREEN + "OK" + RESET)

def fail():
    __result(RED + "MISSING" + RESET)

def __result(text):
    print "\t\t\t[  " + text + "  ]"
