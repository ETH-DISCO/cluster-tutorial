# Troubleshooting

Fix: Error messages because of misconfigured locale.
	
```bash
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LC_CTYPE=UTF-8
export LANG=C.UTF-8
```

---

Fix: Pip dependencies take too long to resolve.

```bash
pip install <dependency> --upgrade --no-cache-dir --user --verbose
```
