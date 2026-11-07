#!/usr/bin/env python3
"""Prints the exception and each thread's frames of one macOS CrashReporter `.ips` report."""

import json
import sys

with open(sys.argv[1], encoding="utf-8") as file:
    file.readline()
    report = json.load(file)

print(report.get("exception", {}))
images = report["usedImages"]
for idx, thread in enumerate(report["threads"]):
    crashed = " crashed" if thread.get("triggered") else ""
    print(f"thread {idx} {thread.get('name', '')}{crashed}")
    for frame in thread["frames"]:
        image = images[frame["imageIndex"]].get("name", "?")
        symbol = frame.get("symbol", hex(frame["imageOffset"]))
        print(f"  {image} {symbol}")
