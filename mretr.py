#!/usr/bin/env python

import os
import sys
import time
import pycurl
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

class MultiDownloader:

    eta = 0
    speed = 0
    total_bytes = 0
    timedelta_curr = 0
    timedelta_prev = 0

    def __init__(self, url, num_conn=5):
        self.url = url
        self.num_conn = num_conn
        self.filename =  os.path.basename(url)
        self.f = open(self.filename, 'w')
        self.m = pycurl.CurlMulti()
        self.m.handles = []
        self.timestamp_start = time.time()
        self.content_length = self.get_contentlength()
        print "Content length is: ", human_bytes(self.content_length)
        self.make_requests()

    def initial_req(self):
        c = pycurl.Curl()
        c.setopt(pycurl.NOBODY, 1)
        c.setopt(pycurl.URL, self.url)
        c.setopt(pycurl.FOLLOWLOCATION, 1)
        c.setopt(pycurl.MAXREDIRS, 5)
        c.setopt(pycurl.CONNECTTIMEOUT, 30)
        c.setopt(pycurl.TIMEOUT, 300)
        c.setopt(pycurl.NOSIGNAL, 1)
        c.perform()
        return c

    def get_contentlength(self):
        c = self.initial_req()
        return c.getinfo(pycurl.CONTENT_LENGTH_DOWNLOAD)
        
    def make_curlobj(self, index, ranges = [0,0], chunk_size = 0):
        print "going to create new curl object i:%d, range: [%d, %d], size: %d" % (index, ranges[0], ranges[1], chunk_size)
        c = pycurl.Curl()
        c.setopt(pycurl.URL, self.url)
        c.setopt(pycurl.FOLLOWLOCATION, 1)
        c.setopt(pycurl.MAXREDIRS, 5)
        c.setopt(pycurl.CONNECTTIMEOUT, 30)
        c.setopt(pycurl.NOSIGNAL, 1)
        c.setopt(pycurl.RANGE, "%d-%d" % (ranges[0], ranges[1]))
        c.setopt(pycurl.WRITEFUNCTION, lambda data: self.chunk(data, index))
        c.seek = ranges[0]
        c.size = chunk_size
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
            curlobj = self.make_curlobj(i, ranges, chunk_size)
            self.m.handles.append(curlobj)
            self.m.add_handle(curlobj)

    def progress_line(self):
        self.speed = int(self.total_bytes / (time.time()-self.timestamp_start))
        self.eta = int((self.content_length - self.total_bytes) / self.speed)
        output = "% 3d%% %s/s " % (self.total_bytes*100/self.content_length, human_bytes(self.speed))
        for i in range(self.num_conn):
            output += "[%02d: %6s] " % (i, human_bytes(self.m.handles[i].done))
        output += "Spent: %s. ETA: %s" % (timedelta(seconds=self.timedelta_curr), timedelta(seconds=self.eta))
        sys.stdout.write('\r\x1b[K'+output)
        sys.stdout.flush()

    def perform(self):
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
            if self.timedelta_curr > self.timedelta_prev:
                self.timedelta_prev = self.timedelta_curr
                self.progress_line()

        self.progress_line()
        sys.stdout.write('\n');
        return True

    def result(self):
        return "Total: %s (%d). Avg. speed: %s/s. Time: %s" % (human_bytes(self.total_bytes), self.total_bytes, human_bytes(self.total_bytes/self.timedelta_curr), timedelta(seconds=self.timedelta_curr))

    def cleanup(self):
        for c in self.m.handles:
            c.close()
        self.m.close()
        self.f.close()

if __name__ == '__main__':
    url = ""
    if len(sys.argv) >= 2:
        url = sys.argv[1]
    else:
        print "URL is required"
        sys.exit(1)
    mdownloader = MultiDownloader(url)
    if mdownloader.perform():
        print mdownloader.result()
    else:
        print "Download failed"
    mdownloader.cleanup()
