OVH-PCA-PERL
============

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
