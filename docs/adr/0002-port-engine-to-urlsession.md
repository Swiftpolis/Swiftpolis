# Port Persepolis's engine to URLSession, without aria2

Persepolis replaced aria2 with its own engine in commit `93e4551`, so we port that engine's Parts, Control file and resume rules onto `URLSession`. Each Connection gets its own session, because a shared session can multiplex every request onto one HTTP/2 connection, which would change what "64 Connections" means. Keeping the Control file format also lets partial Persepolis downloads resume after import.
