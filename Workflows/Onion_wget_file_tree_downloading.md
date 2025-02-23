### **📜 Downloading Extensive File Trees from .Onion Sites Using `wget`**  

---

## **1️⃣ Requirements & Behavior**
✅ **Stable download over Tor** with retries and timeouts.  
✅ **Complete file tree capture** with full recursion and preserved structure.  
✅ **Original timestamps maintained** to match server files.  
✅ **Resumes interrupted downloads** to prevent duplicates.  
✅ **Minimal, meaningful logging**—only saved files and errors, no noise.  

---

## **2️⃣ Optimized `wget` Command**
```bash
torsocks wget -r -np -nH --cut-dirs=1 -R "index.html*" -e robots=off --retry-connrefused --timeout=30 --tries=10 -c -N --progress=dot:mega -l inf "http://site.onion/data1/" \
2>&1 | grep -Ev "Reusing existing connection|HTTP request sent|Saving to:|tmp since it should be rejected|\.{6}|^[[:space:]]*0K|^Length:|Last-modified header missing -- time-stamps turned off" | sed '/^$/d' > data1_log.txt
```

---

## **3️⃣ Key Parameters**
| **Option**         | **Purpose** |
|--------------------|------------|
| `torsocks`        | Routes traffic through **Tor**. |
| `-r -np -nH`      | Enables **full recursion** while preventing unnecessary folders. |
| `--cut-dirs=1`    | Keeps directory structure clean. |
| `-R "index.html*"`| Excludes **auto-generated index files**, which are than only temporarily downloaded as index.html.tmp. |
| `-e robots=off`   | Ignores `robots.txt` restrictions. |
| `--retry-connrefused --timeout=30 --tries=10` | Ensures **stable downloads** over Tor. |
| `-c -N`           | **Resumes downloads** and **preserves timestamps**. |
| `--progress=dot:mega` | Keeps **progress output minimal**. |
| `-l inf`          | Enables **unlimited recursion depth**. |

---

## **4️⃣ Logging Optimization**
📌 **Why?** To keep logs compact and only include necessary details.  
📌 **How?** Filtering removes connection reuse logs, temp files, progress updates, metadata, and empty lines.

```bash
2>&1 | grep -Ev "Reusing existing connection|HTTP request sent|Saving to:|tmp since it should be rejected|\.{6}|^[[:space:]]*0K|^Length:|Last-modified header missing -- time-stamps turned off" | sed '/^$/d' > wget_cleaned_log.txt
```

✅ **Keeps:**  
- Successfully **saved files**.  
- **All errors** for troubleshooting.  

✅ **Removes:**  
- Connection reuse logs.  
- HTTP requests & responses.  
- Temporary file deletions (typically for automatically created index.html.tmp).
- Missing timestamps for automatically created index.html (which is excluded anyway).
- Progress updates (`0K ...`).  
- Metadata (`Length: ...`).  
- Empty lines.  

---

## **📌 Summary**
🚀 **Stable, efficient, and recursive `.onion` file tree downloads**.  
📂 **Preserves timestamps, resumes downloads**.  
📊 **Minimal logging with only saved files and errors**.