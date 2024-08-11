The following are patches for common isses experienced when using the cluster.

---

Fix: Ran out of memory.

```bash
df -Th
df -h /itet-stor/<username>/net_scratch/

rm -rf ./itet-stor/<username>/net_scratch/*
```

---

Fix: Error messages because of misconfigured locale.
	
```bash
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LC_CTYPE=UTF-8
export LANG=C.UTF-8
```

---

Fix: Can't install pip dependencies.

```bash
pip install <dependency> --upgrade --no-cache-dir --user --verbose

echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```
