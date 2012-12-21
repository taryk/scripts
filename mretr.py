#!/usr/bin/env python

import os
import re
import sys
import time
import pycurl
import hashlib
import argparse
from datetime import datetime, timedelta
from dateutil.relativedelta import relativedelta

try:
    import signal
    from signal import SIGPIPE, SIG_IGN
    signal.signal(signal.SIGPIPE, signal.SIG_IGN)
except ImportError:
    pass

def human_bytes(num):
    for x in ['bytes','KB','MB','GB']:
        if num < 1024.0:
            return "%3.1f%s" % (num, x)
        num /= 1024.0
    return "%3.1f%s" % (num, 'TB')

def prompt_overwrite(filename):
    yn = raw_input('File "%s" already exists. Overwrite it? [y/N]: ' % filename)
    while True:
        if yn == 'y' or yn == 'yes':
            return True
        elif (yn == 'n' or yn == 'no') or len(yn) == 0:
            return False
        else: 
            yn = raw_input('Please enter y/yes or n/no: ')

DEBUG=0

class MultiDownloader:

    eta = 0
    speed = 0
    total_bytes = 0
    timedelta_curr = 0
    timedelta_prev = 0

    def __init__(self, url, output=None, num_conn=5, overwrite=False):
        self.url = url
        self.num_conn = num_conn
        if output is None:
            self.filename = os.path.basename(self.url)
        else:
            self.filename = output
        if not overwrite and os.path.exists(self.filename) and not prompt_overwrite(self.filename):
            while os.path.exists(self.filename):
                self.filename, n = re.subn(r'\.(\d+)$', lambda x: '.%d' % (int(x.group(1))+1), self.filename)
                if n <= 0:
                    self.filename+='.0'
                      
        self.f = open(self.filename, 'w')
        self.m = pycurl.CurlMulti()
        self.m.handles = []
        self.timestamp_start = time.time()
        self.content_length = self.get_contentlength()
        if DEBUG:
            print "DEBUG: Content length is: ", human_bytes(self.content_length)
        self.make_requests()          
    
    def initial_req(self):
        c = pycurl.Curl()
        c.setopt(pycurl.NOBODY, 1)
        c.setopt(pycurl.URL, self.url)
        c.setopt(pycurl.FOLLOWLOCATION, 1)
        c.setopt(pycurl.MAXREDIRS, 5)
        c.setopt(pycurl.CONNECTTIMEOUT, 30)
        c.setopt(pycurl.USERAGENT, 'mretr, ping')
        c.setopt(pycurl.TIMEOUT, 300)
        c.setopt(pycurl.NOSIGNAL, 1)
        c.perform()
        return c

    def get_contentlength(self):
        c = self.initial_req()
        return c.getinfo(pycurl.CONTENT_LENGTH_DOWNLOAD)
        
    def make_curlobj(self, index, ranges = [0,0], chunk_size = None):
        if DEBUG:
            print "DEBUG: going to create new curl object i:%2d, range: [%10d, %10d], size: %s" % (index, ranges[0], ranges[1], chunk_size)
        c = pycurl.Curl()
        c.setopt(pycurl.URL, self.url)
        c.setopt(pycurl.FOLLOWLOCATION, 1)
        c.setopt(pycurl.MAXREDIRS, 5)
        c.setopt(pycurl.CONNECTTIMEOUT, 30)
        c.setopt(pycurl.NOSIGNAL, 1)
        c.setopt(pycurl.USERAGENT, 'mretr, %d' % index)
        if ranges[1] > 0:
            c.setopt(pycurl.RANGE, "%d-%d" % (ranges[0], ranges[1]))
        c.setopt(pycurl.WRITEFUNCTION, lambda data: self.chunk(data, index))
        c.seek = ranges[0]
        c.size = chunk_size if chunk_size else self.content_length
        c.done = 0
        c.time = time.time()
        return c

    def chunk(self, data, id):
        length = len(data)
        self.f.seek(self.m.handles[id].seek)
        self.f.write(data)
        self.m.handles[id].seek+=length
        self.m.handles[id].done+=length
        self.total_bytes+=length
        return length

    def make_requests(self):

        def add_handle(curlobj):
            self.m.handles.append(curlobj)
            self.m.add_handle(curlobj)

        if self.num_conn > 1:
            chunk_s = int(self.content_length / self.num_conn)
            last_s = self.content_length % self.num_conn
            for i in range(self.num_conn):
                ranges = [ chunk_s*i, 0 ]
                chunk_size = chunk_s
                if i==self.num_conn-1:
                    ranges[1] = self.content_length
                    chunk_size+=last_s
                else:
                    ranges[1] = chunk_s*(i+1)
                add_handle(self.make_curlobj(i, ranges, chunk_size))
        else:
            add_handle(self.make_curlobj(0))
            
                

    def progress_line(self):
        self.speed = int(self.total_bytes / (time.time()-self.timestamp_start))
        self.eta = int((self.content_length - self.total_bytes) / self.speed)
        output = "%3d%% %s/s " % (self.total_bytes*100/self.content_length, human_bytes(self.speed))
        for i in range(self.num_conn):
            output += "[%02d: %6s] " % (i, human_bytes(self.m.handles[i].done))
        output += "Spent: %s. ETA: %s" % (timedelta(seconds=self.timedelta_curr), timedelta(seconds=self.eta))
        sys.stdout.write('\r\x1b[K'+output)
        sys.stdout.flush()

    def perform(self, progress=False):
        num_processed = 0
        while num_processed < self.num_conn:
            # Run the internal curl state machine for the multi stack
            while 1:
                ret, num_handles = self.m.perform()
                if ret != pycurl.E_CALL_MULTI_PERFORM:
                    break
            # Check for curl objects which have terminated, and add them to the freelist
            while 1:
                num_q, ok_list, err_list = self.m.info_read()
                for c in ok_list:
                    self.m.remove_handle(c)
                for c, errno, errmsg in err_list:
                    self.m.remove_handle(c)
                    return False
                    # print "Failed: ", filename, url, errno, errmsg
                num_processed = num_processed + len(ok_list) + len(err_list)
                if num_q == 0:
                    break
            # Currently no more I/O is pending, could do something in the meantime
            # (display a progress bar, etc.).
            # We just call select() to sleep until some more data is available.
            self.m.select(1.0)
            self.timedelta_curr = int(time.time() - self.timestamp_start)
            if progress:
                if self.timedelta_curr > self.timedelta_prev:
                    self.timedelta_prev = self.timedelta_curr
                    self.progress_line()

        if progress: 
            self.progress_line()
            sys.stdout.write('\n');

        return True

    def result(self):
        return "Total: %s (%d). Avg. speed: %s/s. Time: %s" % (human_bytes(self.total_bytes), self.total_bytes, human_bytes(self.total_bytes/self.timedelta_curr), timedelta(seconds=self.timedelta_curr))


    def checksum(self, csum_type):
        hash_fn = hashlib.new(csum_type)
        with open(self.filename,'rb') as f: 
            for chunk in iter(lambda: f.read(8192), b''):
                hash_fn.update(chunk)
        return hash_fn.hexdigest()
    
    def cleanup(self):
        for c in self.m.handles:
            c.close()
        self.m.close()
        self.f.close()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(prog='mretr', description='Multistream downloader')
    parser.add_argument('url', metavar='URL', type=str, nargs=1, help='URL for download')
    parser.add_argument('-o', '--output', metavar='FILE', action='store', help='Write data to FILE')
    parser.add_argument('-n', type=int, default=5, help='Number of parallel streams')
    parser.add_argument('-p', '--progress', action='store_true', help='Display progress information')
    parser.add_argument('-d', '--debug', action='store_true', help='Display debugging messages')
    parser.add_argument('--overwrite', action='store_true', help='Overwrite existing file')
    parser.add_argument('-c', '--checksum', nargs='+', choices=hashlib.algorithms, help='Calculate the checksum on the file after downloading')
    parser.add_argument('-v', '--version', action='version', version='%(prog)s 0.1')
    
    args = parser.parse_args()
    DEBUG=args.debug
    mdownloader = MultiDownloader(args.url[0], args.output, args.n, args.overwrite)

    if mdownloader.perform(args.progress):
        print mdownloader.result()          
    else:
        print "Download failed"

    mdownloader.cleanup()

    if args.checksum:
        print "== '%s' checksum ====" % mdownloader.filename
        for checksum in args.checksum:
            print "%s\t%s" % (checksum, mdownloader.checksum(checksum))
