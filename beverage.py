#!/usr/bin/env python3

import parser
import sys
import re
import urllib.request as dl
import os.path 

def install(x):
    """
    Does simple passes to parse into something usable.
    (Though slow, it's a simple program).
    """
    x = '\n'.join(map(str, x))
    # Find match, remove newlines, and sub match the removed newlines
    args = re.compile(r"(?<=%W\[)([\s\S]+)(?=\])", re.MULTILINE)
    for m in re.finditer(args, x):
        m = re.sub(r'\s', ' ', ''.join(m.groups(0)))
        x = args.sub(m, x)
    # Correct multiline commands
    x = re.sub(r',\s+', r', ', x)
    # Second pass to remove commas
    x = re.sub(r'(, )', ' ', x)
    # Thrid pass to remove any words:
    l = [
        r'"',
        'system ',
        # ./configure args:
        r'--prefix=#{prefix}',
        '--enable-shared',
        '--enable-static',
        '--mandir=#{man}',
        # ENV
        'ENV.deparallelize'
        ]
    for w in l:
       x = x.replace(w, '')
    # change to pkg:*
    x = x.replace('./configure', 'pkg:configure')
    x = x.replace('make install', 'pkg:install ')
    if os.path.exists('make.sh'):
        return
    with open('make.sh', 'w') as fp:
        fp.write('pkg:setup\n')
        for line in x:
          fp.write(line)

def patch(x):
    for p in x:
        if not p['url'] and p['data']:
          with open('patch.diff', 'w') as fp:
            for l in p['data']:
              fp.write(l)
        else:
          dl.urlretrieve(p['url'], os.path.basename(p['url']))

def main(arg):
    data = parser.parse(arg)
    patch(data['patches'])
    data['install'] = install(data['install'])


if __name__ == '__main__':
    main(sys.argv[1])
