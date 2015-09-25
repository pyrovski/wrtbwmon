# wrtbwmon
Modified from https://code.google.com/p/wrtbwmon/.

## New features
 - "First seen" and "Total" columns in usage table
 - Monitoring of locally generated traffic on a per-interface basis
 - `remove` function to delete `iptables` rules

### What does it do?
`wrtbwmon` was designed to track bandwidth consumption on home routers. 
It accomplishes this with `iptables` rules, which means you don't need to run an extra process just to track bandwidth. 
`wrtbwmon` conveniently tracks bandwidth consumption on a per-IP address basis, 
so you can easily determine which user/device is the culprit.

### How do I use it?
- Setup: `./wrtbwmon setup /tmp/usage/db` (you can place the data table anywhere)
- Update table: `./wrtbwmon update /tmp/usage.db`
- Create html page: `./wrtbwmon publish /tmp/usage.db /tmp/usage.htm`

### Regular updates
 - Install the wrtbwmon.sh script somewhere, making sure to update `baseDir` and `dataDir` to point to `readDB.awk` and `usage.htm*`, respectively.
 - Add the following to root's crontab, assuming `<script location>` is replaced with the actual location:

        * * * * * <script location> update /tmp/usage.db
        0 * * * * <script location> publish /tmp/usage.db /tmp/usage.htm

### Remove `iptables` rules
 - `./wrtbwmon remove`
