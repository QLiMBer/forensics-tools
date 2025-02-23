# **📝 Downloading Onion Directory Listings (Without Files) for future parsing**

---

## **📌 Objective**

- **Download directory structure from `.onion` site**, and store it localy.
- **Skip actual files** to speed up the process.
- **The goal is to get timestamps of directories** it often equals the time of exfiltration in data breach incidents.
- **Parse timestamps** from local directory listing copy later.
- **Ensure download logs are saved separately**, and not just outputed to terminal.

---

## **⚙️ Prerequisites**

> **Note:** This workflow was tested on PC running Windows OS with WSL, but it should work on any Linux distribution with used tools installed.

1. **Windows 11 with WSL (Ubuntu) installed.**
2. **Tor installed inside WSL:**

   ```bash
   sudo apt update && sudo apt install tor -y
   ```

3. **Configure Tor (`/etc/tor/torrc`)** to ensure it's listening on localhost:

   ```plaintext
   SocksPort 9050
   SocksListenAddress 127.0.0.1
   // I added only the SocksPort, but based on comments in torrc, it is possible none of these lines are needed:
   // ## Tor opens a socks proxy on port 9050 by default -- even if you don't
   // ## configure one below. Set "SocksPort 0" if you plan to run Tor only
   // ## as a relay, and not make any local application connections yourself.
   ```

4. **Start the Tor service:**

   ```bash
   sudo service tor start
   ```

5. **Install `torsocks` to route commands through Tor:**

   ```bash
   sudo apt install torsocks -y
   ```

---

## **🛠 Steps**

### **1️⃣ Start the Download (Directory Listings Only)**

Use `wget` through `torsocks` to recursively download only **HTML directory listings**, skipping files:

```bash
torsocks wget -r -np -l inf -A "index.html" -P ./Onion_tree/ \
    http://example.onion/full/ \
    -o wget.log 2> wget_errors.log
```

✅ **Explanation:**

- **`-r -np -l inf`** → Recursively download without going up directories.
- **`-A "index.html"`** → Download only HTML listings (skip files).
- **`-P ./Onion_tree/`** → Store the local file structure in `Onion_tree/`.
- **Logs:**  
  - `wget.log` → Successful downloads.  
  - `wget_errors.log` → Errors only.

---

### **2️⃣ Monitor Progress**

Might be checked live without stopping `wget`, e.g.

```bash
tail -f wget.log
```

Or something like:

```bash
watch -n 5 "wc -l wget.log wget_errors.log"
```

In both cases, be aware the number of lines do not match the number of directories.
Each directory (its index.html representation) download has multiple lines in the log file.

---

### **3️⃣ Resuming an Interrupted Download**

If `wget` stops unexpectedly (e.g., network issues, manual cancel), **resume it** with:

```bash
torsocks wget -r -np -l inf -A "index.html" -P ./Onion_tree/ -c \
    http://example.onion/full/ \
    -o wget_resume.log 2> wget_resume_errors.log
```

✅ **What `-c` (continue) does:**

- **Already downloaded directories remain intact.**
- **Partially downloaded files resume where they left off.**
- **Missing directories will be fetched.**
- **Errors will be reattempted automatically.**

---

### **4️⃣ Extract Directory Timestamps**

Once the download is complete, **parse the stored `index.html` files** to extract timestamps.
For structured parsing, use **Python with BeautifulSoup**.

---

### **5️⃣ Additional Notes**

- Metadata such as timestamps and sizes in the HTML listing may not be accurate; they are simply part of the HTML page.
- However, this is the only method to obtain timestamps for directories, which can be crucial for identifying data exfiltration times.
- For file metadata, HTTP headers can be used, typically containing `Last-Modified`, `Content-Length`, and `Content-Type` if provided by the server.
- Example command to fetch HTTP headers:

 ```bash
 curl -I --socks5-hostname 127.0.0.1:9050 http://example.onion/file.pdf
 ```

---

## **✅ Summary**

1. **Install & configure Tor in WSL (`torrc` settings, start service).**
2. **Use `torsocks wget` to download only directory listings.**
3. **Storing separate (not just terminal output) might be helpful in case of huge directory listings**
4. **Resume if needed (`wget -c` ensures no duplicates).**
5. **Extract directory timestamps later by parsing stored `index.html` files.**
