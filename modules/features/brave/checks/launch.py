"""Basic renderer launch validation for the assembled personal Brave feature."""
import os
from pathlib import Path
import sys
from browser import Browser

browser = Browser(sys.argv[1], dict(os.environ),
                  Path(os.path.expandvars(sys.argv[2])),
                  extra_args=["--disable-extensions"])
try:
    browser.navigate("data:text/html,<title>mybrave launch check</title>",
                     "document.title === 'mybrave launch check'")
    print("mybrave launched and rendered a page in an isolated profile.")
finally:
    browser.close()
