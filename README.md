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
- Install: `make install`
- Setup: `wrtbwmon.sh setup`
- Update table: `wrtbwmon.sh update /tmp/usage.db` (you can place the data table anywhere)
- Create html page: `wrtbwmon.sh publish /tmp/usage.db /tmp/usage.htm`

### Regular updates
- Install the necessary files:
  - `./install.sh wrtbwmon.sh readDB.awk usage.htm1 usage.htm2 wrtbwmon`
  - Or, if you have `make`, just `make install`
  - In the future, there may be an IPK.
- Add the following to root's crontab:

        # adapt to your needs
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
	
        * * * * * <script location> update /tmp/usage.db
        0 * * * * <script location> publish /tmp/usage.db /tmp/usage.htm

- Enable web serving of the generated page (optional)
  - This varies by environment, but for lighttpd:
    - ln -s /tmp/usage.htm /var/www/html/

### Remove `iptables` rules
 - `wrtbwmon.sh remove`
