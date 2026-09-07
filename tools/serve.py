
from pathlib import Path
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from functools import partial
import argparse
parser=argparse.ArgumentParser(description='Mare local game server')
parser.add_argument('--port',type=int,default=8787)
parser.add_argument('--lan',action='store_true',help='Allow a TV on the same local network')
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]/'dist'
handler=partial(SimpleHTTPRequestHandler,directory=str(root))
server=ThreadingHTTPServer(('0.0.0.0' if args.lan else '127.0.0.1',args.port),handler)
print(f'Mare: http://localhost:{args.port}  |  Setas, Enter, Escape',flush=True)
try:server.serve_forever()
except KeyboardInterrupt:server.server_close()
