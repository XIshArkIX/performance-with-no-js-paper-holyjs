## Chrome: TLS False Start is enabled by default

Chrome (Chromium) uses TLS False Start by default.  
The Chromium team documents a command-line flag named `--disable-ssl-false-start`, which exists to turn this behavior off.  
If a feature has a "disable" flag, that indicates it is normally enabled unless explicitly disabled.

Additional historical confirmation comes from the Chromium blog post about SSL False Start rollout and performance results.

Sources:
- [Chromium issue tracker reference (`--disable-ssl-false-start`)](https://issues.chromium.org/issues/41008149#:~:text=%2D%2Ddisable%2Dssl%2Dfalse%2Dstart)
- [Chromium Blog: SSL FalseStart Performance Results (May 2011)](https://blog.chromium.org/2011/05/ssl-falsestart-performance-results.html)
