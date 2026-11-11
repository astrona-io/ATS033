# Case study



Connect with `astrona ssh ats-033-lab-030-01-02`. The VM runs HTTP services on ports 8080 and 8081. Two network namespaces represent remote clients: `trusted` uses `192.0.2.2`, and `untrusted` uses `198.51.100.2`. Their host-facing interfaces are `lab-trusted` (`192.0.2.1`) and `lab-untrusted` (`198.51.100.1`). Both services initially accept both clients.

Allow about 10 minutes for the tasks. VM startup adds time.
