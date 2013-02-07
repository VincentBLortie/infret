#!/usr/bin/env python


# TODO: Read from command line
document_dir = u'/home/hellfire/Code/infret/a1/en/'
index_dir = u'/home/hellfire/Code/infret/a1/idx/'


import xapian
import os
import sys
import os.path
from nltk.corpus import wordnet

def find_synonyms(word):
    synonyms = set()
    wnset = wordnet.synsets(word)
    for synset in wnset:
        for synwords in synset.lemma_names:
            synonyms.add(synwords.replace('_', ' '))
    try:
        synonyms.remove(word)
    except:
        pass
    return synonyms

def _count_terms(db):
    # TODO: This must be stored somewhere, figure out how to get it
    return sum(1 for _ in db.allterms('Z'))

def add_synonyms(db, words):
    count = 0

    for word in words:
        count += 1
        synonyms = find_synonyms(word)
        for synonym in synonyms:
            db.add_synonym('Z' + word, synonym)
        yield (count, word, synonyms)

if __name__ == '__main__':
    # Build the index
    if not os.path.isdir(index_dir):
        os.makedirs(index_dir)

    db = xapian.WritableDatabase(index_dir, xapian.DB_OPEN)

    # Count number of terms
    print 'Counting terms...',
    sys.stdout.flush()
    n_terms = _count_terms(db)
    print n_terms
    print 'Finding synonyms...'

    db.begin_transaction()
    for count, word, synonyms in add_synonyms(db, (x.term[1:] for x in db.allterms('Z'))):
        if count % 100 == 0:
            print '{0} of {1} ({2:.2%}):'.format(count, n_terms, count/float(n_terms)), word, '({})'.format(len(synonyms))
    db.commit_transaction()
