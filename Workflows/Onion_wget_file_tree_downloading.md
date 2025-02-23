### **📜 Downloading Extensive File Trees from .Onion Sites Using `wget`**  

---

## **1️⃣ Requirements & Behavior**  
✅ **Stable download over Tor** with retries and timeouts.  
✅ **Complete file tree capture** with full recursion and preserved structure.  
✅ **Original timestamps maintained** to match server files.  
✅ **Resumes interrupted downloads** to prevent duplicates.  
✅ **Minimal, meaningful logging**—only file requests and errors, no noise.  
✅ **Decodes URL-encoded filenames, including UTF-8 characters (e.g., Czech diacritics).**  

---

## **2️⃣ Optimized `wget` Command**
```bash
torsocks wget -r -np -nH --cut-dirs=1 -R "index.html*" -e robots=off --retry-connrefused --timeout=30 --tries=10 -c -N --progress=dot:mega -l inf "http://site.onion/data1/" \
2>&1 | grep -Ev "Reusing existing connection|HTTP request sent|Saving to:|tmp since it should be rejected|\.{6}|^[[:space:]]*0K|^Length:|Last-modified header missing -- time-stamps turned off|’ saved \[" \
| sed '/^$/d' \
| python3 -u -c "import sys, urllib.parse; [print(urllib.parse.unquote(line.strip()), flush=True) for line in sys.stdin]" > data1_log.txt
```

---

## **3️⃣ Key Parameters**
| **Option**         | **Purpose** |
|--------------------|------------|
| `torsocks`        | Routes traffic through **Tor**. |
| `-r -np -nH`      | Enables **full recursion** while preventing unnecessary folders. |
| `--cut-dirs=1`    | Keeps directory structure clean. |
| `-R "index.html*"`| Excludes **auto-generated index files**, which are temporarily downloaded as `index.html.tmp`. |
| `-e robots=off`   | Ignores `robots.txt` restrictions. |
| `--retry-connrefused --timeout=30 --tries=10` | Ensures **stable downloads** over Tor. |
| `-c -N`           | **Resumes downloads** and **preserves timestamps**. |
| `--progress=dot:mega` | Keeps **progress output minimal**. |
| `-l inf`          | Enables **unlimited recursion depth**. |

---

## **4️⃣ Logging Optimization & URL Decoding**
📌 **Why?** To keep logs compact, only including necessary details while ensuring URLs are readable.  
📌 **How?** Filtering removes connection reuse logs, temp files, progress updates, metadata, and empty lines.

```bash
2>&1 | grep -Ev "Reusing existing connection|HTTP request sent|Saving to:|tmp since it should be rejected|\.{6}|^[[:space:]]*0K|^Length:|Last-modified header missing -- time-stamps turned off|’ saved \[" \
| sed '/^$/d' \
| python3 -u -c "import sys, urllib.parse; [print(urllib.parse.unquote(line.strip()), flush=True) for line in sys.stdin]" > data1_log.txt
```

✅ **Keeps:**  
- File/folder requests (`--2025-...`).  
- **All errors** for troubleshooting.  

✅ **Removes:**  
- Connection reuse logs.  
- HTTP requests & responses.  
- Temporary file deletions (`index.html.tmp`).  
- Missing timestamps for excluded `index.html` files.  
- Progress updates (`0K ...`).  
- Metadata (`Length: ...`).  
- Saved files (Requests already contain info about requested files/folders. Errors would inform about any downloading issues.)
- Empty lines.  

✅ **Decodes URL-encoded filenames** (`%XX` → readable format, including UTF-8 characters).  

---

## **5️⃣ Why We Chose Python for URL Decoding**
We originally attempted **`xargs` and `awk`** for decoding but encountered issues:  
❌ **`xargs printf '%b'` buffered too much**, delaying log updates.  
❌ **`awk` processed only single-byte sequences**, causing issues with UTF-8 characters (e.g., Czech diacritics).  

✅ **Python (`urllib.parse.unquote()`) correctly handles UTF-8** while processing **continuously** in real time.  
✅ **Executed only once** (unlike `xargs` which would spawn a process per line).  
✅ **Ensures logs update efficiently, with correct filenames**.  

---

## **📌 Summary**
🚀 **Stable, efficient, and recursive `.onion` file tree downloads**.  
📂 **Preserves timestamps, resumes downloads**.  
📊 **Minimal logging with only file requests and errors**.  
🔡 **Correctly decodes URL-encoded filenames, including UTF-8 characters**.  

## **TODO**

1. File tree contains also information about folders timestamps. This information is part of html page and is not downloaded by wget. I have a script for that, consolidate with this.
2. Or maybe better do not exclude automatically generated index.html?
