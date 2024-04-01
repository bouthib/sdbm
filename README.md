[![en](https://img.shields.io/badge/language-english-blue)](#english-version)

<a id='french-version' class='anchor' aria-hidden='true'/>


# SDBM - Simple Database Monitoring

## Description du projet

Simple Database Monitoring est un outils permettant de faire le "monitoring" de base de données Oracle, Microsoft SQL Server et MySQL.


### Détails

SDBM permet notament :

- Console de gestion Web (http / https)
- Vérification de la disponibilité des bases de données (incluant la conservation des statistiques associées sur les niveaux de service)
- La création d'événements qui permettent d'être avisés de n'importe quelles situations pouvant être relevé par une instruction SQL
- La vérification des fichiers de trace Oracle et Microsoft SQL Server
- La capture de l'évolution de la capacité disque et le calcul des besoins futurs (projection)
- Le suivi des performance des serveurs - CPU, Charge Système (Load Average), mémoire et activité de pagination
- Céduleur de tâche avec gestion des journaux d'exécution
- Support des dernières technologies Oracle (ASM et RAC)


### Objectif de conception : Simplicité

En plus d'être simple d'utilisation, SDBM est concu dans l'optique d'être simple à l'installation, léger sur les ressources (le serveur de gestion peut s'exécuter sur un PC Windows ou Linux), et non-intrusif.

Le serveur de gestion fonctionne sans aucune installation sur vos serveurs de bases de données. Seul un accès en lecture est requis dans la base de données (un agent léger est requis pour la vérification des traces, le suivi de performance serveur et l'exécution des tâches).


### Installation simple via "Releases"

Le fichier "release" est diponible pour permettre l'installation la plus simple possible.  Avec cette façon, certain composant comme les services Java sont pré-compilés.  Il est aussi à noter que c'est la seule façon possible pour obtenir tout les utilitaires requis pour procéder à une installation sur Windows.  Si vous n'avez pas l'intention de modifier le code Java, cette méthode est recommandée.

#### Linux

Ansible est utilisé pour déployer SDBM sous Linux (donc ansible doit être disponible au même endroit ou le fichier sdbm-release-{verison}.zip extrait). Aucun prérequis n'est requis sur la machine cible (celle qui exécutera SDBM). Votre fichier d'inventaire ansible peut être créer à partir de build/linux/sdbm.example.

```
# Sur Linux : Exécution
cd build/linux
ansible-galaxy collection install ansible.posix
ansible-playbook -i sdbm.example sdbm.yml -kK
```
#####  Nettoyage

L'espace du répertoire /staging peut être récupérée une fois l'installation complétée :

```
# Sur Linux : Exécution
cd build/linux
ansible-playbook -i sdbm.example sdbm-post.yml -kK
```

#####  Utilisation de ojdbc5 pour permettre la surveillance de très anciennes versions Oracle (Linux seulement)

Il est possible de remplacer ojdbc8 par ojdbc5 si requis...

```
# Sur Linux : Exécution
cd ../sdbm/build/linux
ansible-playbook -i sdbm.example ojdbc5.yml -kK
```


#### Windows

Un ensemble de fichiers de commandes est disponible pour installer tout les composants requis pour l'exécution de SDBM sous Windows.  Certain prérequis sont requis sur la machine cible (voir build\windows\Install.cmd).

```
# Sur Windows : Exécution
cd build\windows
Download.cmd
Install.cmd
```

Il est aussi possible de permettre l'accès via HTTPS à la console de gestion SDBM via l'exécution du fichier de commande InstallHTTPSOption.cmd (installation d'un serveur HTTP Apache comme comme terminaison SSL).  Cette étape est optionnelle.

```
# Sur Windows : Exécution
cd build\windows
InstallHTTPSOption.cmd
```


### Bâtir sans utiliser "Releases"

Les pilotes jdbc Oracle, Microsoft SQL et MySQL sont requis. La librairie hyperic-sigar est aussi nécessaire.

```
# Sur Linux : Exécution
cd ../sdbm/server
./download.sh
```


Le répertoire _runtime doit contenir certains fichiers à des endroits spécifiques pour permettre la compiliation des services Java et leur déploiement.

```
# Sur Linux : Exécution
cd ../sdbm/server
./refresh.sh
```


Les services Java doivent aussi être compilés. Pour ce faire, un jdk sera téléchargé et javac exécuté.

```
# Sur Linux : Exécution
cd ../sdbm/server
./compile.sh
```


### Installation sans utiliser "Releases"

Ansible est utilisé pour déployer SDBM sous Linux (donc ansible doit être disponible au même endroit ou réside le clône du dépôt git). Aucun prérequis n'est requis sur la machine cible (celle qui exécutera SDBM). Votre fichier d'inventaire ansible peut être créer à partir de ../sdbm/build/linux/sdbm.example.

Ce point atteint, l'installation devrait être simple :

```
# Sur Linux : Exécution
cd ../sdbm/build/linux
ansible-galaxy collection install ansible.posix
ansible-playbook -i sdbm.example sdbm.yml -kK
```

####  Nettoyage (Linux seulement)

L'espace du répertoire /staging peut être récupérée une fois l'installation complétée :

```
# Sur Linux : Exécution
cd ../sdbm/build/linux
ansible-playbook -i sdbm.example sdbm-post.yml -kK
```

####  Utilisation de ojdbc5 pour permettre la surveillance de très anciennes versions Oracle (Linux seulement)

Il est possible de remplacer ojdbc8 par ojdbc5 si requis...

```
# Sur Linux : Exécution
cd ../sdbm/build/linux
ansible-playbook -i sdbm.example ojdbc5.yml -kK
```


### Licence et propriété intellectuelle

Le code source de ce projet est libéré sous la licence [MIT License](LICENSE).

______________________


[![fr](https://img.shields.io/badge/langue-français-blue)](#french-version)

<a id='english-version' class='anchor' aria-hidden='true'/>


# SDBM - Simple Database Monitoring


## Project description

Simple Database Monitoring is a tool for monitoring Oracle, Microsoft SQL Server and MySQL databases


### Details

SDBM features:

- Web console management (http / https)
- Monitoring of availability of the databases (including statistics on level of services)
- Events creation which allow to be aware of any situation that can be detected by an SQL instruction
- Monitoring of Oracle alert file, SQL Server error log and MySQL log
- Gathering of evolution of disk space and calculus of projected need
- Gathering of performance metrics on servers - CPU, Load Average, memory and paging activities (swapping)
- Tasks scheduler with error and log handling
- Support for latest Oracle technologies (ASM and RAC)


### Design goal: Simplicity

The driving idea behind the design of the project is simplicity. In addition to being easy to use, SDBM is designed from the perspective of being simple to install, light on resources (the management server can run on a Windows or Linux), and non-intrusive.

The management server runs without any installation on your server database. Only read access is required in the database (a lightweight agent is required to verify the trace, monitor server performance and execution of tasks).


### Simple installation using Releases

The release file is available to allow the simplest possible installation. Using this method, certain components such as Java services are pre-compiled. This is the only way to get all the utilities required to carry out installations on Windows. If you do not intend to modify Java code, this method is recommended.

#### Linux

SDBM on Linux is deploy using ansible (so ansible must be available on the same machine where the sdbm-release-{version}.zip is extracted). No special prerequisite are required on the "target" machine (the one that will execute SDBM). The ansible inventory file build/linux/sdbm.example can be use to create your own inventory file.

```
# On Linux : Execute
cd ../sdbm/build/linux
ansible-galaxy collection install ansible.posix
ansible-playbook -i sdbm.example sdbm.yml -kK
```

#####  Cleanup

When the installation is completed, the /staging directory could be remove to reclaim space :

```
# On Linux : Execute
cd ../sdbm/build/linux
ansible-playbook -i sdbm.example sdbm-post.yml -kK
```

#####  Using ojdbc5 for monitoring very old Oracle versions (Linux only)

It is possible to replace ojdbc8 by ojdbc5 if required...

```
# On Linux : Execute
cd ../sdbm/build/linux
ansible-playbook -i sdbm.example ojdbc5.yml -kK
```


#### Windows

A set of batch files is available to install all the components required to run SDBM under Windows. Certain prerequisites are required on the target machine (see build\windows\Install.cmd).

```
# On Windows : Execute
cd build\windows
Download.cmd
Install.cmd
```

It is also possible to allow access via HTTPS to the SDBM management console by executing the InstallHTTPSOption.cmd command file (installation of an Apache HTTP server as an SSL termination). This is an optional step.

```
# On Windows : Execute
cd build\windows
InstallHTTPSOption.cmd
```


### Build without using Release

SDBM require Oracle, Microsoft SQL et MySQL jdbc drivers.  It also require the hyperic-sigar library.

```
# On Linux : Execute
cd ../sdbm/server
./download.sh
```


The _runtime directory need some files to exists within specific locations to allow Java services to be compile and deployment.

```
# On Linux : Execute
cd ../sdbm/server
./refresh.sh
```


Java services also need to be built. To do so, jdk will be downloaded and javac executed.

```
# On Linux : Execute
cd ../sdbm/server
./compile.sh
```


### Installation without using Release

SDBM on Linux is deploy using ansible (so ansible must be available on the same machine where to git repository is clone). No special prerequisite are required on the "target" machine (the one that will execute SDBM). The ansible inventory file ../sdbm/build/linux/sdbm.example can be use to create your own inventory file.

At this point, the installation shoud be simple :

```
# On Linux : Execute
cd ../sdbm/build/linux
ansible-galaxy collection install ansible.posix
ansible-playbook -i sdbm.example sdbm.yml -kK
```

####  Cleanup (Linux only)

When the installation is completed, the /staging directory could be remove to reclaim space :

```
# On Linux : Execute
cd ../sdbm/build/linux
ansible-playbook -i sdbm.example sdbm-post.yml -kK
```

####  Using ojdbc5 for monitoring very old Oracle versions (Linux only)

It is possible to replace ojdbc8 by ojdbc5 if required...

```
# On Linux : Execute
cd ../sdbm/build/linux
ansible-playbook -i sdbm.example ojdbc5.yml -kK
```


### License

The source code of this project is distributed under the [MIT License](LICENSE).

