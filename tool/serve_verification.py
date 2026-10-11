"""Local preview of build/web; optional precompressed responses for measurement."""
import argparse
import gzip
import http.server
import mimetypes
import pathlib
import urllib.parse
import threading
import time

parser = argparse.ArgumentParser()
parser.add_argument('--port',type=int,default=8767)
parser.add_argument('--root',default='build/web')
parser.add_argument('--gzip',action='store_true')
parser.add_argument('--qa', action='store_true')
parser.add_argument('--cache', action='store_true')
parser.add_argument('--rate-mbps', type=float, default=0)
parser.add_argument('--latency-ms', type=float, default=0)
args=parser.parse_args()
root=pathlib.Path(args.root).resolve()
qa_script=(pathlib.Path(__file__).parent/'phase09_metrics.js').read_bytes() if args.qa else b''
def source(file):
    raw=file.read_bytes()
    if args.qa and file.name=='index.html':
        raw=raw.replace(b'<body>',b'<body><script src="/__qa/metrics.js"></script>')
    return raw
cache={}
if args.gzip:
    for file in root.rglob('*'):
        if file.is_file() and file.suffix in ['.html','.js','.json','.ttf','.otf','.wasm']:
            raw=source(file)
            compressed=gzip.compress(raw,compresslevel=6,mtime=0)
            if len(compressed)<len(raw): cache[file]=compressed
rate_lock=threading.Lock()
next_slot=time.monotonic()
def send_limited(stream, data):
    global next_slot
    for offset in range(0,len(data),16384):
        chunk=data[offset:offset+16384]
        if args.rate_mbps:
            with rate_lock:
                next_slot=max(next_slot,time.monotonic())+len(chunk)/(args.rate_mbps*1000000/8)
                delay=next_slot-time.monotonic()
            if delay>0: time.sleep(delay)
        stream.write(chunk)
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self,*args): pass
    def do_GET(self):
        if args.qa and urllib.parse.urlsplit(self.path).path=='/__qa/metrics.js':
            self.send_response(200)
            self.send_header('Content-Type','text/javascript')
            self.send_header('Content-Length',str(len(qa_script)))
            self.send_header('Cache-Control','no-store')
            self.end_headers()
            self.wfile.write(qa_script)
            return
        path=(root / urllib.parse.unquote(urllib.parse.urlsplit(self.path).path).lstrip('/')).resolve()
        if not path.is_relative_to(root): self.send_error(403);return
        if path.is_dir(): path=path/'index.html'
        if not path.is_file(): self.send_error(404);return
        encoded=args.gzip and 'gzip' in self.headers.get('Accept-Encoding','') and path in cache
        data=cache[path] if encoded else source(path)
        if args.latency_ms: time.sleep(args.latency_ms/1000)
        self.send_response(200)
        self.send_header('Content-Type',mimetypes.guess_type(path)[0] or 'application/octet-stream')
        self.send_header('Content-Length',str(len(data)))
        self.send_header('Cache-Control','public,max-age=3600' if args.cache and path.name!='index.html' else 'no-store')
        self.send_header('Vary','Accept-Encoding')
        if encoded: self.send_header('Content-Encoding','gzip')
        self.end_headers()
        try:send_limited(self.wfile,data)
        except (BrokenPipeError,ConnectionResetError):pass
print(f'YOGEN verification http://127.0.0.1:{args.port} compressed={args.gzip}',flush=True)
http.server.ThreadingHTTPServer(('127.0.0.1',args.port),Handler).serve_forever()
