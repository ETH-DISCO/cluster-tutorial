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
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

pip install <dependency> --upgrade --no-cache-dir --user --verbose
```
