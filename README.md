# reMarkable Version Checker

A tiny bash script to report the active and fallback reMarkable OS versions.

## Installation & Usage
All commands should be run on the tablet.

### Fetch & run in one step 
> [!CAUTION]
> Piping code from the internet directly into `bash` can be dangerous. Make sure you trust the source and know what it will do to your system.

   ```bash
   wget -qO- https://raw.githubusercontent.com/rmitchellscott/rm-version-checker/main/rm-version-checker.sh | bash
   ```
### Individual Steps
1. **Download the script**  
   Fetch the raw script from GitHub:

   ```bash
   wget -O rm-version-checker.sh \
     https://raw.githubusercontent.com/rmitchellscott/rm-version-checker/main/rm-version-checker.sh
   ```

2. **Make it executable**

   ```bash
   chmod +x rm-version-checker.sh
   ```

3. **Run it**  

   ```bash
   ./rm-version-checker.sh
   ```


## What it does

- Detects which partition (`p2` or `p3`) is currently running.  
- Determines the alternate (“fallback”) partition.  
- Reads and prints the version numbers for each partition.

Example output:

```text
→ Active:    p2
→ Fallback:  p3
→ Next boot: p2

Version (Active):     3.20.0.92
Version (Fallback):   3.18.2.3
Version (Next boot):  3.20.0.92
```

## Swithing Boot Partitions
To switch boot partitions, check out this project: https://github.com/ddvk/remarkable-update/blob/main/switch.sh
