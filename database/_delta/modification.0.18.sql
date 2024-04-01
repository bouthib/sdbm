-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *



---------------------------------------------
---------------------------------------------
---------------------------------------------
--  V E R S I O N   0 . 1 8  -   B e t a   --
---------------------------------------------
---------------------------------------------



-- SDBM.TACHE
INSERT INTO SDBM.EVENEMENT
(
   TYPE_CIBLE
  ,SOUS_TYPE_CIBLE
  ,NOM_EVENEMENT
  ,COMMANDE
  ,INTERVAL_DEFAUT
  ,DESTI_NOTIF_DEFAUT
  ,DELAI_MAX_EXEC_SEC
  ,COMMENTAIRE
)
VALUES
(
   'BD'
  ,'OR'
  ,'SDBM.TACHE'
  ,'
SELECT ''('' || NOM_SERVEUR || '','' || NOM_TACHE || '')''
      ,''La tâche '' || NOM_TACHE || '' (agent : '' || NOM_SERVEUR || '') aurait du être soumise depuis '' || TO_CHAR(DH_PROCHAINE_EXEC,''YYYY/MM/DD:HH24:MI:SS'') || ''.''
  FROM SDBM.TACHE_AGT TAG
 WHERE EXECUTION         = ''AC''
   AND DH_PROCHAINE_EXEC < SYSDATE - (SELECT (FREQU_VERIF_AGENT_TACHE + 60) / 86400 FROM SDBM.PARAMETRE)
   AND EXISTS (SELECT 1
                 FROM SDBM.PARAMETRE
                WHERE STATUT_AGENT = ''AC''
              )
   AND NOT EXISTS (SELECT 1
                     FROM SDBM.HIST_TACHE_AGT
                    WHERE NOM_SERVEUR  = TAG.NOM_SERVEUR
                      AND NOM_TACHE    = TAG.NOM_TACHE
                      AND STATUT_EXEC  IN (''SB'',''SR'',''EX'',''EV'')
                  )
'
  ,'SYSDATE + 15/1440'
  ,'Aucune'
  ,30
  ,'Vérification de l''exécution des tâches SDBM'
);


GRANT SELECT ON SDBM.HIST_TACHE_AGT            TO SDBMON;
GRANT SELECT ON SDBM.PARAMETRE                 TO SDBMON;
GRANT SELECT ON SDBM.TACHE_AGT                 TO SDBMON;
