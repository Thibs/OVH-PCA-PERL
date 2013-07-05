# OVH-PCA-PERL

Pour que ce script soit fonctionnel il faut :

1° Enregistrer votre application sur http://www.ovh.com/cgi-bin/api/createApplication.cgi

2° Mettre dans le script dans $ak votre clé d'application (publique)

3° Mettre dans le script dans $as votre clé (secrète) d'application

4° Demander un Token d'authentification à OVH ; il y a un exemple sur il y a un exemple sur http://www.ovh.com/fr/g934.premiers-pas-avec-l-api (attention dans l'exemple le token n'a que les droits GET)

5° Mettre ce token dans le script dans $ck


Si vous utilisez Debian, il vous faudra les packages suivants :

libjson-perl
libjson-xs-perl
libdigest-sha1-perl
libwww-perl 

Le package libdigest-sha1-perl n'existe étrangement plus sous Ubuntu 12.04 LTS. Dans le répertoire package, vous trouverez une version adaptée à Ubuntu 12.04 (à installer avec la commande dpkg -i libdigest-sha1-perl.deb)

## Utilisation

```
  usage: ovh-pca-api-manage.pl [-d] max_session_age_in_seconds | [-r] new_name | [-l] | [-t] | [-b] Session ID | [-h]

   -h : this (help) message
   -d : delete PCA sessions older than X
   -r : Rename last PCA session into Y
   -l : List PCA sessions
   -t : List tasks with their status
   -b : Restore session X
```

```
  example:  perl ovh-pca-api-manage.pl -d 86400 (=delete sessions older than a day)
            perl ovh-pca-api-manage.pl -r "new session name" (=rename last session into new session name)
            perl ovh-pca-api-manage.pl -l (=List active sessions)
            perl ovh-pca-api-manage.pl -t (=List tasks and get their status)
            perl ovh-pca-api-manage.pl -b 51d542f302ee4c5466000000 (=Restore session with ID 51d542f302ee4c5466000000)
```
            
