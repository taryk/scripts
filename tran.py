#!/usr/bin/env python

import httplib, urllib, argparse, re

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
        return '[["{}"],"ERROR"]'.format(response.reason)
    return response.read()

def parse_item(item, depth = 0):
    if type(item) is str:
        if len(item) == 0:
            return ''
        return "{}{}\n".format("\t" * depth, item)
    result = ''
    for sub_item in item:
        result += parse_item(sub_item, depth + 1)
    return result

phrase = argparser()
host = 'translate.google.com'
URL = 'translate_a/t?client=t&sl=auto&tl=uk&' + urllib.urlencode({'text' : phrase})

response = re.sub(',{2,}', ',', retrieve(host, "/" + URL))
try:
    translated = eval(response)
    result = ''
    for item in translated:
        if type(item) is str:
            result = "Translation: {} > uk\n\n{}".format(item, result)
            break
        result += parse_item(item, -1)
    print result
except RuntimeError as ex:
    print "Something went wrong ({}): {}".format(response, ex)
