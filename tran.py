#!/usr/bin/env python
# -*- coding: utf-8 -*- 

import httplib, urllib, argparse, re
import json
# import pprint

SRC_LANG = 'auto'
TO_LANG  = 'uk'
HOST     = 'translate.google.com'

def argparser():
    parser = argparse.ArgumentParser(description='Instant Translator')
    parser.add_argument('phrase', metavar='p', type=str,
                        help='phrase to translate')
    args = parser.parse_args()
    return args.phrase

def retrieve(host, path):
    request = httplib.HTTPConnection(host)
    request.request("GET", path, "", {'User-Agent' : 'Mozilla/5.0'})
    response = request.getresponse()
    if response.status > 200:
        return u'[["{}"],"ERROR"]'.format(response.reason)
    return response.read()

def parse_item(item, depth = 0):
    if type(item) is list:
        result = u''
        for sub_item in item:
            result += parse_item(sub_item, depth + 1)
        return result
    elif type(item) is unicode:
        if len(item) == 0:
            return u''
        return u"{}{}\n".format(u"\t" * depth, item)
    else:
        return u''

def main():
    phrase = argparser()
    path = 'translate_a/t?client=t&sl=' + SRC_LANG + '&tl=' + TO_LANG + '&' + urllib.urlencode({'text' : phrase})
    response = re.sub(',{2,}', ',', retrieve(HOST, "/" + path))
    response = response.replace('[,', '[')
    response = response.replace(',]', ']')
    try:
        # translated = eval(response)
        translated = json.loads(response)
        # pp = pprint.PrettyPrinter(indent=2)
        # pp.pprint(translated)
        result = ''
        for item in translated:
            if type(item) is unicode:
                result = u"Translation: {} > {}\n\n{}".format(item, TO_LANG, result)
                # break
            result += parse_item(item, -1)
        print result.encode('utf8')
    except RuntimeError as ex:
        print u'Something went wrong ({}): {}'.format(response, ex)

if __name__ == '__main__':
    main()
