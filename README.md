# Welcome ;) !

Debian might create a package, waiting for news !
https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=859741

Install your Mastodon instance without touching anything !
This script has been created by PastaGringo with indirect help of Angristan
This script works on Debian 8 (Jessie) and is still in development

There are few things that you need to know before continuing if you want your own fonctionnal Mastodon instance :
- You need to have a valid domain name with an A DNS record with the local server IP address
- You need to have an account with a SMTP tiers like Mailgun/SparkPost or you own SMTP relay
- Few dozen of minutes regarding of your server performances

If all above things are in your possession, we can continue and install your first Mastodon instance !
 
# How-To

`wget https://raw.githubusercontent.com/PastaGringo/Mastodon.sh/master/mastodon.sh && bash mastodon.sh`

Don't hesitate to contact me on Mastodon if you need anything! https://mastodon.partipirate.org/@PastaGringo

# To-Do

- Non-verbose mode
- Setup admin account 
- Mailgun settings integration
- cron jobs
- ...
