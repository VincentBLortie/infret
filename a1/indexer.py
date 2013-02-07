#!/usr/bin/env python

# TODO: Read from command line
document_dir = u'/home/hellfire/Code/infret/a1/en/'
index_dir = u'/home/hellfire/Code/infret/a1/idx/'
sw_file = u'/home/hellfire/Code/infret/a1/stopwords.txt'


import xapian
import os
import os.path
from bs4 import BeautifulSoup

from stopper import build_stopper

# Gets the content out of Soup
def extract_content(soup):
    text_nodes = soup.findAll(text=True)
    return ' '.join(x.string for x in text_nodes)

# Parses a wiki file for information
def parse_wiki(root, path):
    abs_path = os.path.join(root, path)
    rel_path = os.path.relpath(abs_path, os.path.abspath(document_dir))

    with open(abs_path) as f:
        bs = BeautifulSoup(f)

    # Extract the title
    title = bs.find(attrs=u'pagetitle')
    if title:
        title = title.string
    elif bs.title:
        title = bs.title.string
    else:
        title = ''

    # Determine the type of page
    if bs.find(name=u'wx_redirect_page_id') is not None:
        page_type = 'redirect'
    elif title.startswith('Image:'):
        page_type = 'image'
    elif title.startswith('Category:'):
        page_type = 'category'
    elif '(disambiguation)' in title:
        page_type = 'disambiguation'
    else:
        page_type = 'content'

    content = ' '.join(extract_content(x) for x in bs.find_all('wx:section', level='1'))
    content = content.lower()
    content = content.replace('\n', ' ')

    return {'type': page_type, 'title': title, 'path': unicode(rel_path), 'content': content}



# Build the index
if not os.path.isdir(index_dir):
    os.makedirs(index_dir)

db = xapian.WritableDatabase(index_dir, xapian.DB_CREATE_OR_OPEN)

# Build the Stopper

stopper = build_stopper(sw_file)

termgenerator = xapian.TermGenerator()
termgenerator.set_stemmer(xapian.Stem('en'))
termgenerator.set_stopper(stopper)

# Count the number of files
file_count = 0
for dirpath, dirnames, filenames in os.walk(document_dir):
    file_count += len(filenames)
file_count = float(file_count)

# Index the files
count = 0
for dirpath, dirnames, filenames in os.walk(document_dir):
    for path in filenames:
        count += 1
        print '{0} of {1} ({2:.2%}):'.format(count, int(file_count),
                                            count/file_count),
        data = parse_wiki(dirpath, path)
        print data['path']

        if data['type'] <> 'content':
            continue
        del data['type']
        try:
            # Build the document
            doc = xapian.Document()
            termgenerator.set_document(doc)

            # Index each field with a prefix
            termgenerator.index_text(data['title'], 1, 'S')

            # Index the content
            termgenerator.index_text(data['title'])
            termgenerator.increase_termpos()
            termgenerator.index_text(data['content'])

            # Set the path of the document
            doc.set_data(data['path'])

            # Give the document an id
            idterm = u'Q' + data['path']
            doc.add_boolean_term(idterm)
            db.replace_document(idterm, doc)
        except:
            print data
            raise
db.commit()
