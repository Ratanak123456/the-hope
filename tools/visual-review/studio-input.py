#!/usr/bin/env python3
"""Send a click or key chord to the focused Studio X11 window for local review."""
import ctypes
import sys
x=ctypes.CDLL('libX11.so.6')
t=ctypes.CDLL('libXtst.so.6')
x.XOpenDisplay.restype=ctypes.c_void_p
x.XStringToKeysym.argtypes=[ctypes.c_char_p];x.XStringToKeysym.restype=ctypes.c_ulong
x.XKeysymToKeycode.argtypes=[ctypes.c_void_p,ctypes.c_ulong];x.XKeysymToKeycode.restype=ctypes.c_uint
x.XFlush.argtypes=[ctypes.c_void_p]
x.XSync.argtypes=[ctypes.c_void_p,ctypes.c_int]
t.XTestFakeMotionEvent.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_ulong]
t.XTestFakeButtonEvent.argtypes=[ctypes.c_void_p,ctypes.c_uint,ctypes.c_int,ctypes.c_ulong]
t.XTestFakeKeyEvent.argtypes=[ctypes.c_void_p,ctypes.c_uint,ctypes.c_int,ctypes.c_ulong]
d=x.XOpenDisplay(None)
if not d: raise SystemExit('X11 display unavailable')
if sys.argv[1]=='click':
 t.XTestFakeMotionEvent(d,-1,int(sys.argv[2]),int(sys.argv[3]),0)
 t.XTestFakeButtonEvent(d,1,1,0);t.XTestFakeButtonEvent(d,1,0,20)
else:
 keys=[x.XKeysymToKeycode(d,x.XStringToKeysym(k.encode())) for k in sys.argv[1:]]
 for k in keys:t.XTestFakeKeyEvent(d,k,1,0)
 for k in reversed(keys):t.XTestFakeKeyEvent(d,k,0,30)
x.XSync(d,0)
