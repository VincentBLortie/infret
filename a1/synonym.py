#!/usr/bin/env python


# TODO: Read from command line
document_dir = u'/home/hellfire/Code/infret/a1/en/'
index_dir = u'/home/hellfire/Code/infret/a1/idx/'


import xapian
import os
import os.path
from nltk.corpus import wordnet

# Build the index
if not os.path.isdir(index_dir):
    os.makedirs(index_dir)

db = xapian.WritableDatabase(index_dir, xapian.DB_OPEN)

# Count number of terms

# TODO: This must be stored somewhere, figure out how to get it
print 'Counting terms...',
n_terms = sum(1 for _ in db.allterms('Z'))
print n_terms

print 'Finding synonyms...'
count = 0

db.begin_transaction()

for word in db.allterms('Z'):
    count += 1
    word = word.term[1:]

    synonyms = set()
    wnset = wordnet.synsets(word)
    for synset in wnset:
        for synwords in synset.lemma_names:
            synonyms.add(synwords.replace('_', ' '))
    try:
        synonyms.remove(word)
    except:
        pass

    if count % 100 == 0:
        print '{0} of {1} ({2:.2%}):'.format(count, n_terms, count/float(n_terms)), word, '({})'.format(len(synonyms))

    for synonym in synonyms:
        db.add_synonym(word, 'Z' + synonym)

db.commit_transaction()
