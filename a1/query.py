#!/usr/bin/env python


# TODO: Read from command line
document_dir = u'/home/hellfire/Code/infret/a1/en/'
index_dir = u'/home/hellfire/Code/infret/a1/idx/'
query_file = u'/home/hellfire/Ubuntu One/School/2013/01-Winter/INF/Assignments/1/Queries.txt'
sw_file = u'/home/hellfire/Code/infret/a1/stopwords.txt'

import xapian
import os
import os.path
import json
import nltk
from stopper import build_stopper


class QueryRunner(object):
    def __init__(self, index_dir, sw_file):
        self._load_db(index_dir)
        self._build_stopper(sw_file)
        self._build_parser()

    def expand(self, querystring):
        pass

    def _load_db(self, path):
        self.db = xapian.Database(path)

    def _build_stopper(self, path):
        self.stopper = build_stopper(path)

    def _build_parser(self):
        # Prepare the QueryParser with the same settings as the database
        queryparser = xapian.QueryParser()
        queryparser.set_stemmer(xapian.Stem('en'))
        queryparser.set_stemming_strategy(queryparser.STEM_SOME)
        queryparser.set_stopper(self.stopper)

        # Set up the fields
        queryparser.add_prefix('title', 'S')

        queryparser.set_database(self.db)

        self.queryparser = queryparser

    def search(self, querystring, offset=0, pagesize=10):
        '''offset -> starting point within resultset
        pagesize -> number of results to return'''

        queryparser = self.queryparser

        # Parse the query
        query = queryparser.parse_query(querystring, queryparser.FLAG_AUTO_SYNONYMS)

        enquire = xapian.Enquire(self.db)
        enquire.set_query(query)
        enquire.set_cutoff(20)

        for match in enquire.get_mset(offset, pagesize):
            yield match

runner = QueryRunner(index_dir, sw_file)

# Generate an identifier
import random
run_tag = hex(random.randint(0, 0xFFFFFFFF))

with open(query_file) as f:
    for line in f:
        qid, query = line.split(':', 1)
        for result in runner.search(query, 0, 20):
            document = 'en/' + result.document.get_data()
            rank = result.rank  # Xapian is 0-based
            percent = result.percent

            print '{0}\t1\t{1}\t{2}\t{3}\t{4}'.format(qid, document,
                                                rank, percent, run_tag)
