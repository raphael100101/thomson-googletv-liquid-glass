# Thomson Google TV : moins de pubs, plus fluide, accueil « liquid glass »

Un kit pour une télé **Thomson sous Google TV** (prévu pour la **Thomson 55QG7C14**, série Q70 QLED Pro), piloté depuis un **PC Windows**, en **Wi-Fi**.

C'est l'adaptation Windows de [NoamAssayag/tcl-googletv-liquid-glass](https://github.com/NoamAssayag/tcl-googletv-liquid-glass) (fait pour Mac et TCL). Le lanceur vient du projet open source [Gathin23/cleanyourtv](https://github.com/Gathin23/cleanyourtv).

Ce que ça fait :
- **Désactive** les applis de pubs, de statistiques et de démo préinstallées (rien n'est désinstallé).
- Installe un **accueil épuré** avec Netflix, YouTube, Disney+ et Prime Video dans le dock.
- Thème **verre dépoli** : boutons du haut en icônes seules, fond d'écran qui change **jour / nuit** selon le soleil.
- **Écran de veille** : grande horloge et date centrées sur le fond.
- **Sauvegarde automatique** avant toute modification, et un script pour **tout remettre comme avant**.

Le Play Store, Chromecast intégré et la TV en direct restent disponibles.

## Avant de commencer
1. Le PC et la télé sont sur le **même réseau** (même box).
2. Sur la télé : Paramètres > Système > À propos > clique 7 fois sur **Build du système d'exploitation Android TV** pour activer le mode développeur. Puis Paramètres > Système > **Options pour les développeurs** > active le **Débogage USB** (il sert aussi en Wi-Fi sur Google TV).
3. Note l'**adresse IP** de la télé : Paramètres > Réseau et Internet > ton Wi-Fi.
4. Sur le PC, il faut **Git**, **Python 3** et **Android Studio** (qui fournit Java et le SDK Android pour compiler le lanceur). Le script propose de les installer avec `winget` s'ils manquent. Après l'installation d'Android Studio, **ouvre-le une fois** et laisse l'assistant installer le SDK (choix « Standard », accepte les licences).

## Installation
**Le plus simple** : sur GitHub, bouton vert **Code > Download ZIP**, décompresse, puis double-clique **`installer.cmd`** et tape l'IP de la télé. (`inventaire.cmd` fait la même chose pour l'inventaire.)

**En ligne de commande**, dans PowerShell (menu Démarrer > « PowerShell ») :
```powershell
git clone https://github.com/raphael100101/thomson-googletv-liquid-glass.git
cd thomson-googletv-liquid-glass
powershell -ExecutionPolicy Bypass -File .\setup.ps1 -TvIp 192.168.1.50 -Lat 48.85 -Lon 2.35
```
- Remplace `192.168.1.50` par l'IP de ta télé. `-Lat` et `-Lon` (ici Paris) font changer le fond au lever et au coucher du soleil ; sans eux, le lanceur utilise 7 h et 18 h 30.
- Une fenêtre « **Autoriser le débogage** » apparaît sur la télé : accepte, en cochant « Toujours autoriser ».
- Le script demande confirmation avant les étapes importantes (`-Oui` pour tout accepter).
- La première compilation du lanceur prend plusieurs minutes.

`-ExecutionPolicy Bypass` permet à Windows de lancer ces scripts sans changer tes réglages de sécurité.

## Vérifier la liste d'applis de ta télé (conseillé avant le 1er lancement)
La liste `debloat-thomson.txt` contient des applis Google TV communes et les applis TCL du kit d'origine (ignorées si elles n'existent pas). Les applis propres à Thomson ne sont pas encore listées. Pour les voir :
```powershell
# 1. installe seulement les outils sur le PC, sans toucher à la télé
powershell -ExecutionPolicy Bypass -File .\setup.ps1 -TvIp 192.168.1.50 -OutilsSeulement
# 2. liste les applis de la télé (lecture seule)
powershell -ExecutionPolicy Bypass -File .\inventaire.ps1 -TvIp 192.168.1.50
```
Il crée `inventaire-….txt`. Les lignes **A-VERIFIER** ont un nom qui ressemble à une appli du fabricant. N'ajoute à `debloat-thomson.txt` que celles dont tu connais le rôle.

## Personnaliser
- **Applis du dock** : modifie `dock_apps` dans `theme/config.json`, puis relance `setup.ps1`.
- **Fonds d'écran** : dépose tes propres `jour.jpg` et `nuit.jpg` (1920×1080, plutôt sombres) dans `theme/wallpapers/`. Sinon, des fonds dégradés sont générés.
- **Applis à désactiver** : édite `debloat-thomson.txt` (un `#` devant une ligne = on la garde).
- **Bouton TV en direct** : détecté automatiquement ; sinon passe `-LiveTv <nom du paquet>`.
- Autres options du thème : voir la [documentation du thème](https://github.com/Gathin23/cleanyourtv/blob/main/themes/README.md).

## Tout remettre comme avant
```powershell
powershell -ExecutionPolicy Bypass -File .\restore.ps1 -TvIp 192.168.1.50
```
Il réactive les applis, remet l'accueil Google TV, retire le thème et le lanceur, et rétablit les animations et l'écran de veille d'origine (lus dans la **toute première** sauvegarde). Redémarre ensuite la télé.
Avant une **revente**, fais en plus une réinitialisation d'usine.

Les sauvegardes sont dans `backup-…/` : **garde-les et ne les publie jamais** (infos propres à ta télé). Elles sont exclues de Git par `.gitignore`.

## Fichiers
| Fichier | Rôle |
|---|---|
| `installer.cmd` / `inventaire.cmd` | Raccourcis à double-cliquer |
| `setup.ps1` | Installation complète, en 7 étapes |
| `backup.ps1` | Sauvegarde de l'état de la télé (lancé par `setup.ps1`) |
| `restore.ps1` | Retour à l'état d'origine |
| `inventaire.ps1` | Liste des applis de la télé, sans rien changer |
| `debloat-thomson.txt` | Applis à désactiver |
| `theme/config.json` | Réglages du thème et du dock |
| `patches/horloge-centree.patch` | Horloge centrée sur l'écran de veille |

## Dépannage
**« Connexion impossible » alors que la télé est allumée et que le cast marche depuis un téléphone**
Un **VPN** sur le PC (Cisco AnyConnect, VPN d'entreprise…) peut intercepter le réseau local 192.168.1.x : le PC n'atteint alors plus la télé. Déconnecte le VPN le temps de l'installation, ou active « Autoriser l'accès au réseau local » dans ses réglages s'il le permet. Pour vérifier, dans PowerShell : `Find-NetRoute -RemoteIPAddress <IP de la télé>` doit indiquer l'interface **Wi-Fi** (ou Ethernet), pas celle du VPN.

**« Skipping com.google.android.tungsten.setupwraith: the saved Wi-Fi network belongs to it », puis l'accueil revient à Google TV**
Les réseaux Wi-Fi enregistrés pendant la première configuration de la télé appartiennent à l'assistant de configuration (`setupwraith`). Tant qu'il est actif, il reprend l'écran d'accueil, et le kit refuse de le désactiver, car la télé effacerait ces réseaux.
1. Sur la télé : Paramètres > Réseau et Internet > ton Wi-Fi > **Oublier le réseau**, puis reconnecte-toi au même réseau.
2. Fais pareil pour **tous les autres réseaux enregistrés** (anciennes box, partages de connexion de téléphone…), ou supprime ceux qui ne servent plus. Un seul suffit à bloquer.
3. Relance `setup.ps1`.

Pour voir à qui appartient chaque réseau (`cname=…setupwraith` = bloquant) :
```powershell
. .\lib.ps1; Set-TvIp 192.168.1.50; Invoke-Tv 'dumpsys wifi' | Select-String 'SSID: "|cname='
```
Si seuls des réseaux **inutilisés** sont encore bloquants, tu peux forcer : `$env:FORCE_SETUPWRAITH='1'` puis relance `setup.ps1` (ces réseaux sont alors oubliés par la télé). Ne le fais **jamais** si le réseau sur lequel la télé est connectée en fait partie : elle perdrait le Wi-Fi.

**« Unsupported class file major version 69 » pendant la compilation**
Les Android Studio récents embarquent Java 25, trop récent pour Gradle 8.9 utilisé par le lanceur. `setup.ps1` cherche un Java 17 à 22 et propose d'installer Microsoft OpenJDK 21 s'il n'en trouve aucun (`winget install --id Microsoft.OpenJDK.21 -e`).

**Des applis désactivées reviennent toutes seules**
Tant que l'assistant de configuration est actif, il peut réactiver certaines applis (`feedbackconsent`, ACR Anoki…). Une fois l'assistant désactivé (voir plus haut), relance `setup.ps1` : il ne redésactive que ce qui est revenu.

## Limites à connaître
- Kit **testé sur une 55QG7C14** (Android 14, firmware UKRC.260302.020). Sur un autre modèle ou firmware, fais l'inventaire d'abord, et garde les sauvegardes.
- Préfère le Wi-Fi **5 GHz** ou l'Ethernet : les applis s'ouvrent plus vite.
- Le fond de nuit n'est pas progressif : l'image change d'un coup.

## Sécurité
- Les applis sont désactivées pour l'utilisateur 0 seulement (`pm disable-user`), jamais supprimées. Le script d'origine refuse de toucher aux composants système indispensables.
- Pense à **désactiver le débogage USB** sur la télé une fois terminé.
- Le kit récupère le code du lanceur sur le dépôt d'origine, à une version précise (voir `lib.ps1`).

Licence MIT (voir `LICENSE`). Kit d'origine © contributeurs de tcl-googletv-liquid-glass ; lanceur © Gathin, licence MIT.
