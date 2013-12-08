# OVH-PCA-PERL

Pour que ce script soit fonctionnel il faut :

1° Enregistrer votre application sur http://www.ovh.com/cgi-bin/api/createApplication.cgi

2° Mettre dans le script dans $ak votre clé d'application (publique)

3° Mettre dans le script dans $as votre clé (secrète) d'application

4° Demander un Token d'authentification à OVH en procédant ainsi (XXXXXXXXXXXXXXXX est votré clé publique d'application) :

a)
```
curl -XPOST -H"X-Ovh-Application: XXXXXXXXXXXXXXXX" -H "Content-type: application/json" \
https://eu.api.ovh.com/1.0/auth/credential  -d '{
    "accessRules": [
        {
            "method": "GET",
            "path": "/*"
        },
        {
            "method": "POST",
            "path": "/*"
        },
        {
            "method": "PUT",
            "path": "/*"
        },
        {
            "method": "DELETE",
            "path": "/*"
        }
    ],
    "redirection":"https://api.ovh.com/"
}'
```

b) Vous revevez une réponse ressemblant à 
```
{"validationUrl":"https://api.ovh.com/auth/?credentialToken=yyyyyyyyyyyyyyyyyyyyyyyyyyyyyy","consumerKey":"CONSUMERKEY","state":"pendingValidation"}
```

Prenez note de la consumerKey

c)

Rendez vous à l'URL https://api.ovh.com/auth/?credentialToken=yyyyyyyyyyyyyyyyyyyyyyyyyyyyyy pour valider la demande et indiquez le temps de validité souhaité (illimité).

Il y a un autre exemple sur http://www.ovh.com/fr/g934.premiers-pas-avec-l-api (attention dans cet autre exemple le token n'a que les droits GET)

5° Mettre ce token/consumerKey dans le script dans la variable $ck


Si vous utilisez Debian, il vous faudra les packages suivants :

libjson-perl
libjson-xs-perl
libdigest-sha1-perl
libwww-perl
libcrypt-ssleay-perl

Le package libdigest-sha1-perl n'existe étrangement plus ni sous Debian 7 Wheezy, ni sous Ubuntu 12.04 LTS.

Dans le répertoire package-ubuntu, vous trouverez une version adaptée à Ubuntu 12.04

Dans le répertoire packages-debian7-wheezy, vous trouverez une version adaptée à Debian 7

Un fois le package téléchargé sur votre système, installez le à l'aide de la commande dpkg -i libdigest-sha1-perl_2.13-1_amd64.deb

Même si le script gère la différence d'heure entre votre machine et les serveurs d'OVH, je vous recommande quand même d'ajouter en cron une synchroniosation d'heure avec OVH.

Par exemple ainsi :

20 01 * * * ntpdate -s ntp.ovh.net

(synchronisation silencieuse avec les serveurs d'OVH à 01h20)

## Utilisation

```
  usage: perl ovh-pca-api-manage.pl [-d] max_session_age_in_seconds | [-d] session ID | [-f] session ID | [-b] Session ID | [-r] new_name | [-r] "Session ID new_name" | [-l] | [-t] | [-s] | [-h]

   -h : this (help) message
   -d : delete PCA sessions older than X (exprimed in seconds) or PCA session ID
   -f : List files from PCA session ID
   -r : Rename last PCA session into Y
   -r : Rename PCA session ID into Z
   -l : List PCA sessions
   -t : List tasks with their status
   -s : Total size of all sessions 
   -b : Restore session X
```

```
  example:  perl ovh-pca-api-manage.pl -d 86400 (=delete sessions older than a day)
            perl ovh-pca-api-manage.pl -d 51d542f302ee4c5466000000 (=Delete session with ID 51d542f302ee4c5466000000)
            perl ovh-pca-api-manage.pl -b 51d542f302ee4c5466000000 (=Restore session with ID 51d542f302ee4c5466000000)
            perl ovh-pca-api-manage.pl -f 51cbb78fb75806f22f000000 (list files contained in session 51cbb78fb75806f22f000000)
            perl ovh-pca-api-manage.pl -r "new session name" (=rename last session into "new session name")
  	    perl ovh-pca-api-manage.pl -r "51cbb78fb75806f22f000000 new session name" (=rename session 51cbb78fb75806f22f000000 into "new session name")
            perl ovh-pca-api-manage.pl -l (=List active sessions)
            perl ovh-pca-api-manage.pl -t (=List tasks and get their status)
            perl ovh-pca-api-manage.pl -s (=List total sessions size)
```
            
