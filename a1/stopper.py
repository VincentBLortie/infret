#!/usr/bin/env python

import xapian

def build_stopper(sw_file):
	stopper = xapian.SimpleStopper()

	with open(sw_file, 'r') as f:
		for word in f:
			stopper.add(word.strip())

	return stopper
